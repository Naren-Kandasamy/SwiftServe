import 'dart:convert';
import 'package:http/http.dart' as http;
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
CRITICAL: If an image is provided alongside this text, inspect it thoroughly. If you detect ANY visual evidence of smoke, fire, weapons, significant blood, or structural collapse, aggressively boost the severity score to 4 or 5 and set escalateToEmergencyServices to true regardless of the guest's text description.

Output format:
{
  "type": "fire" | "medical" | "security" | "infrastructure" | "other",
  "severity": <integer 1-5>,
  "immediateInstructions": "<Provide highly detailed, 3-4 sentence step-by-step safety instructions specifically addressing the exact crisis described>",
  "escalateToEmergencyServices": <boolean, ONLY set to true if the situation requires immediate mass-evacuation or heavily armed response. Default to false for standard medical, fire, or security incidents that venue staff can respond to first.>
}

Guest SOS Message: "${alert.description}"
Location: Room ${alert.roomNumber}, Floor ${alert.floor}
''';

    Map<String, dynamic> triageResult = {
      "type": alert.type?.name ?? "other",
      "severity": 3,
      "immediateInstructions": "Help is on the way. Please stay calm.",
      "escalateToEmergencyServices": false
    };

    int maxRetries = 3;
    bool success = false;
    String lastError = '';

    if (model != null) {
      List<Part> parts = [TextPart(prompt)];
      if (alert.imageUrl != null && alert.imageUrl!.isNotEmpty) {
        try {
          print('[TriageService] Fetching SOS image attached to this alert...');
          final imageBytes = await http.readBytes(Uri.parse(alert.imageUrl!));
          parts.add(DataPart('image/jpeg', imageBytes));
          print('[TriageService] Image streamed into Gemini memory block successfully!');
        } catch(e) {
          print('[TriageService] Could not fetch image for multimodal: $e');
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
        triageResult['immediateInstructions'] = 'AI Exception: $lastError\n\nHelp is still on the way.';
      }
    } else {
      print('[TriageService] API key not found. Using fallback placeholder classification.');
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
      parsedType = EmergencyType.values.firstWhere((e) => e.name == triageResult['type']);
    } catch (_) {}

    final incident = Incident(
      id: incidentId,
      venueId: _venueId,
      alertIds: [alert.id],
      type: parsedType,
      severity: triageResult['severity'] as int? ?? 3,
      affectedZone: '${alert.roomNumber} (Floor ${alert.floor})',
      status: (triageResult['escalateToEmergencyServices'] == true) ? IncidentStatus.escalated : IncidentStatus.active,
      guestCount: 1,
      createdAt: timestamp,
      timeline: [
        IncidentUpdate(timestamp: timestamp, updateText: 'SOS Received: "${alert.description}"'),
        IncidentUpdate(timestamp: timestamp + 50, updateText: 'AI Triaged as ${parsedType.name.toUpperCase()} (Severity ${triageResult['severity'] ?? 3}).')
      ],
    );

    await FirebaseDatabase.instance.ref('venues/$_venueId/incidents/$incidentId').set(incident.toMap());
    
    // Mark as permanently done so stream re-fires are ignored
    _completedIds.add(alert.id);
    _processingIds.remove(alert.id);
  }
}
