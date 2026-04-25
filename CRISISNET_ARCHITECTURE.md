# CrisisNet — Architecture & Implementation Guide

> Google Solution Challenge 2026 — Rapid Crisis Response (Problem Statement 2)
> This document is the single source of truth for the Antigravity agentic IDE.
> Read this fully before writing any code. Do not deviate from the data contracts, file ownership rules, or tech stack defined here.

---

## 1. Project Summary

CrisisNet is a hospitality emergency response platform that connects three actors — guests in distress, venue staff, and first responders — on a single real-time network. When a crisis occurs, a guest triggers an SOS, Gemini Flash classifies the emergency and scores its severity, all relevant staff are notified simultaneously via Firebase, and first responders receive a structured briefing packet before they arrive.

The system is built on a **progressive degradation architecture** — it operates at full AI capability when connected, falls back to on-device Gemini Nano and SMS when connectivity is weak, uses BLE mesh gossip protocol when there is no internet, and serves pre-loaded offline knowledge content in a complete blackout. The system never fully fails.

**SDG alignment:**
- SDG 3 — Good Health and Wellbeing (faster emergency response saves lives)
- SDG 11 — Sustainable Cities and Communities (resilient public venue infrastructure)
- SDG 16 — Peace, Justice and Strong Institutions (auditable emergency protocols)

---

## 2. Tech Stack — Google Technologies

All AI, backend, and infrastructure must use Google technologies as mandated by the hackathon.

| Layer | Technology | Purpose |
|---|---|---|
| Mobile app | Flutter 3.x | Guest SOS app — iOS + Android + Web |
| Web app | Flutter Web | Staff command dashboard |
| Realtime backend | Firebase Realtime Database (Asia-SE1) | Sub-100ms incident sync across all clients |
| Auth | Firebase Authentication | Guest and staff login (pending integration) |
| Push notifications | Firebase Cloud Messaging (FCM) | Alert staff devices even when app is backgrounded (pending) |
| ~~Serverless backend~~ | ~~Firebase Cloud Functions (Node.js)~~ | **Deprecated** — requires Blaze paid plan. Replaced by in-app TriageService. |
| Primary AI | **Gemini 2.5 Flash (via Google AI Studio Developer API)** | Emergency classification, severity scoring, instruction generation. Called directly from Dashboard Dart code. |
| On-device AI | Gemini Nano (Android) | Offline classification fallback — planned, not yet implemented |
| Voice transcription | **`speech_to_text` Flutter package (native OS engine)** | Streams real-time transcription; uses Chrome Web Speech API on web, Siri on iOS, Google on Android — **zero cost, no API key required** |
| Image analysis | ~~Google Cloud Vision API~~ | **Deprecated** — AI Triage handles image analysis directly via Gemini Flash Multimodal in the dashboard. |
| Translation | Google Cloud Translation API | Planned — not yet implemented |
| Maps | Google Maps SDK (Flutter + JS) | Venue floor plan overlay, incident pinning (partial implementation) |
| Offline knowledge | Curated HTML assets | Planned — not yet implemented |
| BLE mesh | flutter_blue_plus | Planned — not yet implemented |
| Connectivity detection | connectivity_plus | Planned — not yet implemented |
| Hosting | Firebase Hosting | Planned deployment target |
| Storage | Firebase Storage | Planned — not yet implemented |
| Secret Management | **`flutter_dotenv`** | Keeps API keys out of version control via `.env` + `.gitignore` |

---

## 3. System Architecture — Five Modules

### Module 1 — Guest SOS App (Flutter Mobile)
**Owner: Member 1**
**Platform: iOS + Android**

The guest-facing mobile application. UI is minimal by design — a person in a crisis must be able to trigger an alert within three seconds of opening the app.

**Features:**
- One-tap SOS panic button (full-screen, cannot be missed)
- Emergency type selector: Fire / Medical / Security / Infrastructure / Other
- Voice input via Google Cloud Speech-to-Text API (streaming, real-time transcription)
- Photo attachment — image sent to Cloud Vision API for analysis
- QR code check-in on venue arrival to register room number and floor
- Real-time status feed — guest sees "Help dispatched", "Security en route", "ETA 3 min"
- Gemini-generated context-aware safety instructions pushed to guest
- Two-way messaging with assigned staff member
- Connectivity status indicator: Online / Limited / Offline — BLE active
- BLE offline fallback (Android only) — broadcasts alert as BLE beacon when Firebase unreachable
- SMS fallback (iOS and Android) — sends alert to pre-registered staff number via native SMS when offline
- Local alert queue — stores alerts locally and syncs immediately on reconnect

