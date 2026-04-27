import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter/foundation.dart';
import 'offline_knowledge.dart';
import 'package:shared/models/alert.dart';

enum TriageSource { 
  cloud('Gemini 1.5 Pro'), 
  native('Edge Intelligence (NPU)'), 
  universal('CrisisNET AI (Offline)'), 
  local('Heuristic Protocol');

  final String label;
  const TriageSource(this.label);
}

class LocalTriageService {
  final String apiKey;

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
          try {
            final json = _parseJson(response);
            return {
              'source': TriageSource.cloud,
              'content': json['immediateInstructions'] ?? json['safetyInstructions'] ?? response,
              'type': json['type'] ?? type,
              'severity': json['severity'] ?? severity,
              'assetPath': OfflineKnowledgeService.getAssetPath(_getEmergencyType(json['type'] ?? type)),
            };
          } catch (e) {
            // If it failed to parse JSON, return string
            return {
              'source': TriageSource.cloud,
              'content': response,
              'type': type,
              'severity': severity,
              'assetPath': OfflineKnowledgeService.getAssetPath(_getEmergencyType(type)),
            };
          }
        }
      }
    } catch (_) {}

    // TIER 2: NATIVE EDGE (Gemma)
    try {
      debugPrint('[Triage] Attempting Tier 2 (Native Gemma)...');
      final response = await _gemmaTriage(description);
      if (response != null) {
        try {
          final json = _parseJson(response);
          return {
            'source': TriageSource.native,
            'content': json['immediateInstructions'] ?? json['safetyInstructions'] ?? response,
            'type': json['type'] ?? type,
            'severity': json['severity'] ?? severity,
            'assetPath': OfflineKnowledgeService.getAssetPath(_getEmergencyType(json['type'] ?? type)),
          };
        } catch (e) {
          return {
            'source': TriageSource.native,
            'content': response,
            'type': type,
            'severity': severity,
            'assetPath': OfflineKnowledgeService.getAssetPath(_getEmergencyType(type)),
          };
        }
      }
    } catch (e) {
      debugPrint('[Triage] Gemma Triage failed: $e');
    }

    // TIER 3 FAILED: Immediate fallback to Keyword Classifier + Predefined Protocols
    debugPrint('[Triage] All AI tiers unavailable. Activating Keyword Classifier...');
    return {
      'source': TriageSource.local,
      'content': _keywordClassify(description),
      'type': type,
      'severity': severity,
      'assetPath': OfflineKnowledgeService.getAssetPath(_getEmergencyType(type)),
    };
  }

  Map<String, dynamic> _parseJson(String text) {
    try {
      final jsonMatch = RegExp(r'\{.*\}', dotAll: true).firstMatch(text);
      if (jsonMatch != null) {
        return jsonDecode(jsonMatch.group(0)!);
      }
      return jsonDecode(text);
    } catch (e) {
      throw FormatException('Failed to parse JSON');
    }
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

  Future<String?> _gemmaTriage(String description) async {
    if (!FlutterGemma.hasActiveModel()) return null;
    try {
      final model = await FlutterGemma.getActiveModel(maxTokens: 512);
      final chat = await model.createChat();
      
      final prompt = '''
You are a tactical emergency response AI. Classify the incoming guest SOS alert and provide IMMEDIATE, ACTIONABLE life-saving instructions.
DO NOT give generic "Call 911" advice. Assume the user is in immediate danger and help is minutes away.

Instructions should be:
1. Tactical (e.g., "Stay low under smoke", "Apply pressure with clean cloth", "Barricade the door").
2. Bulleted (3-4 points).
3. In the same language as the SOS message.

Output format (STRICT JSON):
{
  "type": "fire" | "medical" | "security" | "infrastructure" | "other",
  "severity": <integer 1-5>,
  "immediateInstructions": "1. [First tactical step]\\n2. [Second tactical step]\\n3. [Third tactical step]",
  "escalateToEmergencyServices": <boolean>
}

Guest SOS Message: "$description"
''';
      await chat.addQuery(Message(text: prompt, isUser: true));
      final response = await chat.generateChatResponse();
      await chat.close();
      await model.close();
      if (response is TextResponse) {
        return response.token;
      }
    } catch (e) {
      debugPrint('[Gemma] Error: $e');
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
      generationConfig: GenerationConfig(maxOutputTokens: 300),
    );
    
    final prompt = '''
You are an emergency triage AI for a hospitality venue.
Classify the incoming guest SOS alert and return ONLY valid JSON.

MULTILINGUAL SUPPORT: Detect the language of the SOS message. The `immediateInstructions` MUST be in the same language.

Severity scale 1–5:
1 = Minor nuisance. 2 = Low concern. 3 = Active incident (staff needed).
4 = Serious (emergency services likely needed). 5 = Mass casualty / catastrophic.

Output format:
{
  "type": "fire" | "medical" | "security" | "infrastructure" | "other",
  "severity": <integer 1-5>,
  "immediateInstructions": "<3-4 sentence safety instruction IN GUEST'S LANGUAGE>",
  "language": "<ISO 639-1 code>",
  "escalateToEmergencyServices": <boolean>
}

Guest SOS Message: "$description"
''';
    final response = await model.generateContent([Content.text(prompt)]);
    return response.text;
  }

  /// Keyword-based classifier with predefined emergency protocols.
  /// Guaranteed fallback when all AI/network tiers are unavailable.
  String _keywordClassify(String description) {
    final d = description.toLowerCase();
    
    // MEDICAL REASONING BLOCKS
    if (d.contains('medical') || d.contains('hurt') || d.contains('bleed') || d.contains('heart') || d.contains('breath') || d.contains('stroke') || d.contains('face') || d.contains('cut') || d.contains('dizzy') || d.contains('collapse') || d.contains('unconscious') || d.contains('choke') || d.contains('cough')) {
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
      if (d.contains('bleed') || d.contains('cut') || d.contains('stab')) {
        return 'EMERGENCY: SEVERE BLEEDING\n'
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
    if (d.contains('fire') || d.contains('smoke') || d.contains('gas') || d.contains('leak') || d.contains('electric') || d.contains('burn') || d.contains('spark')) {
      if (d.contains('fire') || d.contains('smoke') || d.contains('burn')) {
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
      return 'EMERGENCY: INFRASTRUCTURE\n'
             '• Avoid all standing water if electricity is a concern.\n'
             '• If trapped, signal from a window with a white cloth.\n'
             '• Stay away from elevators and glass panels.';
    }
    
    // SECURITY REASONING BLOCKS
    if (d.contains('threat') || d.contains('intruder') || d.contains('gun') || d.contains('shooter') || d.contains('attack') || d.contains('knife') || d.contains('weapon')) {
      if (d.contains('gun') || d.contains('shooter') || d.contains('active') || d.contains('weapon')) {
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
    if (d.contains('fire') || d.contains('smoke') || d.contains('burn')) return 'fire';
    if (d.contains('medical') || d.contains('hurt') || d.contains('pain') || d.contains('breath') || d.contains('heart') || d.contains('bleed') || d.contains('cut') || d.contains('dizzy')) return 'medical';
    if (d.contains('intruder') || d.contains('gun') || d.contains('threat') || d.contains('attack') || d.contains('weapon') || d.contains('knife')) return 'security';
    if (d.contains('water') || d.contains('leak') || d.contains('power') || d.contains('electric')) return 'infrastructure';
    return 'other';
  }

  int _detectSeverity(String description) {
    final d = description.toLowerCase();
    if (d.contains('help') || d.contains('kill') || d.contains('die') || d.contains('gun') || d.contains('fire') || d.contains('heart') || d.contains('shooter')) return 5;
    if (d.contains('hurt') || d.contains('bleed') || d.contains('smoke') || d.contains('attack')) return 4;
    return 3;
  }
}
