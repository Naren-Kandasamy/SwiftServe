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
    if (alert.status != AlertStatus.pending) return;
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
You are an emergency triage AI for a hospitality venue.
Classify the incoming guest SOS alert and return ONLY valid JSON.
CRITICAL: If an image is provided, inspect it thoroughly. If you detect smoke, fire, weapons, blood, or structural collapse, boost severity to 4 or 5 and set escalateToEmergencyServices to true.

MULTILINGUAL SUPPORT: You must automatically detect the language the Guest SOS Message is written in. The `immediateInstructions` field you generate MUST be written in the exact same language the guest used. For example, if they type in Spanish, your instructions must be in Spanish.

Severity scale — use the FULL range 1–5:
1 = Minor nuisance. No danger. (e.g. noisy neighbour, lost key, dripping tap, mild headache)
2 = Low concern. Monitoring only. (e.g. small cut needing first aid, suspicious person seen briefly, flickering lights)
3 = Active incident. Staff response needed. (e.g. moderate injury, small fire in bin, security dispute, power outage affecting a room)
4 = Serious emergency. Emergency services likely needed. (e.g. cardiac arrest, large fire, assault, structural damage)
5 = Mass casualty / catastrophic. Emergency services required immediately. (e.g. explosion, mass stabbing, building collapse, gas leak with fire)

Default to 1 or 2 for vague or low-risk descriptions. Only go to 3+ when there is clear immediate danger.

Output format:
{
  "type": "fire" | "medical" | "security" | "infrastructure" | "other",
  "severity": <integer 1-5>,
  "immediateInstructions": "<3-4 sentence safety instruction IN THE EXACT SAME LANGUAGE AS THE SOS MESSAGE>",
  "language": "<ISO 639-1 code of guest's language>",
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

    // 2. Aggregate the raw Alert into an actionable Dashboard Incident
    final incidentId = 'inc_${alert.id.substring(0, 8)}';
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
      IncidentUpdate(timestamp: timestamp + 50, updateText: 'AI Triaged as ${parsedType.name.toUpperCase()} (Severity $severity).')
    ];

    // Explicitly add escalation to timeline so the user is notified
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
      imageUrl: resolvedImageUrl, // pass down the resolved image URL
      timeline: timeline,
    );

    await FirebaseDatabase.instance.ref('venues/$_venueId/incidents/$incidentId').set(incident.toMap());
    
    // Wake up background staff running the web dashboard via native push
    try {
      if (html.Notification.permission == 'granted') {
        html.Notification(
          '🚨 NEW ALERT: ${parsedType.name.toUpperCase()} (Severity ${triageResult['severity']})',
          body: 'Room ${alert.roomNumber}: ${alert.description}',
          icon: '/favicon.png', // Or similar absolute asset path
        );
      }
    } catch (_) {}

    // Mark as permanently done so stream re-fires are ignored
    _completedIds.add(alert.id);
    _processingIds.remove(alert.id);
  }
}