**Key files:**
```
lib/screens/sos_screen.dart          — main SOS UI
lib/screens/status_screen.dart       — post-alert status feed
lib/screens/checkin_screen.dart      — QR check-in flow
lib/screens/knowledge_library_screen.dart — UI Grid for the full offline emergency directory
lib/services/ble_service.dart        — BLE mesh advertising
lib/services/ble_scanner_service.dart— BLE mesh scanning and relay
lib/services/sms_fallback.dart       — SMS offline fallback
lib/services/speech_service.dart     — Speech-to-Text integration
lib/services/connectivity_service.dart — tier detection and mode switching
lib/services/offline_knowledge.dart  — local HTML knowledge base loader
```

---

### Module 2 — Staff Command Dashboard (Flutter Web)
**Owner: Member 2**
**Platform: Web (Flutter Web, runs in any browser)**

The venue staff nerve centre. Runs on tablets at the front desk, phones for security guards, and desktop for management. Shows a unified real-time picture of all active incidents across the venue.

**Features:**
- Live incident map — venue floor plan overlay on Google Maps with incidents pinned and colour-coded by severity (1=gray, 2=blue, 3=amber, 4=orange, 5=red)
- Incident cards — show who raised the alert, when, where, AI classification, severity score, current status, and assigned responders
- Task assignment — assign specific teams (e.g., Sec 1, Med Alpha) to incidents with real-time tracking
- Two-way guest messaging — staff sends reassurance and instructions directly to the distressed guest
- Internal Staff Chat — private team-to-team coordination channel with role/team identifiers
- One-tap escalation — upgrade severity, add response teams, trigger responder brief generation
- Team-based views — Teams only see incidents explicitly assigned to their Team ID; Admins see all raw and active incidents
- FCM push notifications — staff alerted even when dashboard tab is not in focus
- Responder brief trigger — generates and copies shareable link for emergency services
- Post-incident log — full timeline, response times, actions taken, outcome

**Key files:**
```
lib/screens/dashboard_screen.dart    — main dashboard
lib/screens/incident_detail.dart     — expanded incident view
lib/widgets/incident_card.dart       — incident card component
lib/widgets/venue_map.dart           — Google Maps floor plan overlay
lib/widgets/severity_badge.dart      — colour-coded severity indicator
lib/services/task_service.dart       — task assignment logic
lib/services/dashboard_fcm.dart      — web push notification handler
```

---

### Module 3 — AI Triage Engine (Gemini Developer API — Serverless)
**Owner: Member 3**
**Runtime: Dart, embedded inside Staff Command Dashboard (`dashboard/lib/services/triage_service.dart`)**

> **Architecture Delta:** The original plan used Firebase Cloud Functions (Node.js) with Vertex AI. This required the **Blaze (pay-as-you-go) billing plan**, which was infeasible for a hackathon prototype. The implementation was redesigned to be **fully serverless and zero-cost** by moving the AI logic directly into the Dashboard Flutter Web app.

The intelligence layer. Every alert written to `/venues/{venueId}/alerts/` is intercepted by the Dashboard's real-time listener before it is broadcast to staff. It is immediately classified by Gemini without requiring any backend server.

**How it works:**
1. Dashboard subscribes to `/venues/{venueId}/alerts/` via Firebase Realtime Database `.onValue` stream.
2. When a new alert arrives with `status: pending`, `TriageService.processAlert(alert)` is called.
3. `TriageService` calls **Gemini 2.5 Flash** via the `google_generative_ai` Dart package using the Google AI Studio Developer API key.
4. Gemini returns a strict JSON object: `{ type, severity, immediateInstructions, escalateToEmergencyServices }`
5. The service writes the result back to `/alerts/{id}` (updating type, severity, safetyInstructions, status=triaged).
6. A new structured **Incident** document is written to `/incidents/{id}` for staff to action.
7. The Guest App listens to its own alert document and surfaces a full-screen modal with Gemini's safety instructions.

