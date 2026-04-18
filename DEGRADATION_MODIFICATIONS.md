# Progressive Degradation Layers - Modifications Log

This file tracks the architectural changes and implementations made to support the CrisisNet "Progressive Degradation" architecture (Tiers 2-4).

## Architecture Context
The CrisisNet system must never fully fail. When cloud connectivity is lost (Tier 1 -> Tier 2, 3, 4), the Guest App must gracefully degrade, queuing alerts locally, attempting SMS fallback, broadcasting via BLE Mesh, and surfacing offline first aid guides.

## Completed Modifications (April 2026 Sprint)

### 1. Dependencies added to `guest_app/pubspec.yaml`
- `connectivity_plus` (Network state detection)
- `flutter_blue_plus` (BLE Mesh advertising)
- `flutter_inappwebview` (Offline Knowledge Base rendering)
- `shared_preferences` (Local queueing)
- `url_launcher` (SMS intent)
- Registered `assets/knowledge/` in assets bundle.

### 2. Network State Management (`connectivity_service.dart`)
- Implemented `ConnectivityService` as a singleton.
- Added `ConnectivityTier` enum (`online`, `limited`, `offline`).
- Uses `connectivity_plus` combined with a DNS ping to 8.8.8.8 to verify actual internet reachability, avoiding false positives on captive portals.

### 3. Tier 2: SMS Fallback (`sms_fallback.dart`)
- Created `SmsFallbackService`.
- Triggers via `url_launcher` using the `sms:` URI scheme.
- Formats critical `Alert` data (type, ID, location, description) into a concise string under 160 characters.
- Uses mock staff emergency number: `+15550198000`.

### 4. Tier 3: BLE Mesh Beacon Protocol (`ble_service.dart`)
- Created `BleService` singleton.
- Encodes crisis data into an 11-byte payload: `[shortId(8)][type(1)][severity(1)][floor(1)]`.
- Designed for Android's background BLE advertising (iOS limitation). Note: actual `flutter_blue_plus` advertising implementation is mocked for MVP due to package API surface, but the routing and logic are established.

### 5. Tier 4: Offline Knowledge Base (`offline_knowledge.dart` & `assets/knowledge/`)
- Created `OfflineKnowledgeService` to map `EmergencyType` to specific HTML assets.
- Curated 10 standalone, zero-dependency HTML files inside `guest_app/assets/knowledge/`:
  - `fire.html`
  - `medical_cpr.html`
  - `choking.html`
  - `cardiac.html`
  - `gas_leak.html`
  - `earthquake.html`
  - `flood.html`
  - `security.html`
  - `burns.html`
  - `wounds.html`
  - `other.html`

### 6. Guest App UI Integration (`sos_screen.dart`)
- Injected real-time connectivity validation UI (Green/Orange/Red badges) to inform the user of system state.
- Refactored `_triggerSOS()` logic:
  - **If Online:** Normal Firebase Realtime Database insertion.
  - **If Offline:** 
    1. Queues alert locally via `SharedPreferences`.
    2. Broadcasts data via `BleService`.
    3. Prompts user with SMS fallback dialog.
    4. Automatically launches `OfflineKnowledgeService` with instructions matching the specific crisis type.

## Next Steps / Future Enhancements
- Fully implement the BLE scanner in the Responder App / Dashboard to act as edge-nodes picking up the BLE Mesh signals.
- Deploy a background sync worker mechanism (e.g. `workmanager`) that monitors the `local_alerts` queue and silently flushes it to Firebase once `connectivity_service` detects `ConnectivityTier.online` in the background.
