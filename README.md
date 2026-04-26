# CrisisNet — The Emergency Response OS for High-Density Venues

> **Google Solution Challenge 2026** — *Empowering guests and responders through intelligent, resilient coordination.*

CrisisNet is a mission-critical emergency response platform designed for hotels, stadiums, and campuses. It bridges the gap between a guest in distress and a rapid response team, ensuring that **no one is left in the dark during a crisis**, even when connectivity fails.

---

## 🚀 Project Overview

In high-density venues, emergency communication is often fragmented. Guests struggle to report their exact location, roommates are left out of the loop, and staff are overwhelmed by unclassified alerts.

**CrisisNet solves this with three core innovations:**
1.  **Per-Stay Session Persistence:** Guests are assigned a 6-character, ephemeral Room Token (e.g., `J K 4 M N R`). This allows roommates to instantly sync to the same emergency and view live status updates without needing an account.
2.  **AI-Driven Triage:** Using **Gemini 2.5 Flash**, every SOS is automatically classified by type (Fire, Medical, Security) and severity (1-5), providing staff with a prioritized command view.
3.  **Progressive Degradation:** The system never fully fails. It gracefully transitions through 4 tiers of connectivity, from full Cloud AI to local SMS fallback and offline knowledge libraries.

---

## 🏗️ Architecture & Tech Stack

CrisisNet is built entirely on the **Google Technology Stack** for maximum scale and reliability.

### 4-Tier Resilience Model
| Tier | Connectivity | Features |
|---|---|---|
| **Tier 1: Online** | WiFi / 5G | Full Cloud AI Triage (Gemini), Real-time Firebase Sync, Live Staff Chat. |
| **Tier 2: Limited** | Intermittent Data | Local Queuing, Background Retry, Cached Floor Plans. |
| **Tier 3: SMS Fallback**| No Data | Transparently switches to SMS reporting to notify staff numbers directly. |
| **Tier 4: Blackout** | No Signal | Access to a pre-loaded, interactive Emergency Knowledge Library (Offline HTML/JS). |

### Technology Stack
- **Frontend:** Flutter 3.x (iOS, Android, and Web)
- **Realtime Backend:** Firebase Realtime Database
- **Intelligence:** Gemini 2.5 Flash (via Google AI Studio API)
- **Authentication:** Firebase Anonymous Auth
- **Infrastructure:** Firebase Hosting & Storage

---

## 🛠️ Project Structure

```bash
SwiftServe/
├── guest_app/          # Flutter Mobile/Web — High-contrast Guest SOS Interface
├── dashboard/          # Flutter Web — Real-time Staff Command & Control Center
├── shared/             # Shared Dart models, logic, and data contracts
└── firebase/           # DB Rules & Security Config
```

---

## 🚦 Getting Started

### Prerequisites
- Flutter SDK 3.x
- Firebase CLI
- Google AI Studio API Key (for Gemini classification)

### Installation
1.  **Clone the repository and install dependencies:**
    ```bash
    cd guest_app && flutter pub get
    cd ../dashboard && flutter pub get
    ```
2.  **Environment Setup:**
    Create a `.env` file in the `dashboard/` directory:
    ```bash
    GEMINI_API_KEY=your_google_ai_studio_key_here
    ```

### Running the Application
1.  **Guest SOS App (Mobile/Web):**
    ```bash
    cd guest_app
    flutter run -d chrome  # Run in browser
    # OR
    flutter run            # Run on connected mobile device
    ```
2.  **Staff Command Dashboard (Web):**
    ```bash
    cd dashboard
    flutter run -d chrome
    ```

---

*Built with ❤️ for the Google Solution Challenge 2026.*