**Resilience features implemented:**
- Exponential backoff retry loop (3 attempts, 1.5s/3s/4.5s delays) to handle rate limiting gracefully.
- Safety filter bypass (`HarmBlockThreshold.none`) to allow processing of violent emergency descriptions.
- Fallback logic preserves the user's manually selected emergency type if Gemini fails.
- Error text is surfaced to the guest modal so failures are visible, not silent.

**Key files:**
```
dashboard/lib/services/triage_service.dart   — Main AI triage engine (Gemini 2.5 Flash)
dashboard/lib/screens/dashboard_screen.dart  — Listens to /alerts/ and invokes TriageService
guest_app/lib/screens/sos_screen.dart        — Listens for triage result and shows instruction modal
```

**Secret management:**
- API Key stored in `dashboard/.env` (gitignored)
- Loaded at runtime via `flutter_dotenv` package
- Team members must create their own `.env` file from the shared secret

---

### Module 4 — Backend, Firebase Architecture & Responder Brief System
**Owner: Member 4**
**This module must be started and schema locked by end of Day 2. All other modules depend on it.**

Owns the Firebase data architecture, security rules, shared data models, and the responder briefing system. Acts as the integration lead — ensures all modules use consistent data contracts.

**Responsibilities:**
- Design and maintain the full Firebase Realtime Database schema
- Write and maintain Firebase security rules (guests can only write alerts, staff can read/update)
- Define all shared data model classes in `lib/models/` — these are read-only for all other agents
- Maintain the venue configuration system (floor plans, staff roster, room counts)
- Build the responder brief generation pipeline client-side directly within `dashboard/lib/services/pdf_service.dart`

**Key files:**
```
lib/models/alert.dart              — Alert data model (shared, read-only for M1/M2/M3)
lib/models/incident.dart           — Incident data model
lib/models/user.dart               — User + role model
lib/models/venue.dart              — Venue + floor plan model
lib/services/firebase_service.dart — Firebase read/write helpers (shared)
dashboard/lib/services/pdf_service.dart — Fully native PDF Brief generation
database.rules.json                — Realtime DB security rules
firestore.rules                    — Firestore security rules
docs/responder_brief_template.md   — Brief format template
docs/floorplan_schema.json         — Floor plan data format
```

---

### Module 5 — Offline Knowledge Base
**Owner: Member 3 (content) + Member 1 (Flutter integration)**
**Effort: ~1 day total. Content: half day (M3). Flutter loader: half day (M1).**

Pre-loaded emergency reference content bundled as local HTML assets. Inspired by the Kiwix/ZIM open offline knowledge model. Works with zero internet, zero power from external sources — renders from the device's local storage via Flutter WebView.

**Content pages to curate (M3 responsible):**
- Fire emergency — what to do if you smell smoke or see fire
- Medical emergency — CPR guide with step-by-step instructions
- Choking — Heimlich manoeuvre guide
- Cardiac arrest — AED usage guide
- Chemical/gas leak — evacuation and exposure response
- Earthquake — drop, cover, hold procedure
- Flood — evacuation and shelter procedure
- Security threat — lockdown and shelter-in-place procedure
- Burn treatment — immediate first aid for burns
- Wound management — bleeding control and shock prevention

**Implementation:**
- Pages are clean, minimal HTML files stored in `assets/knowledge/`
- Loaded via `flutter_inappwebview` package — renders locally, no network call
- Each page is tagged with emergency type so the app auto-opens the relevant page after Gemini Nano classification
- Pages are written in English by default; basic translations for top 5 languages bundled as separate files
- In the pitch: "This is the simplified version of our Kiwix/ZIM integration — in production this expands to full Wikipedia Medical and Red Cross ZIM dumps"

**Key files:**
```
assets/knowledge/fire.html
assets/knowledge/medical_cpr.html
assets/knowledge/choking.html
assets/knowledge/cardiac.html
assets/knowledge/gas_leak.html
assets/knowledge/earthquake.html
assets/knowledge/flood.html
assets/knowledge/security.html
assets/knowledge/burns.html
assets/knowledge/wounds.html
lib/services/offline_knowledge.dart   — maps emergency type → HTML asset path
```

---

## 4. Data Schema — Single Source of Truth

**DO NOT modify these schemas without updating this document and informing all team members. All agents must use these exact field names.**

### Alert object
Written by Guest App (M1), processed by AI Engine (M3), read by Dashboard (M2).

