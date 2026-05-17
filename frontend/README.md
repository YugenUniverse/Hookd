# Hookd — Frontend

Flutter app for the Hookd climbing platform. Targets Android, iOS, and web/desktop from a single codebase.

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

The app uses Firebase Auth for Google Sign-In. `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) must be present and configured for your Firebase project. The web config is loaded from `lib/firebase_options.dart` via `flutter_dotenv`.

## Running

```bash
flutter run                 # run on a connected device or emulator
flutter run -d chrome       # run as a web app
flutter run -d macos        # run as a macOS desktop app
```

## Building

```bash
flutter build apk           # Android APK
flutter build appbundle     # Android App Bundle (Play Store)
flutter build ios           # iOS (requires macOS + Xcode)
flutter build web           # web
```

## Architecture

The app is map-centric. The home screen (`MyHomePage`) renders a full-screen `POIMap` with navigation controls overlaid on top — a bottom nav bar on mobile and a collapsible side nav on desktop/web.

Most secondary screens open as **modal bottom sheets** (wall details, facility details, log session). Role-specific account pages (`UserPage`, `FacilityOwnerPage`, `PublicBodyPage`) are full-screen and pushed via `Navigator.push`.

**Key singletons** (accessed anywhere via factory constructors):
- `AuthService` — JWT/refresh token lifecycle, Google login, `isAuthenticated`, `userType`
- `ApiService` — Dio wrapper; auto-injects `Authorization` header, retries on 401 after refreshing the token

**User roles** (set at registration, stored in the JWT `userType` claim):

| Role | Home screen extras |
|------|--------------------|
| `Climber` | Log session, my issues, personal profile |
| `FacilityOwner` | Facility profile, wall management, analytics reports |
| `PublicBody` | Outdoor wall management, analytics reports |

## Testing

```bash
flutter test
```
