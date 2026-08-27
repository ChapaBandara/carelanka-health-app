# 🏥 CareLanka — Digital Healthcare & Medication Compliance Platform

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.11.5-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Auth%20%7C%20Firestore%20%7C%20FCM-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)](https://firebase.google.com)
[![Node.js](https://img.shields.io/badge/Backend-Node.js%20%7C%20Express-339933?style=for-the-badge&logo=nodedotjs&logoColor=white)](https://nodejs.org)
[![Status](https://img.shields.io/badge/Status-Active%20Development-brightgreen?style=for-the-badge)](#project-status)

**CareLanka** is a comprehensive personal healthcare and medication compliance management application designed to empower individuals and families to stay on top of their health regimes. Powered by **Flutter**, **Firebase**, and a custom **Node.js/Express Push Notification Engine**, CareLanka helps users manage complex medication schedules, prevent dangerous drug interactions, store medical documents securely, and link family members via QR codes for remote caregiving.

---

## 📸 Overview

Managing multiple medications, medical records, and family health schedules can be overwhelming. CareLanka simplifies personal digital healthcare through real-time notifications, intelligent conflict checking, health analytics, and family caregiving features.

```
       +-------------------------------------------------------------+
       |                       CareLanka App                         |
       |  +-------------------+  +--------------------------------+  |
       |  |  Flutter Client   |  |   Firebase Services            |  |
       |  |  - Provider state |  |   - Firebase Auth              |  |
       |  |  - Local Alarms   |  |   - Cloud Firestore            |  |
       |  |  - PDF & Charts   |  |   - Firebase Storage           |  |
       |  +---------+---------+  +---------------+----------------+  |
       +------------|----------------------------|-------------------+
                    |                            |
                    v                            v
       +-------------------------------------------------------------+
       |             Node.js FCM Push Server (backend/)             |
       |   Cron Job Scheduler -> Firebase Cloud Messaging (FCM)      |
       +-------------------------------------------------------------+
```

---

## ✨ Key Features

### 💊 Medication Management & Adherence Tracking
- **Interactive Schedules:** View daily doses with dosage details, instructions, and time slots.
- **Dose Action Flow:** Mark doses as *Taken*, *Snoozed*, or *Missed* with real-time adherence scoring.
- **Log & History:** Comprehensive history logs of past doses to track compliance over days, weeks, and months.

### 🔔 Dual Notification & Alert Engine
- **Local Device Alarms:** High-priority local notifications using `flutter_local_notifications` and exact timezone scheduling.
- **Server Push Server (`backend/`):** Express + Firebase Admin SDK service with `node-cron` to push notifications via FCM even when the app is inactive.

### ⚠️ Drug Conflict & Allergy Detection
- **Interaction Engine:** Automatic checking of co-prescribed medications against local interaction datasets (`assets/data/drug_conflicts.json`).
- **Allergy Mapping:** Cross-checks active prescriptions against user allergen profiles (`assets/data/allergy_map.json`) to trigger high-severity safety alerts.

### 👨‍👩‍👧 Family & Caregiver Network
- **QR-Code Linking:** Instantly share personal profiles or connect with family members using built-in QR generators (`qr_flutter`) and camera scanners (`mobile_scanner`).
- **Dependent Profiles:** Manage elderly parents or children with managed profiles and linked caregiving accounts.

### 📄 Medical Document Vault & Health Records
- **Secure Storage:** Upload, view, and categorize medical records, prescriptions, and lab test results backed by Firebase Storage.
- **PDF Viewer & Printing:** In-app PDF rendering and direct device printing integration (`pdf`, `printing`).
- **Search & Filter:** Instant search across record titles, dates, tags, and medical categories.

### 📅 Appointments & Checkup Manager
- **Doctor Visits:** Track upcoming clinic checkups, specialist appointments, and medical consultations.
- **Reminders:** Automatic reminders for upcoming medical visits.

### 📊 Health Analytics & Exportable Reports
- **Visual Analytics:** Interactive compliance graphs and trend charts built with `fl_chart`.
- **PDF Report Generator:** Export detailed adherence and medical history reports as clean, printable PDF documents.

### 🔒 Security & Authentication
- **Multi-Factor Auth & OTP:** Firebase Auth integrated with EmailJS for email verification codes and password resets.
- **Session Persistence:** Persistent login state with local preference caching.

---

## 🛠️ Tech Stack

### Mobile App (Client)
- **Framework:** [Flutter 3.x](https://flutter.dev) (Dart SDK `^3.11.5`)
- **State Management:** `provider`
- **UI & Styling:** Material Design 3, Google Fonts (`google_fonts`), `cupertino_icons`
- **Data Visualization:** `fl_chart`
- **QR Code Handling:** `qr_flutter`, `mobile_scanner`
- **PDF Generation & Export:** `pdf`, `printing`
- **Notifications:** `flutter_local_notifications`, `firebase_messaging`, `timezone`
- **Utilities:** `shared_preferences`, `permission_handler`, `image_picker`, `url_launcher`, `share_plus`

### Backend Server (`backend/`)
- **Runtime:** Node.js (v20+)
- **Framework:** Express.js
- **Services:** Firebase Admin SDK (FCM)
- **Scheduler:** `node-cron`
- **Hosting:** Deployable on Render.com / Railway / Cloud Run

### Database & Cloud (Firebase)
- **Authentication:** Firebase Auth
- **Database:** Cloud Firestore
- **Storage:** Firebase Storage
- **Messaging:** Firebase Cloud Messaging (FCM)

---

## 📁 Repository Structure

```
MedAPP/
├── assets/
│   └── data/
│       ├── allergy_map.json       # Predefined drug-allergy mapping dataset
│       └── drug_conflicts.json    # Drug-to-drug conflict matrix
├── backend/                       # Node.js Express FCM reminder push server
│   ├── server.js                  # Main server entrypoint with cron jobs & FCM push
│   ├── package.json               # Backend dependencies
│   └── README.md                  # Backend setup & Render deployment guide
├── functions/                     # Firebase Cloud Functions codebase
├── lib/                           # Flutter Mobile Application Source Code
│   ├── core/                      # Application constants, routing, theme, observers
│   │   ├── constants/             # App routes and constant definitions
│   │   ├── navigation/            # Route navigation observers
│   │   └── theme/                 # App Theme (Colors, Typography)
│   ├── models/                    # Data models (User, Medication, HealthRecord, etc.)
│   ├── providers/                 # State management providers (Auth, Medication, Family)
│   ├── screens/                   # UI Screens organized by feature area
│   │   ├── alerts/                # Drug conflict and allergy alert screens
│   │   ├── allergies/             # Allergy manager screens
│   │   ├── appointments/          # Appointment tracking screens
│   │   ├── auth/                  # Authentication, OTP, & splash screens
│   │   ├── family/                # Family profile, QR generator & scanner screens
│   │   ├── home/                  # Dashboard and main shell navigation
│   │   ├── illnesses/             # Illness and medical condition tracking
│   │   ├── medications/           # Medication schedules, intake & history
│   │   ├── profile/               # User settings, privacy, help & profile editing
│   │   ├── records/               # Document vault & health record viewer
│   │   └── reports/               # Adherence analytics & report generation
│   ├── services/                  # Business logic services & API connectors
│   └── widgets/                   # Shared UI components and custom widgets
├── pubspec.yaml                   # Flutter package manifest & dependencies
└── firebase.json                  # Firebase configuration CLI settings
```

---

## 🚀 Getting Started

### Prerequisites

Ensure you have the following installed on your development system:
- **[Flutter SDK](https://docs.flutter.dev/get-started/install)** (v3.19 or higher)
- **[Dart SDK](https://dart.dev/get-dart)** (v3.11.5+)
- **[Node.js](https://nodejs.org/)** (v20+ for running the backend server)
- **[Git](https://git-scm.com/)**
- **Android Studio / Xcode / VS Code** with Flutter extensions installed

---

### 1. Flutter Mobile App Setup

1. **Clone the repository:**
   ```bash
   git clone https://github.com/ChapaBandara/carelanka-health-app.git
   cd carelanka-health-app
   ```

2. **Install Flutter dependencies:**
   ```bash
   flutter pub get
   ```

3. **Configure Firebase:**
   - Place your `google-services.json` file inside `android/app/`.
   - Place your `GoogleService-Info.plist` file inside `ios/Runner/`.
   - Ensure `lib/firebase_options.dart` is populated with your Firebase project credentials using FlutterFire CLI:
     ```bash
     flutterfire configure
     ```

4. **Run the Flutter application:**
   ```bash
   # Connect a device or launch an emulator, then run:
   flutter run
   ```

---

### 2. Push Notification Backend Setup (`backend/`)

The `backend/` directory contains an Express server that handles background FCM push notification delivery.

1. **Navigate to the backend folder:**
   ```bash
   cd backend
   npm install
   ```

2. **Configure Firebase Admin Credentials:**
   Set the `FIREBASE_SERVICE_ACCOUNT_JSON` environment variable with your Firebase Admin Service Account JSON content:
   ```bash
   export FIREBASE_SERVICE_ACCOUNT_JSON='{
     "type": "service_account",
     "project_id": "your-project-id",
     "private_key_id": "...",
     "private_key": "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n",
     "client_email": "...",
     ...
   }'
   ```

3. **Start the Development Server:**
   ```bash
   npm run dev
   ```
   The server will run on `http://localhost:3000`.

#### Backend API Endpoints

| Method   | Path                                  | Description                                 |
|----------|---------------------------------------|---------------------------------------------|
| `POST`   | `/schedule-medication`                | Queue or update a scheduled reminder        |
| `DELETE` | `/cancel-medication`                  | Cancel a single queued medication reminder  |
| `DELETE` | `/cancel-all-medications/:userId`     | Remove all active reminders for a user      |
| `GET`    | `/queue`                              | Inspect current in-memory reminder queue    |
| `GET`    | `/health`                             | System health status and server uptime      |

---

## 🔒 Security & Privacy

CareLanka is built with privacy-first principles:
- **Authenticated Access:** All endpoints and Firestore queries enforce security rules tied to authenticated user IDs.
- **Local Data Processing:** Drug interaction and allergy checks operate locally using cached datasets to ensure fast, private evaluation.
- **Encrypted Transmission:** All external cloud communication occurs over HTTPS / TLS to Firebase services.

---

## 🚧 Project Status

CareLanka is currently in **active development** as part of an academic research project focused on improving digital health access and medication compliance.

---

## 🤝 Contributing

Contributions, feature suggestions, and feedback are welcome!
1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## 📜 License

This project is licensed under the [MIT License](LICENSE) — see the repository for details.

---

<p center="align">
  Crafted with ❤️ for healthcare compliance and family wellness.
</p>
