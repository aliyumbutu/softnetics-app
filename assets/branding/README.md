# SCSAP Softnetics — Flutter app icons

Copy each folder into the root of your Flutter project (same paths), replacing existing files:

- android/app/src/main/res/  -> launcher icons for all densities + adaptive icon (Android 8+) + themed/monochrome icon (Android 13+)
- ios/Runner/Assets.xcassets/AppIcon.appiconset/  -> all iPhone/iPad sizes + 1024 App Store icon (opaque, no alpha, as Apple requires)
- macos/Runner/Assets.xcassets/AppIcon.appiconset/
- web/icons/ and web/favicon.png  (maskable icons included)
- windows/runner/resources/app_icon.ico
- linux/app_icon.png
- store/play_store_512.png -> Google Play Console listing icon

Make sure android/app/src/main/AndroidManifest.xml has:  android:icon="@mipmap/ic_launcher"

Then run:  flutter clean && flutter run

## Alternative: generate with flutter_launcher_icons
Copy the assets/icon/ folder, add this to pubspec.yaml, then run  dart run flutter_launcher_icons

```yaml
dev_dependencies:
  flutter_launcher_icons: ^0.14.4

flutter_launcher_icons:
  android: "ic_launcher"
  ios: true
  remove_alpha_ios: true
  image_path: "assets/icon/app_icon.png"
  adaptive_icon_background: "assets/icon/adaptive_background.png"
  adaptive_icon_foreground: "assets/icon/adaptive_foreground.png"
  adaptive_icon_monochrome: "assets/icon/adaptive_monochrome.png"
  web:
    generate: true
    image_path: "assets/icon/app_icon_rounded.png"
  windows:
    generate: true
    image_path: "assets/icon/app_icon_rounded.png"
    icon_size: 256
  macos:
    generate: true
    image_path: "assets/icon/app_icon_rounded.png"
```