```dart
class Alert {
  String id;               // uuid v4
  String userId;           // Firebase Auth UID
  String venueId;          // venue identifier
  String roomNumber;       // e.g. "412"
  int floor;               // e.g. 4
  String description;      // raw guest input text
  String? imageUrl;        // Firebase Storage URL if photo attached
  EmergencyType type;      // enum — set by Gemini, initially null
  int? severity;           // 1–5 — set by Gemini, initially null
  GeoPoint location;       // GPS coordinates
  int timestamp;           // Unix milliseconds
  AlertStatus status;      // enum
  List<String> assignedTeams; // IDs of teams assigned (e.g. ["sec_01"])
  String? responderBriefUrl;
  String? language;        // ISO 639-1, detected by Gemini
  String? safetyInstructions; // generated by Gemini
}

enum EmergencyType { fire, medical, security, infrastructure, other }
enum AlertStatus { pending, triaged, acknowledged, inProgress, resolved }
```

### Incident object
Created by AI Engine (M3) after triage. Aggregates one or more related alerts.

```dart
class Incident {
  String id;
  String venueId;
  List<String> alertIds;   // all alerts belonging to this incident
  EmergencyType type;
  int severity;            // 1–5, may upgrade over time
  String affectedZone;     // e.g. "Floor 4 East Wing"
  int guestCount;          // from venue occupancy data
  IncidentStatus status;
  int createdAt;
  int? resolvedAt;
  List<IncidentUpdate> timeline; // chronological log of all updates
  String? responderBriefUrl;
  String? imageUrl; // Optional image evidence
  String? requestedResolutionBy; // Team ID requesting closure
  List<String> assignedTeams; // IDs of teams currently on the case
}

enum IncidentStatus { active, escalated, contained, reviewPending, resolved }
```

### User object

```dart
class AppUser {
  String id;               // Firebase Auth UID
  String name;
  String venueId;
  UserRole role;
  String? teamId;          // e.g. "sec_01", "hq"
  String? roomNumber;      // guests only
  int? floor;              // guests only
  String? fcmToken;        // for push notifications
  bool hasFirstAid;        // staff only — for priority routing
}

enum UserRole { guest, security, medical, management, admin }
```

### Firebase Realtime Database structure

```
/venues/{venueId}/
  /config/
    name: string
    address: string
    floorCount: int
    floorPlans/{floor}: { imageUrl, width, height, rooms: [{id, number, x, y}] }
    staffRoster/{userId}: { name, role, teamId, fcmToken, hasFirstAid }
  /alerts/{alertId}: Alert object
  /incidents/{incidentId}: Incident object
  /messages/{incidentId}/{messageId}: { senderId, text, timestamp, isStaff }
  /internal_messages/{incidentId}/{messageId}: { senderId, text, timestamp, isStaff }
```

---

## 5. Progressive Degradation Architecture

The app detects connectivity using `connectivity_plus` and switches modes automatically. The user sees only a small status badge — Online / Limited / Offline.

### Tier 1 — Full connectivity (WiFi + cell + power)
- Gemini Flash via Cloud Functions — full triage, multilingual, image analysis
- Firebase Realtime DB — sub-100ms sync
- Google Cloud Speech-to-Text — streaming voice transcription
- Cloud Vision API — photo analysis
- FCM push notifications
- AI-generated responder brief with shareable link
- Full staff dashboard with live map

### Tier 2 — Weak or intermittent cell
- Gemini Nano on-device — basic classification, no cloud call
- SMS fallback — alert sent via native SMS to pre-registered staff numbers
- Android SpeechRecognizer — offline voice transcription
- Cached floor plan — pre-downloaded on app install
- Local alert queue — alerts stored locally, synced on reconnect
- Pre-written instruction templates served from cache instead of Gemini

### Tier 3 — No internet, power on
- BLE mesh (Android only) — gossip protocol relay between staff devices
- Gemini Nano — on-device classification and severity scoring
- Offline Knowledge Base — Kiwix-inspired HTML emergency guides open automatically
- Device-to-device messaging via BLE
- Full local incident log — syncs when connectivity returns
- iOS devices: SMS only (no BLE background mode on iOS)

### Tier 4 — Complete blackout (no power, no signal)
- BLE mesh on battery — phones run on battery, BLE uses ~1% battery per hour
- Gemini Nano on battery — classification still works
- Offline Knowledge Base — pre-loaded emergency reference content
- All alerts queued locally, full sync the moment any connectivity returns

