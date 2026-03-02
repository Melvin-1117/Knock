# 👊 Knock

A Flutter mobile app project built with **Dart**. This repository contains the Flutter app under the `knock/` directory and includes integrations for **Supabase** and **Firebase Cloud Messaging (FCM)**, plus local notifications.

> Repo: https://github.com/Melvin-1117/Knock

---

## Overview

**Knock** is a Flutter application scaffolded as a standard Flutter project, then extended with:
- **Supabase** (`supabase_flutter`) for backend/services
- **Firebase** (`firebase_core`, `firebase_messaging`) for push notifications
- **flutter_local_notifications** for handling notifications on-device

The main application entry point is located at:

- `knock/lib/main.dart`

---

## Key Features

- **Flutter app (Dart)**
- **Push notifications support**
  - Firebase Messaging integration
  - Local notifications support for device-level notification display
  - Included documentation for setup and verification:
    - `knock/PUSH_SETUP.md`
    - `knock/PUSH_NOTIFICATION_SETUP.md`
    - `knock/PUSH_VERIFY.md`
- **Supabase integration**
- **Local persistence**
  - Uses `shared_preferences` for storing simple key/value data
- **App icon generation**
  - Configured via `flutter_launcher_icons` and `assets/icon.png`

---

## Tech Stack

- **Framework:** Flutter
- **Language:** Dart (SDK `^3.9.2`)
- **Backend/Services:** Supabase (`supabase_flutter`)
- **Notifications:**
  - Firebase Core (`firebase_core`)
  - Firebase Messaging (`firebase_messaging`)
  - Local notifications (`flutter_local_notifications`)
- **Storage:** `shared_preferences`
- **Tooling / Lints:** `flutter_lints`
- **Icons:** `flutter_launcher_icons`

---

## Installation

### Prerequisites
- Flutter SDK installed (`flutter --version`)
- A configured Android/iOS development environment (Android Studio/Xcode as applicable)

### Get dependencies
From the repo root, the Flutter project is inside `knock/`:

```bash
cd knock
flutter pub get
```

### Run the app
```bash
cd knock
flutter run
```

---

## Android: Firebase / Google Services Setup

This repo does **not** commit `android/app/google-services.json` (it contains secrets).

To run on Android:

1. Copy the example file:
   ```bash
   cp android/app/google-services.json.example android/app/google-services.json
   ```
2. Fill in your Firebase project values from the Firebase Console.
3. Ensure you replace any placeholder API key values as described in the project docs.

See: `knock/README.md` and `knock/PUSH_NOTIFICATION_SETUP.md` for the detailed steps.

---

## Project Structure

```text
.
├─ .idea/                 # IDE config (JetBrains)
├─ .vscode/               # VS Code config
└─ knock/                 # Flutter application root
   ├─ android/            # Android platform project
   ├─ assets/             # App assets (includes icon.png)
   ├─ lib/                # Dart source code
   │  └─ main.dart        # App entry point
   ├─ supabase/           # Supabase-related resources/config
   ├─ test/               # Flutter tests
   ├─ web/                # Flutter web support
   ├─ pubspec.yaml        # Dependencies & Flutter config
   ├─ pubspec.lock        # Locked dependency versions
   ├─ analysis_options.yaml
   ├─ PUSH_SETUP.md
   ├─ PUSH_NOTIFICATION_SETUP.md
   ├─ PUSH_VERIFY.md
   └─ README.md           # Existing (default + Android secrets note)
```

---

## 👨‍💻 Developed By

**Melvin**
