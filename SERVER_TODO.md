# Server changes for scsap.softnetics.ng (from PLAN.md §13)

| # | Change | Why | Priority |
|---|--------|-----|----------|
| 1 | App-initiated Paystack top-ups (user-agent contains `SoftneticsApp`) use `callback_url` = `/app-return/paystack`, which redirects to `softnetics://paystack/callback?reference=…`; fallback page "Payment received — return to the Softnetics app" with scheme button + wallet link. Also confirm the verify route used in `lib/config.dart` (`kPaystackVerifyPath`). | Payment returns to the app | Required |
| 2 | Host `/.well-known/assetlinks.json` (`ng.softnetics.app`, SHA-256 of upload + Play signing keys) and `/.well-known/apple-app-site-association` | Links open the app | Required |
| 3 | `Cache-Control`: hashed assets immutable 1 year; HTML no-cache; wallet/payment pages no-store | Fast loads, fresh balances | High |
| 4 | `Permissions-Policy` allowing camera, microphone, geolocation for self and daily.co | Video calls + GPS | High |
| 5 | Detect `SoftneticsApp` UA: hide "get the app" prompts, add no-select / no-tap-highlight CSS | Native feel | Medium |
| 6 | OTP fields: `autocomplete="one-time-code"`, `inputmode="numeric"` | SMS autofill | Medium |
| 7 | Downloads send `Content-Disposition` with file name | Correct names | Medium |
| 8 | Longer "remember me" session for the app | Rare re-login | Medium |
| 9 | Service worker + web manifest | Offline shell, cached articles/tiles | Medium |
| 10 | Optional `window.SoftneticsBack()` closing modals, returns true | Natural back button | Low |
| 11 | Use `window.SoftneticsApp.scanQr()` when present | Phase 2 | Phase 2 |
| 12 | `POST /api/devices` for push tokens | Phase 2 | Phase 2 |
