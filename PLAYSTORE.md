# Play Store release

## Build
    flutter build appbundle --release      # build/app/outputs/bundle/release/app-release.aab
Before each upload bump `version:` in pubspec.yaml (the number after `+` is versionCode and must increase).

## Signing
- Upload key: ~/softnetics-keys/upload-keystore.jks, alias `upload`, passwords in android/key.properties (gitignored).
- BACK UP ~/softnetics-keys somewhere safe (password manager / cloud). Enrol in Play App Signing on first upload; Google holds the real app-signing key, this is only the upload key (resettable via Play support).
- Upload cert SHA-256: B9:77:29:72:FF:23:7E:71:CB:4B:C3:21:2C:CE:1B:FA:D1:7A:68:29:10:76:51:C6:84:E1:FA:DD:B7:3E:C5:50

## Play Console checklist
1. Create app: name "Softnetics", default language, App, Free.
2. Store listing: short (80) + full (4000) description, icon 512x512 (assets/branding), feature graphic 1024x500, >=2 phone screenshots.
3. App content: privacy policy URL (public page on scsap.softnetics.ng), Data safety form, Ads = No, target audience (not for children), Content rating questionnaire, App access (give reviewers a test farmer + expert login), Financial features declaration (wallet via Paystack).
4. Data safety: collects name, email, phone, precise location (farm GPS), photos, financial/payment info (via Paystack), device ID/push token; encrypted in transit; users can request deletion (in-app/web account deletion URL required).
5. Permissions to justify: location, camera, microphone (video calls), notifications, biometric.
6. Testing: new personal accounts must run a closed test with 12+ testers for 14 days before production.
7. After the first upload, add the Play app-signing SHA-256 to https://scsap.softnetics.ng/.well-known/assetlinks.json (see SERVER_TODO.md) so App Links verify.
8. Push: add android/app/google-services.json (README_PHASE2.md) before the build you ship if you want notifications.
