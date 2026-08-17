# Implementation Plan: Optimize Code and Build Executable (APK)

This plan outlines the steps to optimize the Flutter codebase for better performance and create a build (APK) for the connected Android device.

## User Review Required

> [!IMPORTANT]
> **Flutter SDK Location**: I have searched for the Flutter SDK on your machine but could not locate it. To build the APK, I need the path to your Flutter installation (e.g., `C:\src\flutter\bin`).
> **API Base URL**: The current `baseUrl` in `AgentApiService` is set to `127.0.0.1`. This will not work when the app runs on a physical device unless it's pointing to a remote server or your machine's local IP. Please provide the server IP if available.

## Proposed Changes

### [Component] Code Optimization (Performance & Memory)

#### [MODIFY] [home_screen.dart](file:///C:/Users/mayan/Hackathon/Flutter_bSafe/lib/screens/home_screen.dart)
- Implement `StreamSubscription` for the decibel stream and cancel it in `dispose()` to prevent memory leaks.
- Refactor `_buildGridItem` into a separate `StatelessWidget` to optimize the widget tree and rebuilds.
- Replace the nested `GridView` (which uses `shrinkWrap: true`) with a `SliverGrid` within a `CustomScrollView` for better scroll performance.
- Add missing `const` constructors to static UI elements.

#### [MODIFY] [agent_api_service.dart](file:///C:/Users/mayan/Hackathon/Flutter_bSafe/lib/services/agent_api_service.dart)
- Refactor `baseUrl` to allow for dynamic configuration (e.g., using a global config or environment variables) so it works on physical devices.

#### [MODIFY] Global Codebase
- Search for and add missing `const` keywords across all screen files (`lib/screens/*.dart`) to reduce unnecessary rebuilds.

---

### [Component] Asset Optimization

#### [OPTIMIZE] [img1.png](file:///C:/Users/mayan/Hackathon/Flutter_bSafe/assets/img1.png)
- Suggest compressing this 1MB image to reduce the final APK size.

---

### [Component] Build and Deployment

#### [BUILD] Create Executable (APK)
- Once the Flutter SDK path is provided, I will run:
  ```bash
  flutter build apk --release
  ```
- This will generate a production-ready APK in `build/app/outputs/flutter-apk/app-release.apk`.

#### [DEPLOY] Install on Device
- Install the generated APK on the connected device (`001613558002048`) using `adb`.

## Verification Plan

### Automated Tests
- I will run `flutter analyze` to ensure there are no linting errors or missing `const` warnings.

### Manual Verification
- Deploy the APK to the device.
- Verify that the SOS button and navigation grid work as expected.
- Monitor logs for any memory leaks related to the audio stream.
