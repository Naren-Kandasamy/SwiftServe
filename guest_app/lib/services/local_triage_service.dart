import 'dart:async';
import 'package:dio/dio.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter/foundation.dart';
import 'model_manager.dart';
import 'offline_knowledge.dart';
import 'package:shared/models/alert.dart';

enum TriageSource { 
  cloud('Gemini 1.5 Pro'), 
  native('Edge Intelligence (NPU)'), 
  universal('CrisisNET AI (Offline)'), 
  web('Local Intel (Ollama)'),
  local('Heuristic Protocol');

  final String label;
  const TriageSource(this.label);
}

class LocalTriageService {
  final String apiKey;
  static const MethodChannel _channel = MethodChannel('com.crisisnet.guest_app/ai_bridge');

  LocalTriageService({required this.apiKey});

  Future? _pendingRequest;
  final Dio _dio = Dio();

  /// Processes guest description and returns a detailed response + source label + asset path.
  /// Uses a sequential queue to prevent concurrent LLM hangs.
  Future<Map<String, dynamic>> processEmergency(String description) async {
    final previousRequest = _pendingRequest;
    final completer = Completer();
    _pendingRequest = completer.future;

    if (previousRequest != null) {
      debugPrint('[Triage] Sequential Queue: Waiting for previous SOS to clear...');
      await previousRequest;
    }

    try {
      return await _processEmergencyInternal(description);
    } finally {
      completer.complete();
    }
  }

  Future<Map<String, dynamic>> _processEmergencyInternal(String description) async {
    String type = _detectType(description);
    int severity = _detectSeverity(description);
    
    // TIER 1: CLOUD (High Fidelity)
    try {
      if (await _isActuallyOnline()) {
        debugPrint('[Triage] Attempting Tier 1 (Cloud)...');
        final response = await _cloudTriage(description).timeout(const Duration(seconds: 4));
        if (response != null) {
          return {
            'source': TriageSource.cloud,
            'content': response,
            'type': type,
            'severity': severity,
            'assetPath': OfflineKnowledgeService.getAssetPath(_getEmergencyType(type)),
          };
        }
      }
    } catch (_) {}

    // TIER 2: OLLAMA (Local Desktop/Web Intelligence)
    try {
      debugPrint('[Triage] Attempting Tier 2 (Ollama Service)...');
      final response = await _ollamaTriage(description);
      if (response != null) {
        String content = response;
        
        // Output from the few-shot /api/chat model is strictly the instruction text.
        // We rely on the local _detectType(description) function that ran earlier to supply `type` and `severity`.

        return {
          'source': TriageSource.universal,
          'content': content,
          'type': type,
          'severity': severity,
          'assetPath': OfflineKnowledgeService.getAssetPath(_getEmergencyType(type)),
        };
      }
    } catch (e) {
      debugPrint('[Triage] Ollama Triage failed: $e. Falling back to Keyword Classifier.');
    }

    // TIER 2 FAILED: Immediate fallback to Keyword Classifier + Predefined Protocols
    debugPrint('[Triage] Ollama unavailable. Activating Keyword Classifier...');
    return {
      'source': TriageSource.local,
      'content': _keywordClassify(description),
      'type': type,
      'severity': severity,
      'assetPath': OfflineKnowledgeService.getAssetPath(_getEmergencyType(type)),
    };
  }


  /// Strict online check using a lightweight head request to prevent "ghost" connection hangs.
  Future<bool> _isActuallyOnline() async {
    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.any((r) => r == ConnectivityResult.none)) return false;
      
