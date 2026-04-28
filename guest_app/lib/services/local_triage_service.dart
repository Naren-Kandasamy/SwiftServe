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
  cloud('Gemini 2.5 Flash'), 
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
  Future<Map<String, dynamic>> processEmergency(String description, {String selectedType = 'other'}) async {
    final previousRequest = _pendingRequest;
    final completer = Completer();
    _pendingRequest = completer.future;

    if (previousRequest != null) {
      debugPrint('[Triage] Sequential Queue: Waiting for previous SOS to clear...');
      await previousRequest;
    }

    try {
      return await _processEmergencyInternal(description, selectedType: selectedType);
    } finally {
      completer.complete();
    }
  }

  Future<Map<String, dynamic>> _processEmergencyInternal(String description, {String selectedType = 'other'}) async {
    String type = selectedType; // Use the guest-selected type, not keyword detection
    int severity = _detectSeverity(description);
    
    // TIER 1: CLOUD (High Fidelity)
    try {
      if (await _isActuallyOnline()) {
        debugPrint('[Triage] Attempting Tier 1 (Cloud — Gemini 2.5 Flash)...');
        final response = await _cloudTriage(description, selectedType: type).timeout(const Duration(seconds: 15));
        if (response != null) {
          try {
            final json = _parseJson(response);
            final advice = json['immediateInstructions'] ?? json['safetyInstructions'] ?? response;
            return {
              'source': TriageSource.cloud,
              'content': '[Cloud] $advice',
              'type': json['type'] ?? type,
              'severity': json['severity'] ?? severity,
              'assetPath': OfflineKnowledgeService.getAssetPath(_getEmergencyType(json['type'] ?? type)),
            };
          } catch (e) {
            // If it failed to parse JSON, return string
            return {
              'source': TriageSource.cloud,
              'content': '[Cloud] $response',
              'type': type,
              'severity': severity,
              'assetPath': OfflineKnowledgeService.getAssetPath(_getEmergencyType(type)),
            };
          }
        }
      }
    } catch (_) {}

    // TIER 2: NATIVE EDGE (Gemma 3 1B IT) — upgraded from 270M
    try {
      debugPrint('[Triage] Attempting Tier 2 (Gemma 3 1B)...');
      final response = await _gemmaTriage(description, selectedType: type);
      if (response != null) {
        return {
          'source': TriageSource.native,
          'content': '[Edge 1B]\n$response',
          'type': type,
          'severity': severity,
          'assetPath': OfflineKnowledgeService.getAssetPath(_getEmergencyType(type)),
        };
      }
    } catch (e) {
      debugPrint('[Triage] Gemma Triage failed: $e');
    }

    // TIER 3: Curated Keyword Classifier — instant guaranteed fallback
    debugPrint('[Triage] Gemma unavailable. Using curated classifier...');
    return {
      'source': TriageSource.local,
      'content': '[Local]\n${_keywordClassify(description, type)}',
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
        options: Options(receiveTimeout: const Duration(seconds: 5), sendTimeout: const Duration(seconds: 3)),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<String?> _gemmaTriage(String description, {String selectedType = 'other'}) async {
    if (!FlutterGemma.hasActiveModel()) return null;
    try {
      final model = await FlutterGemma.getActiveModel(maxTokens: 300);
      final chat = await model.createChat();

      // ── Strict Instruction Prompt for 1B IT Model ─────────────────────────
      // The 1B IT model is heavily aligned to give safety warnings ("call 911").
      // We must use forceful negative constraints to bypass conversational filler.
      final typeLabel = _typeLabel(selectedType);
      final prompt = '''
You are a tactical emergency AI. The user is in an active $typeLabel emergency.
Incident: "$description"

Provide exactly 3 immediate, physical, life-saving steps they must take right now.
CRITICAL RULES:
- DO NOT say "Call 911" or "seek medical help".
- DO NOT say "assess the situation" or "stay calm".
- DO NOT provide any conversational filler, warnings, or disclaimers.
- Output ONLY a numbered list starting with 1.
'''.trim();

      await chat.addQuery(Message(text: prompt, isUser: true));
      final response = await chat.generateChatResponse();
      await chat.close();
      await model.close();

      if (response is TextResponse) {
        final raw = response.token.trim();
        if (raw.isNotEmpty) {
          return raw;
        }
      }
    } catch (e) {
      debugPrint('[Gemma] Error: $e');
    }
    return null;
  }


  /// Maps type key → human-readable label for Gemma's context.
  String _typeLabel(String type) {
    const labels = {
      'fire': 'FIRE',
      'medical': 'MEDICAL',
      'security': 'SECURITY THREAT',
      'infrastructure': 'INFRASTRUCTURE',
      'other': 'GENERAL',
    };
    return labels[type] ?? 'EMERGENCY';
  }

  /// Strips any acknowledgment preamble that small models sometimes prepend.
  String _stripAcknowledgment(String text) {
    // If the text starts with a numbered step, it's clean — return as-is
    if (RegExp(r'^\d+\.').hasMatch(text)) return text;
    // Otherwise find the first occurrence of "1." and slice from there
    final idx = text.indexOf(RegExp(r'\b1\.'));
    if (idx >= 0) return text.substring(idx).trim();
    // Last resort: return everything after the first sentence (the acknowledgment)
    final dotIdx = text.indexOf('. ');
    if (dotIdx > 0 && dotIdx < 100) return text.substring(dotIdx + 2).trim();
    return text;
  }



  EmergencyType _getEmergencyType(String typeStr) {
    return EmergencyType.values.firstWhere(
      (e) => e.name == typeStr, 
      orElse: () => EmergencyType.other
    );
  }

  Future<String?> _cloudTriage(String description, {String selectedType = 'other'}) async {
    if (apiKey.isEmpty) return null;

    // ── IDENTICAL configuration to dashboard/lib/services/triage_service.dart ──
    final model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.1,
        responseMimeType: 'application/json',
      ),
      safetySettings: [
        SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.harassment, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.none),
      ],
    );

    // ── IDENTICAL prompt to dashboard/lib/services/triage_service.dart ──
    final prompt = '''
You are a high-stakes emergency dispatcher AI for a premium hospitality venue.
Your mission is to provide cold, tactical, life-saving instructions to a guest in panic.

CRITICAL CONSTRAINTS:
1. DO NOT tell the user to "call 911", "contact management", or "find a staff member". Assume we have already done this.
2. DO NOT use conversational filler like "I'm sorry to hear that" or "Stay calm".
3. Provide ONLY specific, physical, tactical actions they must perform RIGHT NOW (e.g., "Press a clean towel into the wound", "Stay 12 inches from the floor to avoid smoke", "Barricade the door with heavy furniture").

MULTILINGUAL SUPPORT: You MUST detect the guest's language. The `immediateInstructions` MUST be written in the exact same language.

Emergency type is pre-classified as: $selectedType (DO NOT override unless the description clearly contradicts it).

Severity scale (1–5):
1 = Minor nuisance (noisy neighbor, lost key).
2 = Low concern (small cut, flickering light).
3 = Active incident. Staff response needed (moderate injury, bin fire).
4 = Serious emergency. Life at risk (cardiac arrest, large fire, assault).
5 = Mass casualty / catastrophic (active shooter, building collapse, gas explosion).

Output format:
{
  "type": "fire" | "medical" | "security" | "infrastructure" | "other",
  "severity": <integer 1-5>,
  "immediateInstructions": "1. [Specific Tactical Step]\\n2. [Specific Tactical Step]\\n3. [Specific Tactical Step]",
  "language": "<ISO 639-1 code>",
  "escalateToEmergencyServices": <boolean>
}

Guest SOS Message: "$description"
''';

    // ── Same 3-retry exponential backoff as the dashboard ──
    for (int i = 0; i < 3; i++) {
      try {
        final response = await model.generateContent([Content.text(prompt)]);
        final text = response.text ?? '';
        final cleanJson = text.replaceAll('```json', '').replaceAll('```', '').trim();
        debugPrint('[Triage] Gemini 2.5 response received on attempt ${i + 1}');
        return cleanJson;
      } catch (e) {
        debugPrint('[Triage] Cloud attempt ${i + 1} failed: $e');
        if (i < 2) await Future.delayed(Duration(milliseconds: 1500 * (i + 1)));
      }
    }
    return null;
  }

  /// Curated tactical classifier. Matches on keywords in description AND
  /// the guest-selected emergency type as a strong secondary signal.
  String _keywordClassify(String description, [String selectedType = 'other']) {
    final d = description.toLowerCase();

    // ── MEDICAL ──────────────────────────────────────────────────────────────
    if (selectedType == 'medical' ||
        d.contains('medical') || d.contains('hurt') || d.contains('pain') ||
        d.contains('bleed') || d.contains('heart') || d.contains('breath') ||
        d.contains('stroke') || d.contains('cut') || d.contains('dizzy') ||
        d.contains('collapse') || d.contains('unconscious') || d.contains('choke') ||
        d.contains('seizure') || d.contains('convuls') || d.contains('faint') ||
        d.contains('allerg') || d.contains('overdose') || d.contains('drown') ||
        d.contains('swallow') || d.contains('poison')) {

      // Seizure / convulsions
      if (d.contains('seizure') || d.contains('convuls') || d.contains('shaking') || d.contains('fit')) {
        return '1. Clear the area — move furniture and hard objects away from the person.\n'
               '2. Place something soft (folded jacket, pillow) under their head immediately.\n'
               '3. Roll them onto their left side to keep the airway open and prevent choking.\n'
               '4. Time the seizure — note when it started and watch for breathing. Do NOT restrain them.';
      }
      // Choking
      if (d.contains('choke') || d.contains('cough') || d.contains('swallow')) {
        return '1. Stand behind them, place one foot forward for stability.\n'
               '2. Give 5 firm back blows between the shoulder blades with the heel of your hand.\n'
               '3. If that fails, perform the Heimlich: make a fist just above the navel and thrust inward and upward sharply.\n'
               '4. Alternate 5 back blows and 5 abdominal thrusts until the object is dislodged.';
      }
      // Cardiac / chest pain
      if (d.contains('heart') || d.contains('chest') || d.contains('cardiac') || d.contains('arrest')) {
        return '1. Sit the person down on the floor, leaning against a wall — do not let them stand.\n'
               '2. Loosen all tight clothing: collar, tie, belt, bra strap.\n'
               '3. If they are unconscious and not breathing, begin CPR: 30 hard, fast chest compressions then 2 rescue breaths.\n'
               '4. Locate the nearest AED defibrillator (hotel corridors/lobby) and send someone to get it now.';
      }
      // Stroke
      if (d.contains('stroke') || d.contains('face') || d.contains('numb') || d.contains('slur') || d.contains('drooping')) {
        return '1. FACE: Ask them to smile — check for lopsidedness on one side.\n'
               '2. ARMS: Ask them to raise both arms — watch if one drifts down.\n'
               '3. SPEECH: Ask them to repeat a simple sentence — listen for slurring.\n'
               '4. Lay them down with head and shoulders slightly raised. Do NOT give food or water.';
      }
      // Bleeding
      if (d.contains('bleed') || d.contains('cut') || d.contains('stab') || d.contains('wound')) {
        return '1. Apply HEAVY direct pressure with the cleanest cloth available — press hard and hold.\n'
               '2. Do NOT remove the cloth even when soaked — add more material on top.\n'
               '3. Elevate the wound above heart level if it is on a limb.\n'
               '4. If bleeding is from the neck or torso, keep pressure constant and keep the person still.';
      }
      // Fainting / unconscious
      if (d.contains('faint') || d.contains('unconscious') || d.contains('unresponsive') || d.contains('collapse')) {
        return '1. Lower them to the floor carefully — support the head.\n'
               '2. Raise their legs 12 inches to restore blood flow to the brain (unless head/neck injury suspected).\n'
               '3. Check for breathing every 30 seconds — if absent, begin CPR immediately.\n'
               '4. Loosen tight clothing around the neck and waist.';
      }
      // Allergic reaction / overdose / poisoning
      if (d.contains('allerg') || d.contains('overdose') || d.contains('poison') || d.contains('swollen') || d.contains('reaction')) {
        return '1. Check for an EpiPen on the person — if found, inject into the outer thigh and hold for 10 seconds.\n'
               '2. Lay them flat with legs raised unless breathing is difficult, then sit them upright.\n'
               '3. Loosen any tight clothing around the throat and chest.\n'
               '4. Do NOT give any food, drink, or medication by mouth if consciousness is impaired.';
      }
      // Drowning
      if (d.contains('drown') || d.contains('water') && d.contains('breath')) {
        return '1. Remove them from the water only if it is safe to do so — do not enter deep water without flotation.\n'
               '2. Lay them flat. If not breathing, begin CPR: 30 chest compressions then 2 rescue breaths.\n'
               '3. Keep them warm — remove wet clothing and cover with towels or jackets.\n'
               '4. Continue CPR without stopping until help arrives — drowning victims can be revived even after minutes.';
      }
      // Generic medical
      return '1. Keep the person still — do not move them unless they are in immediate physical danger.\n'
             '2. Check for responsiveness: tap shoulder and shout — note if they respond.\n'
             '3. Monitor breathing every 60 seconds — if absent, begin CPR immediately.\n'
             '4. Keep them warm and loosen any tight clothing around the neck and chest.';
    }

    // ── FIRE & INFRASTRUCTURE ────────────────────────────────────────────────
    if (selectedType == 'fire' || selectedType == 'infrastructure' ||
        d.contains('fire') || d.contains('smoke') || d.contains('gas') ||
        d.contains('leak') || d.contains('electric') || d.contains('burn') ||
        d.contains('spark') || d.contains('flood') || d.contains('collapse') ||
        d.contains('trapped') || d.contains('structural')) {

      if (d.contains('fire') || d.contains('smoke') || d.contains('burn')) {
        return '1. Evacuate NOW — leave all belongings and exit via the nearest stairwell. Do NOT use elevators.\n'
               '2. Feel door surfaces with the back of your hand before opening — if hot, do not open.\n'
               '3. Stay low: crawl if the corridor is smoky — clean air is within 12 inches of the floor.\n'
               '4. If you cannot evacuate, seal door gaps with wet towels and signal from the window.';
      }
      if (d.contains('gas') || d.contains('leak') || d.contains('smell')) {
        return '1. Do NOT touch any light switches, phones, or electrical devices — a spark can ignite the gas.\n'
               '2. Open all windows and doors as you leave — move quickly and quietly.\n'
               '3. Evacuate to the assembly point upwind (away from the building).\n'
               '4. Do not re-enter for any reason until the building is declared safe.';
      }
      if (d.contains('flood') || d.contains('water')) {
        return '1. Move immediately to the highest floor you can access.\n'
               '2. Do NOT attempt to walk through moving water deeper than ankle height.\n'
               '3. Avoid all electrical outlets, switches, and appliances.\n'
               '4. Signal from a window with a bright cloth or phone torch.';
      }
      if (d.contains('collapse') || d.contains('trapped') || d.contains('structural')) {
        return '1. Cover your nose and mouth with cloth to filter dust — breathe slowly.\n'
               '2. Do NOT light a match or lighter — gas leaks may be present.\n'
               '3. Tap on a pipe or wall repeatedly — rescuers use sound to locate survivors.\n'
               '4. Move as little as possible to conserve oxygen and avoid further collapse.';
      }
      return '1. Stay away from all standing water if electricity is a concern.\n'
             '2. Evacuate the immediate area and move to the nearest stairwell.\n'
             '3. Do NOT use elevators or touch metal surfaces.\n'
             '4. If trapped, signal from a window with a white cloth or bright object.';
    }

    // ── SECURITY ─────────────────────────────────────────────────────────────
    if (selectedType == 'security' ||
        d.contains('threat') || d.contains('intruder') || d.contains('gun') ||
        d.contains('shooter') || d.contains('attack') || d.contains('knife') ||
        d.contains('weapon') || d.contains('assault') || d.contains('rob') ||
        d.contains('stalk') || d.contains('harass')) {

      if (d.contains('gun') || d.contains('shooter') || d.contains('active') || d.contains('weapon') || d.contains('shot')) {
        return '1. RUN: If there is a clear, safe path out of the building, take it now. Leave all belongings.\n'
               '2. HIDE: If you cannot run, lock and barricade your door with heavy furniture. Kill all lights.\n'
               '3. SILENCE: Put all devices on silent. Stay away from doors and windows.\n'
               '4. FIGHT: Only as an absolute last resort — use improvised weapons (chair, lamp) to fight back aggressively.';
      }
      if (d.contains('assault') || d.contains('attack') || d.contains('hit') || d.contains('violent')) {
        return '1. Put as many locked doors between you and the threat as possible.\n'
               '2. Barricade the door with heavy furniture — bed, wardrobe, desk.\n'
               '3. Move to a corner of the room away from the door and out of line of sight from windows.\n'
               '4. Use your phone torch to signal SOS (3 short, 3 long, 3 short flashes) from the window.';
      }
      // Generic security
      return '1. Lock and deadbolt your room door immediately.\n'
             '2. Move away from the door and windows — position yourself in the bathroom or a corner.\n'
             '3. Do NOT open the door for anyone until you hear the verified staff All-Clear.\n'
             '4. Keep your phone charged and on silent — only use it to communicate if absolutely necessary.';
    }

    // ── GENERIC FALLBACK ─────────────────────────────────────────────────────
    return '1. Stay at your current location and keep your room door locked.\n'
           '2. Do not open the door to anyone until staff make direct voice contact.\n'
           '3. Check for any obvious hazards in your immediate area and move away from them.\n'
           '4. Your alert has been registered — help is being coordinated to your location.';
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
