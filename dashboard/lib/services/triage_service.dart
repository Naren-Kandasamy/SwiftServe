import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared/models/alert.dart';
import 'package:shared/models/incident.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class TriageService {
  static String get _geminiApiKey => dotenv.env['GEMINI_API_KEY'] ?? '';
  static const String _venueId = 'mockVenue123';
  
  // Track ids currently being computed (prevents re-entry during async)
  static final Set<String> _processingIds = {};
  // Track ids already fully processed (prevents re-fire from stream update)
  static final Set<String> _completedIds = {};

  static Future<void> processAlert(Alert alert) async {
    // Accept both 'pending' (needs AI triage) and 'triaged' (already has instructions
    // from the Guest App, just needs an Incident created on the dashboard)
    if (alert.status != AlertStatus.pending && alert.status != AlertStatus.triaged) return;
    if (_processingIds.contains(alert.id)) return;
    if (_completedIds.contains(alert.id)) return;  // already fully processed
    
    _processingIds.add(alert.id);
    print('[TriageService] Intercepted new SOS alert: ${alert.id}. Querying Gemini...');

    GenerativeModel? model;
    
    try {
      if (_geminiApiKey.isNotEmpty && _geminiApiKey.length > 10 && _geminiApiKey != 'YOUR_GEMINI_API_KEY') {
        model = GenerativeModel(
          model: 'gemini-2.5-flash',
          apiKey: _geminiApiKey,
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
      }
    } catch (_) {
      model = null;
    }

    final prompt = '''
You are a high-stakes emergency dispatcher AI for a premium hospitality venue.
Your mission is to provide cold, tactical, life-saving instructions to a guest in panic.

CRITICAL CONSTRAINTS:
1. DO NOT tell the user to "call 911", "contact management", or "find a staff member". Assume we have already done this.
2. DO NOT use conversational filler like "I'm sorry to hear that" or "Stay calm".
3. Provide ONLY specific, physical, tactical actions they must perform RIGHT NOW (e.g., "Press a clean towel into the wound", "Stay 12 inches from the floor to avoid smoke", "Barricade the door with heavy furniture").
4. If an image is provided, analyze it for specific hazards (blood, fire, weapons) and reference them in your instructions.

MULTILINGUAL SUPPORT: You MUST detect the guest's language. The `immediateInstructions` MUST be written in the exact same language.

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
  "immediateInstructions": "1. [Specific Tactical Step]\n2. [Specific Tactical Step]\n3. [Specific Tactical Step]",
  "language": "<ISO 639-1 code>",
  "escalateToEmergencyServices": <boolean>
}

Guest SOS Message: "${alert.description}"
Location: Room ${alert.roomNumber}, Floor ${alert.floor}
''';

    // Provide curated fallback advice immediately
    String curatedAdvice = "Help is on the way. Please stay calm.";
    int curatedSeverity = 3;
    switch (alert.type ?? EmergencyType.other) {
      case EmergencyType.fire:
        curatedAdvice = "Activate the nearest fire alarm and evacuate via the stairs immediately. Do NOT use elevators. Check doors for heat before opening.";
        curatedSeverity = 5;
        break;
      case EmergencyType.medical:
        curatedAdvice = "Do not move the patient unless they are in immediate danger. Clear the area for paramedics. If trained, apply firm pressure to any bleeding.";
        curatedSeverity = 4;
        break;
      case EmergencyType.security:
        curatedAdvice = "Lock and barricade doors if unsafe to leave. Do not confront the individual. Silence your device and stay entirely out of sight.";
        curatedSeverity = 4;
        break;
      case EmergencyType.infrastructure:
        curatedAdvice = "Stay away from exposed wires or structural damage. Do not attempt to fix anything. Await maintenance staff.";
        curatedSeverity = 2;
        break;
      case EmergencyType.other:
        curatedAdvice = "Help is on the way. Please distance yourself from any hazard and wait for staff updates.";
        curatedSeverity = 2;
        break;
    }

    Map<String, dynamic> triageResult = {
      "type": alert.type?.name ?? "other",
      "severity": curatedSeverity,
      "immediateInstructions": curatedAdvice,
      "escalateToEmergencyServices": false
    };

    // ── Short-circuit for already-triaged alerts ──────────────────────────────
    // If the Guest App's background Gemini call already triaged this alert before
    // any admin was logged in, we skip the AI call and just create the incident.
    if (alert.status == AlertStatus.triaged && alert.safetyInstructions != null) {
      print('[TriageService] Alert ${alert.id} already triaged by Guest App. Creating incident directly...');
      triageResult = {
        "type": alert.type?.name ?? "other",
        "severity": alert.severity ?? curatedSeverity,
        "immediateInstructions": alert.safetyInstructions,
        "escalateToEmergencyServices": (alert.severity ?? 3) >= 4,
      };
      // Skip all Gemini logic, jump straight to incident creation
      await _createIncident(alert, triageResult);
      _completedIds.add(alert.id);
      _processingIds.remove(alert.id);
      return;
    }

    int maxRetries = 3;
    bool success = false;
    String lastError = '';

    String? resolvedImageUrl = alert.imageUrl;

    // If imageUrl was marked 'pending_upload',
    // poll Firebase for only up to 6 seconds since we use fast Base64 updates now.
    if (resolvedImageUrl == 'pending_upload') {
      print('[TriageService] imageUrl is pending — waiting up to 6s for background upload...');
      for (int wait = 0; wait < 3; wait++) {
        await Future.delayed(const Duration(seconds: 2));
        final snap = await FirebaseDatabase.instance
            .ref('venues/$_venueId/alerts/${alert.id}/imageUrl')
            .get();
        if (snap.value != null && snap.value.toString() != 'pending_upload') {
          resolvedImageUrl = snap.value as String?;
          print('[TriageService] imageUrl arrived after ${(wait + 1) * 2}s: $resolvedImageUrl');
          break;
        }
      }
    }

    if (resolvedImageUrl == 'pending_upload') resolvedImageUrl = null; // timed out


    if (model != null) {
      List<Part> parts = [TextPart(prompt)];

      if (resolvedImageUrl != null && resolvedImageUrl.isNotEmpty) {
        try {
          print('[TriageService] Fetching SOS image for multimodal triage...');
          
          if (resolvedImageUrl.startsWith('data:image')) {
            print('[TriageService] Detected Base64 image. Decoding inline...');
            // extract base64 payload
            final base64String = resolvedImageUrl.split(',').last;
            final imageBytes = base64Decode(base64String);
            parts.add(DataPart('image/jpeg', imageBytes));
            print('[TriageService] Base64 Image (${imageBytes.length} bytes) streamed into Gemini context.');
          } else {
            final ref = FirebaseStorage.instance.refFromURL(resolvedImageUrl);
            final imageBytes = await ref.getData(10 * 1024 * 1024); // 10MB limit
            if (imageBytes != null) {
              parts.add(DataPart('image/jpeg', imageBytes));
              print('[TriageService] Firebase Storage Image (${imageBytes.length} bytes) streamed into Gemini context.');
            }
          }
        } catch(e) {
          print('[TriageService] Could not parse image for multimodal (skipping): $e');
        }
      }

      for (int i = 0; i < maxRetries; i++) {
        try {
          final response = await model.generateContent([Content.multi(parts)]);
          final text = response.text ?? '';
          final cleanJson = text.replaceAll('```json', '').replaceAll('```', '').trim();
          triageResult = jsonDecode(cleanJson);
          print('[TriageService] Gemini JSON parsed successfully!');
          success = true;
          break; // Exit loop on success
        } catch (e) {
          lastError = e.toString().split('\n').first;
          print('[TriageService] Gemini attempt ${i+1} failed: $lastError');
          
          // Exponential backoff buffer before hitting the free tier limit again
          if (i < maxRetries - 1) {
             await Future.delayed(Duration(milliseconds: 1500 * (i + 1)));
          }
        }
      }
      
      if (!success) {
        triageResult['immediateInstructions'] = 'AI Exception: $lastError\n\n$curatedAdvice';
      }
    } else {
      print('[TriageService] API key not found. Using high-quality curated fallback classification.');
      // Keep the curated triageResult established at the top.
    }

    // 1. Update the original Alert with AI guidance
    await FirebaseDatabase.instance.ref('venues/$_venueId/alerts/${alert.id}').update({
      'type': triageResult['type'],
      'severity': triageResult['severity'],
      'safetyInstructions': triageResult['immediateInstructions'],
      'status': AlertStatus.triaged.name,
    });

    await _createIncident(alert, triageResult, resolvedImageUrl: resolvedImageUrl);

    // Mark as permanently done so stream re-fires are ignored
    _completedIds.add(alert.id);
    _processingIds.remove(alert.id);
  }

  /// Aggregates a triaged alert into an actionable Dashboard Incident and
  /// fires a browser notification. Extracted so both the AI path and the
  /// short-circuit path (guest-app pre-triaged) can share this logic.
  static Future<void> _createIncident(
    Alert alert,
    Map<String, dynamic> triageResult, {
    String? resolvedImageUrl,
  }) async {
    final incidentId = 'inc_${alert.id.substring(0, 8)}';

    // Idempotency check: do NOT overwrite an incident that already exists
    final existingSnap = await FirebaseDatabase.instance
        .ref('venues/$_venueId/incidents/$incidentId')
        .get();
    if (existingSnap.exists) {
      print('[TriageService] Incident $incidentId already exists — skipping creation.');
      return;
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;

    EmergencyType parsedType = EmergencyType.other;
    try {
      final String triageType = triageResult['type']?.toString().toLowerCase() ?? 'other';
      parsedType = EmergencyType.values.firstWhere((e) => e.name.toLowerCase() == triageType);
    } catch (_) {}

    final severity = triageResult['severity'] as int? ?? 3;
    bool shouldEscalate = triageResult['escalateToEmergencyServices'] == true;

    // Auto-escalate severe fires (Level 4+)
    if (parsedType == EmergencyType.fire && severity >= 4) {
      shouldEscalate = true;
    }

    final timeline = [
      IncidentUpdate(timestamp: timestamp, updateText: 'SOS Received: "${alert.description}"'),
      IncidentUpdate(timestamp: timestamp + 50, updateText: 'AI Triaged as ${parsedType.name.toUpperCase()} (Severity $severity).'),
    ];

    if (shouldEscalate) {
      timeline.add(IncidentUpdate(timestamp: timestamp + 100, updateText: 'Escalated to Emergency Services'));
    }

    final incident = Incident(
      id: incidentId,
      venueId: _venueId,
      alertIds: [alert.id],
      type: parsedType,
      severity: severity,
      affectedZone: '${alert.roomNumber} (Floor ${alert.floor})',
      status: shouldEscalate ? IncidentStatus.escalated : IncidentStatus.active,
      guestCount: 1,
      createdAt: timestamp,
      imageUrl: resolvedImageUrl ?? alert.imageUrl,
      timeline: timeline,
      roomKey: alert.roomKey,
      medicalInfo: alert.medicalInfo,
    );

    await FirebaseDatabase.instance
        .ref('venues/$_venueId/incidents/$incidentId')
        .set(incident.toMap());

    // Wake up background staff via browser notification
    try {
      if (html.Notification.permission == 'granted') {
        html.Notification(
          '🚨 NEW ALERT: ${parsedType.name.toUpperCase()} (Severity $severity)',
          body: 'Room ${alert.roomNumber}: ${alert.description}',
          icon: '/favicon.png',
        );
      }
    } catch (_) {}
  }
}