### Auto-switch logic (connectivity_service.dart)
```dart
connectivityStream.listen((status) {
  if (status == ConnectivityResult.wifi || status == ConnectivityResult.mobile) {
    if (await _canReachFirebase()) {
      _setTier(ConnectivityTier.online);
    } else {
      _setTier(ConnectivityTier.degraded);
    }
  } else {
    _setTier(ConnectivityTier.offline);
    if (Platform.isAndroid) BLEService.startMesh();
  }
});
```

---

## 6. BLE Mesh — Gossip Protocol (Android Only)

When offline, the Guest App advertises a compact BLE beacon containing the encoded alert payload. Any staff device with the app running within BLE range (~50m) picks it up and relays it to the next available device. This is a simplified gossip protocol — each device rebroadcasts any alert it has not seen before (deduplication by alert ID).

**Beacon payload format (compact, fits in BLE advertising packet):**
```
[alertId: 8 bytes][type: 1 byte][severity: 1 byte][floor: 1 byte][timestamp: 4 bytes]
= 15 bytes total — fits within BLE 31-byte advertising limit
```

**Deduplication:** Each device maintains a Set of seen alert IDs in memory. If the incoming alertId is already in the set, the beacon is ignored. Otherwise it is relayed and added to the set.

**Sync on reconnect:** When the device regains any connectivity, the full locally-queued alert is written to Firebase Realtime DB with its original timestamp, so the incident timeline is accurate.

**iOS limitation:** iOS does not allow BLE peripheral advertising in the background. iOS devices fall back to SMS. This is acknowledged in the architecture and flagged as a post-hackathon roadmap item.

---

## 7. AI Integration Details

### Gemini Flash — classification prompt structure
```
System: You are an emergency triage system for a hospitality venue.
Classify the incoming alert and return ONLY valid JSON. No explanation.

Output format:
{
  "type": "fire|medical|security|infrastructure|other",
  "severity": 1-5,
  "confidence": 0.0-1.0,
  "language": "ISO 639-1 code",
  "routingTargets": ["security"|"medical"|"management"|"maintenance"],
  "immediateInstructions": "2-3 sentence safety instruction for the guest",
  "escalateToEmergencyServices": true|false
}

Severity scale:
1 = Minor inconvenience, no immediate danger
2 = Potential hazard, monitoring required
3 = Active danger, immediate staff response needed
4 = Life risk, emergency services likely needed
5 = Mass casualty / catastrophic, emergency services required immediately

User alert: "{description}"
Location: Floor {floor}, Room {roomNumber}
Venue type: Hotel
Additional visual context: {imageAnalysisResult or "none"}
```

### Gemini Nano — offline fallback
Gemini Nano is accessed via the Android ML Kit / AICore API. It handles basic classification only — type and severity. Instruction generation falls back to pre-written templates keyed by emergency type when Nano is the only available model.

### Gemini Native Multimodal — Image Analysis Pipeline
> **Architecture Delta:** We abandoned Cloud Vision API entirely in favor of sending the attached image strictly as a `DataPart` directly into the Gemini 2.5 Flash classifier natively. This vastly simplified architecture and reduced latency.

1. Guest attaches photo in SOS screen (compressed natively using `maxWidth` and `imageQuality`)
2. Image uploaded to Firebase Storage, URL stored in alert `imageUrl`
3. Dashboard app's `TriageService` securely downloads the image stream via `FirebaseStorage.instance.refFromURL().getData()`
4. Image bytecode bound strictly to the `prompt` payload
5. Gemini independently determines labels, severity, and visual context entirely off the raw byte stream

---

## 8. File Ownership — Antigravity Agent Rules

Each agent owns specific files. **No agent modifies another agent's files.**
Shared files in `lib/models/` and `lib/services/firebase_service.dart` are owned exclusively by Member 4. All other members read these files only.

