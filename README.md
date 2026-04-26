# CrisisNet — Emergency Response Platform

> Google Solution Challenge 2026 — Rapid Crisis Response (Problem Statement 2)

CrisisNet connects guests in distress, venue staff, and first responders on a single real-time network. It operates on a **progressive degradation architecture** — full AI capability when online, SMS + BLE mesh when offline, and pre-loaded emergency guides in a complete blackout.

---

## Sprint Schedule (Updated)

| Date | Focus | Owner |
|---|---|---|
| Apr 18–19 | **BLE Mesh** — real advertising + dashboard scanner | M1 + M2 |
| Apr 20 | **FCM Push Notifications** — background tab alerts | M2 |
| Apr 21 | **Firebase Auth** — replace mock credentials | M1 + M4 |
| Apr 22 | **Two-way Messaging** — staff ↔ guest chat | M1 + M2 |
| Apr 23 | **Role-based Dashboard** — Security / Medical / Management views | M2 |
| Apr 24 | **Post-incident Log + Analytics** | M2 |
| Apr 25 | **Gemini Nano** — offline AI fallback (Android) | M1 |
| Apr 26 | **Full end-to-end offline demo run** (Tiers 1→4) | All |
| Apr 27 | Polish, pitch deck, README, edge cases | All |
| **Apr 28** | **🎯 DEMO DAY** | All |

---

## Architecture

See [`CRISISNET_ARCHITECTURE.md`](./CRISISNET_ARCHITECTURE.md) — the single source of truth. Do not deviate from its data contracts or file ownership rules without team consensus.

---

## Project Structure

```
SwiftServe/
├── guest_app/          # Flutter Mobile — Guest SOS App (M1)
├── dashboard/          # Flutter Web — Staff Command Dashboard (M2)
├── shared/             # Shared Dart models (M4 — read-only for M1/M2/M3)
├── firebase/           # Firebase config, rules, Cloud Functions (M4)
└── CRISISNET_ARCHITECTURE.md
```

---

## Setup — Getting Started

### Prerequisites
- Flutter SDK 3.x
- Firebase CLI (`npm install -g firebase-tools`)
- A `.env` file in `dashboard/` (get the shared secret from M3)

### 1. Install dependencies
```bash
cd guest_app && flutter pub get
cd ../dashboard && flutter pub get
cd ../shared && flutter pub get
```

### 2. Create your `.env` file
```
# dashboard/.env
GEMINI_API_KEY=your_key_here
```

### 3. Run the Guest App (mobile or web)
```bash
cd guest_app
flutter run                  # Android/iOS device
flutter run -d chrome        # Browser
```

### 4. Run the Staff Dashboard
```bash
cd dashboard
flutter run -d chrome
```

---

## What's Working (Implemented)

| Feature | Status |
|---|---|
| SOS button + emergency type selector | ✅ |
| Voice-to-text dictation | ✅ |
| Photo attachment | ✅ |
| Floor + Room dropdown (venue-synced) | ✅ |
| Connectivity status badge (Online/Limited/Offline) | ✅ |
| GDPR consent before SOS | ✅ |
| Firebase Realtime DB write + triage pipeline | ✅ |
| Gemini 2.5 Flash classification + severity 1–5 | ✅ |
| Multimodal triage (image + text) | ✅ |
| Offline local queue (real upload on reconnect) | ✅ |
| SMS fallback (Tier 2) | ✅ |
| BLE beacon broadcast — skeleton (Tier 3) | ⚠️ In progress |
| Offline knowledge guides — 10 HTML pages | ✅ |
| Staff dashboard — live incident cards | ✅ |
| Sort/filter (time, severity, type) | ✅ |
| Venue map with floor tabs + incident pins | ✅ |
| Staff assignment + escalation | ✅ |
| Responder PDF brief (shareable link) | ✅ |

---

## Environment Variables

| Key | Used By | Notes |
|---|---|---|
| `GEMINI_API_KEY` | Dashboard | Google AI Studio key |
| Firebase config | Both apps | `google-services.json` (Android), `GoogleService-Info.plist` (iOS) |

All keys are gitignored. Do not commit them.

---

## Branch Strategy

| Branch | Purpose |
|---|---|
| `main` | Stable, demo-ready |
| `feat/tier-1-connectivity` | AI triage pipeline, venue map, PDF brief |
| `feat/progressive-degradation` | Offline resilience (Tiers 2–4) |

Always pull `main` before starting new work.
