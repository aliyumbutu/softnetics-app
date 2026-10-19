# Phase 2 setup

Code is in place; these need your accounts/files:

- **Push (FCM):** create a Firebase project, add Android `ng.softnetics.app` and iOS `ng.softnetics.app`.
  Put `google-services.json` in `android/app/` and `GoogleService-Info.plist` in `ios/Runner/` (via Xcode).
  Upload your APNs key in Firebase. Without these files the app runs and push is silently off.
  Server: `POST /api/devices` to store the token from `window.SoftneticsApp.registerPushToken()`; send pushes with `data.url`.
- **QR:** the web page calls `await SoftneticsApp.scanQr()` (returns the text, or null if cancelled).
- **App lock:** the Me page calls `SoftneticsApp.setAppLock(true|false)` / `getAppLock()`.
- **Updates:** `upgrader` prompts from the store listing. `in_app_update` (Android) not added.
- **Notification icon:** `ic_stat_notification` is a placeholder leaf; replace with a brand silhouette.