      // Fast check for actual internet routing
      final response = await _dio.head(
        'https://www.google.com',
        options: Options(receiveTimeout: const Duration(seconds: 2), sendTimeout: const Duration(seconds: 1)),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<String?> _ollamaTriage(String description) async {
    try {
      final baseUrl = kIsWeb ? 'http://localhost:11434' : 'http://10.0.2.2:11434';

      final response = await _dio.post(
        '$baseUrl/api/chat',
        data: {
          'model': 'qwen:0.5b',
          'messages': [
            {
              'role': 'system',
              'content': 'You are an offline tactical survival AI. You provide exactly 3 to 5 highly detailed and distinct physical actions the user must take immediately to survive by themselves. Assume phones and internet do not work. Be highly specific and commanding and do not ask them to call for emergency services. Give instructions such that they can handle the situation themselves.'
            },
            {
              'role': 'user',
              'content': 'I stepped on glass and my foot is bleeding heavily.'
            },
            {
              'role': 'assistant',
              'content': '1. Apply immediate, heavy pressure directly to the wound using a clean shirt or towel to stop the bleeding.\n2. Elevate your leg above your heart level to reduce blood flow to the injury.\n3. Do not pull out deeply embedded shards; wrap your makeshift bandage completely around them.\n4. Lie down flat on the floor to prevent fainting from shock or blood loss.\n5. Tie the fabric tightly to maintain pressure and keep all weight off the injured foot.'
            },
            {
              'role': 'user',
              'content': 'I am trapped in an elevator and it just dropped suddenly.'
            },
            {
              'role': 'assistant',
              'content': '1. Lie flat on your back in the exact center of the elevator floor immediately.\n2. Cover your face and head with your arms to protect against falling debris.\n3. Do not attempt to force the doors open; this risks falling into the shaft.\n4. Conserve your energy and oxygen; breathe slowly and stay as quiet as possible.\n5. Use a flashlight or phone screen only to check for immediate hazards, then turn it off to save battery.'
            },
            {
              'role': 'user',
              'content': description
            }
          ],
          'stream': false,
          'options': {'temperature': 0.15, 'top_p': 0.9, 'presence_penalty': 1.5},
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final content = response.data['message']['content'] as String;
        // The model output usually starts exactly with "1. ...".
        return content.trim();
      }
    } catch (e) {
      debugPrint('[Ollama] API Error: $e');
    }
    return null;
  }

  EmergencyType _getEmergencyType(String typeStr) {
    return EmergencyType.values.firstWhere(
      (e) => e.name == typeStr, 
      orElse: () => EmergencyType.other
    );
  }

  Future<String?> _cloudTriage(String description) async {
    if (apiKey.isEmpty) return null;
    final model = GenerativeModel(
      model: 'gemini-1.5-flash', 
      apiKey: apiKey,
      generationConfig: GenerationConfig(maxOutputTokens: 200),
    );
    
    final prompt = 'EMERGENCY TRIAGE: A guest reports: "$description". Provide 3 short, critical safety instructions in bullet points.';
    final response = await model.generateContent([Content.text(prompt)]);
    return response.text;
  }

  /// Keyword-based classifier with predefined emergency protocols.
  /// Guaranteed fallback when all AI/network tiers are unavailable.
  String _keywordClassify(String description) {
    final d = description.toLowerCase();
    
    // MEDICAL REASONING BLOCKS
    if (d.contains('medical') || d.contains('hurt') || d.contains('bleed') || d.contains('heart') || d.contains('breath') || d.contains('stroke') || d.contains('face')) {
      if (d.contains('choke') || d.contains('cough')) {
        return 'EMERGENCY: CHOKING\n'
               '1. RECOGNITION: If they cannot speak or cough, perform 5 abdominal thrusts (Heimlich).\n'
               '2. CPR: If they collapse, begin chest compressions immediately.\n'
               '3. MESH: Your coordinates are locked. Staff is navigating to you.';
      }
      if (d.contains('stroke') || d.contains('face') || d.contains('numb') || d.contains('slur')) {
        return 'EMERGENCY: STROKE (F.A.S.T)\n'
               '1. FACE: Ask them to smile. Look for lopsidedness.\n'
               '2. ARMS: Ask them to raise both. Check for drift.\n'
               '3. SPEECH: Listen for slurring. Clear furniture for stretcher access.';
      }
      if (d.contains('heart') || d.contains('chest')) {
        return 'EMERGENCY: CARDIAC ALERT\n'
               '1. POSITION: Sit the patient on the floor, leaning back against a wall.\n'
               '2. LOOSEN: Remove any tight ties, collars, or belts immediately.\n'
               '3. MEDS: If conscious/not-allergic, have them chew an aspirin. AED unit nearby.';
      }
      if (d.contains('bleed')) {
        return 'MERGENCY: SEVERE BLEEDING\n'
               '1. PRESSURE: Apply heavy, direct pressure with a clean cloth.\n'
               '2. ELEVATE: Keep the wound above heart level if possible.\n'
               '3. DO NOT remove the cloth even if soaked; add more on top.';
      }
      return 'DISPATCHER ADVICE (SYNCED):\n'
             '• Keep the patient calm. Do not move them unless in immediate danger.\n'
             '• Check for pulse and breathing every 60 seconds.\n'
             '• Responder team is tracking your Bluetooth beacon.';
    }

    // FIRE & INFRA REASONING BLOCKS
    if (d.contains('fire') || d.contains('smoke') || d.contains('gas') || d.contains('leak') || d.contains('electric')) {
      if (d.contains('fire') || d.contains('smoke')) {
        return 'EMERGENCY: FIRE/SMOKE\n'
               '1. EVACUATE NOW: Leave everything. Use stairs, not elevators.\n'
               '2. HAND CHECK: Feel doors with the back of your hand before opening.\n'
               '3. CRAWL: Smoke rises; stay 12 inches from the floor for clean air.';
      }
      if (d.contains('gas') || d.contains('leak') || d.contains('smell')) {
        return 'EMERGENCY: HAZMAT/GAS LEAK\n'
               '1. No switches, phones, or sparks. Evacuate immediately.\n'
               '2. Meet at the external assembly point.\n'
               '3. Move upwind from the suspected leak source.';
      }
      return 'EMERGENCY: NFRASTRUCTURE\n'
             '• Avoid all standing water if electricity is a concern.\n'
             '• If trapped, signal from a window with a white cloth.\n'
             '• Stay away from elevators and glass panels.';
    }
    
    // SECURITY REASONING BLOCKS
    if (d.contains('threat') || d.contains('intruder') || d.contains('gun') || d.contains('shooter') || d.contains('attack')) {
      if (d.contains('gun') || d.contains('shooter') || d.contains('active')) {
        return 'EMERGENCY: ACTIVE THREAT (RUN-HIDE-FIGHT)\n'
               '1. RUN: Evacuate if there is a safe path. Leave belongings.\n'
               '2. HIDE: Barricade your door, turn off lights, and silence ALL devices.\n'
               '3. FIGHT: As a last resort, commit to stopping the threat aggressively.';
      }
      return 'EMERGENCY: SECURITY BREACH\n'
             '• Lock and deadbolt your room immediately.\n'
             '• Move to a bathroom or corner away from door visibility.\n'
             '• Do not exit until you hear the verified staff "All-Clear" code.';
    }

    return 'OFFLINE TRIAGE ACTIVE:\n'
           '• Stay at your current safe location and keep your door locked.\n'
           '• Your incident has been registered in the local CrisisNet buffer.\n'
           '• We will sync your data to our command center automatically.';
  }

  String _detectType(String description) {
    final d = description.toLowerCase();
    if (d.contains('fire')) return 'fire';
    if (d.contains('medical') || d.contains('hurt') || d.contains('pain') || d.contains('breath') || d.contains('heart') || d.contains('bleed')) return 'medical';
    if (d.contains('intruder') || d.contains('gun') || d.contains('threat') || d.contains('attack')) return 'security';
    if (d.contains('water') || d.contains('leak') || d.contains('power') || d.contains('electric')) return 'infrastructure';
    return 'other';
  }

  int _detectSeverity(String description) {
    final d = description.toLowerCase();
    if (d.contains('help') || d.contains('kill') || d.contains('die')) return 5;
    if (d.contains('hurt') || d.contains('fire')) return 4;
    return 3;
  }
}