| File / Directory | Owner | Notes |
|---|---|---|
| `lib/models/` | M4 | All model files. Read-only for M1, M2, M3. |
| `lib/services/firebase_service.dart` | M4 | Shared Firebase helpers. |
| `lib/services/ble_service.dart` | M1 | BLE mesh implementation |
| `lib/services/speech_service.dart` | M1 | Speech-to-Text integration |
| `lib/services/sms_fallback.dart` | M1 | SMS offline fallback |
| `lib/services/offline_knowledge.dart` | M1 | Knowledge base loader |
| `lib/screens/sos_screen.dart` | M1 | SOS UI |
| `lib/screens/status_screen.dart` | M1 | Post-alert status feed |
| `lib/screens/dashboard_screen.dart` | M2 | Staff dashboard |
| `lib/widgets/incident_card.dart` | M2 | Incident card component |
| `lib/widgets/venue_map.dart` | M2 | Google Maps overlay |
| `lib/services/task_service.dart` | M2 | Task assignment logic |
| `dashboard/lib/services/pdf_service.dart` | M4 | Client-side Responder Brief Generator |
| `functions/src/classifyAlert.js` | M3 | **Deprecated** due to serverless TriageService |
| `functions/src/generateInstructions.js`| M3 | **Deprecated** |
| `functions/src/analyseImage.js` | M3 | **Deprecated** due to native Multimodal |
| `functions/src/detectEscalation.js` | M3 | Pattern detection |
| `functions/src/prompts/` | M3 | All Gemini prompt templates |
| `database.rules.json` | M4 | Firebase security rules |
| `assets/knowledge/` | M3 (content) | HTML knowledge pages |

---

## 9. Cross-Module Contracts — Must Be Agreed Before Coding

These are the integration points between modules. Member 4 defines, all others implement against.

**Contract 1 — Alert write format (M1 → Firebase → M3)**
M1 writes a new Alert object to `/venues/{venueId}/alerts/{alertId}`.
M3's `classifyAlert` Cloud Function is triggered by this write.
M1 must never write a partial alert — all required fields must be present.

**Contract 2 — Classified incident broadcast (M3 → Firebase → M2)**
After classification, M3 writes the updated alert (with type, severity, instructions) and creates a new Incident document.
M2's dashboard listener subscribes to `/venues/{venueId}/incidents/` and renders new incident cards in real time.

**Contract 3 — Guest status updates (M2 → Firebase → M1)**
Staff messages and status updates are written to `/venues/{venueId}/messages/{incidentId}/`.
M1's status screen subscribes to this path and renders updates in the guest's feed.

**Contract 4 — Responder brief generation (M2 triggers → M4 generates)**
M2's "Escalate to 911" button calls the `PdfService.generateBriefUrl()` method inside the dashboard context with the incidentId.
M4's package natively builds the visual PDF and spawns a temporary Web Blob URL which the staff manually shares or downloads.

**Contract 5 — BLE to Firebase sync (M1 offline → M4 schema)**
When BLE-received alerts are synced to Firebase on reconnect, M1 must write the full Alert object using M4's schema with the original offline timestamp, not the sync timestamp.

---

## 10. Environment Variables & API Keys

Store all keys in `.env` (never commit to git). Firebase config goes in `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) — these are gitignored.

```
GEMINI_API_KEY=
GOOGLE_CLOUD_SPEECH_API_KEY=
GOOGLE_CLOUD_VISION_API_KEY=
GOOGLE_MAPS_API_KEY=
FIREBASE_PROJECT_ID=
FIREBASE_DATABASE_URL=
```

Cloud Functions access Gemini via the Vertex AI SDK with Application Default Credentials — no hardcoded API key in function code.

---

## 11. Flutter Package Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter
  firebase_core: ^2.x
  firebase_auth: ^4.x
  firebase_database: ^10.x          # Realtime DB
  firebase_storage: ^11.x
  firebase_messaging: ^14.x         # FCM
  cloud_functions: ^4.x
  google_maps_flutter: ^2.x
  speech_to_text: ^6.x              # offline STT fallback
  flutter_blue_plus: ^1.x           # BLE mesh
  connectivity_plus: ^5.x           # tier detection
  flutter_inappwebview: ^6.x        # offline knowledge base
  mobile_scanner: ^3.x              # QR check-in
  image_picker: ^1.x                # photo attachment
  uuid: ^4.x                        # alert ID generation
  shared_preferences: ^2.x          # local alert queue storage
```

---

## 12. 12-Day Sprint Timeline

**Deadline: April 24, 2026 — MVP submission**
**Registration: April 12, 2026 — already done**

