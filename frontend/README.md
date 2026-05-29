# Hookd — Frontend

Flutter app for the Hookd climbing platform. Targets Android and web only.

## Stack

- **Framework:** Flutter (Dart SDK ^3.9)
- **State management:** Provider (`ChangeNotifier`)
- **HTTP:** Dio with automatic JWT injection and silent token refresh
- **Auth:** `flutter_secure_storage` for token persistence; Firebase Auth for Google Sign-In
- **Maps:** `flutter_map` (OpenStreetMap tiles) with `flutter_map_cache` for tile caching
- **Charts:** `fl_chart`
- **Theming:** Material 3 with `dynamic_color` (Material You)

## Setup

### 1. Install dependencies

```bash
flutter pub get
```

### 2. Environment file

Create a `.env` file in `frontend/` (it is listed in `pubspec.yaml` as an asset):

```
API_BASE_URL=http://<your-backend-host>:3000
```

During local development with an Android emulator use `10.0.2.2` as the host. For a physical device on the same network, use your machine's LAN IP.

### 3. Firebase

The app uses Firebase Auth for Google Sign-In. `google-services.json` (Android) and must be present and configured for your Firebase project. The web config is loaded from `lib/firebase_options.dart` via `flutter_dotenv`.

## Running

```bash
flutter run -d web-server   # run as a web server
flutter run                 # run on a connected device or emulator
```

> [!TIP]
> For web development, you can specify `--web-port` to avoid random port assignment after each restart.

## Building

```bash
flutter build web           # web
flutter build apk           # Android APK
```