| Day | M1 (Guest App) | M2 (Dashboard) | M3 (AI Engine) | M4 (Backend) |
|---|---|---|---|---|
| 1 | Flutter project scaffold, Firebase init | Flutter Web scaffold, Firebase init | Cloud Functions project scaffold | **Firebase schema design — MUST COMPLETE** |
| 2 | SOS screen UI (no logic yet) | Dashboard layout + incident card component | Gemini classification prompt — first iteration | Data models in `lib/models/`, security rules, share contracts with team |
| 3 | Wire SOS button → Firebase write | Firebase Realtime DB listener → live cards | `classifyAlert` function — end to end working | `generateResponderBrief` function skeleton |
| 4 | Voice input (Speech-to-Text API) | Google Maps integration + floor plan overlay | `generateInstructions` function + FCM push to guest | Venue config system + occupancy data structure |
| 5 | Photo attachment → Cloud Vision pipeline | Severity colour coding + incident map pins | `analyseImage` function, integrate with classify | Responder brief — full assembly + public link generation |
| 6 | Real-time status feed + guest messaging | Task assignment + staff acknowledgement | `detectEscalation` function | Integration testing — all modules end to end |
| 7 | Gemini Nano offline fallback | Role-based view filtering | Prompt refinement + multilingual support | Firebase security rules audit + performance |
| 8 | BLE mesh — advertising + scanning (Android) | FCM web push notifications | Offline keyword classifier fallback | BLE → Firebase sync on reconnect |
| 9 | SMS fallback (iOS + Android) | Responder brief UI + share flow | Offline knowledge content — curate 10 HTML pages | Full offline Tier 3/4 integration test |
| 10 | QR check-in flow | Post-incident log + analytics view | Offline knowledge base loader (flutter_inappwebview) | End-to-end flow test all tiers |
| 11 | Polish + edge cases | Polish + accessibility | Test classification accuracy on edge inputs | Load test + security audit |
| 12 | Demo prep + README | Demo prep + screenshots | Demo prep + pitch narrative | Final deployment + submission |

**Daily sync protocol:**
- Morning (5 min): M4 posts any schema changes to team. All agents load updated AGENTS.md.
- Midday (10 min): Each member reports done/blocked/changed. Any shared file changes → everyone resets agent context.
- Evening (15 min): All members commit. M4 resolves conflicts, updates PROGRESS.md.

---

## 13. Demo Script (60 seconds for judges)

1. Member 1 opens guest app on Android phone. Types: "I smell gas in my room."
2. Judge watches staff dashboard on laptop — incident card appears in real time, pinned to floor map.
3. Dashboard shows Gemini classification: "Gas leak — Severity 4 — route to Security + Maintenance."
4. Member 2 clicks "Generate Responder Brief" — shows structured page: floor, wing, guest count, entry points.
5. Member 1's phone shows: "Help is coming. Leave your room now. Do not operate any switches. Use the stairwell on your left." — generated by Gemini in the guest's language.
6. Member 1 turns off WiFi on the phone. Hits SOS again. BLE indicator lights up. Dashboard receives the alert via BLE relay from a second Android device acting as a relay node.
7. Member 1 opens Offline Knowledge page — full first aid guide loads instantly, zero internet.

**Total demo time: under 60 seconds. End with:** "The system never fully fails — it degrades gracefully from full AI coordination to BLE mesh and offline knowledge, because emergencies don't wait for good WiFi."

---

## 14. Pitch Narrative — SDG Story

Open with: "Every year, thousands of people die in preventable hospitality emergencies — not because help wasn't available, but because the right information didn't reach the right people in time."

Core claim: "CrisisNet eliminates the communication gap between a guest in danger, the staff who can help, and the first responders who need to be ready before they arrive."

Technical differentiator: "We're the only team that built a system that works when the infrastructure fails. Using BLE mesh gossip protocol — technology we've previously implemented for natural disaster scenarios — combined with on-device Gemini Nano and an offline-first knowledge base inspired by the Kiwix open knowledge model, CrisisNet functions in a complete blackout."

SDG close: "Every minute saved in emergency response is lives protected. We're targeting a 30% reduction in coordination time — a measurable, direct contribution to SDG 3, SDG 11, and SDG 16."

Future roadmap: "Post-hackathon: full Kiwix ZIM dump integration for Wikipedia Medical and Red Cross content, iOS BLE mesh support, and expansion to airports, hospitals, and public event venues."

---

*End of architecture document. Version 1.0 — locked April 12, 2026.*
*Do not modify data schemas or file ownership assignments without team consensus.*
