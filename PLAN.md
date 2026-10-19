Softnetics Flutter WebView App — Build Plan
 · 
1. Overview and instructions to the builder
Build a Flutter app called Softnetics that wraps the live SCSAP platform at https://scsap.softnetics.ng in a WebView and makes it feel like a native app. The website already holds all the business logic. The app adds a splash screen, native permissions, a secure in-app browser for Paystack that returns to the app, caching, offline handling, downloads, sharing and deep links.
Rules for the AI building this app:
Do not rebuild any platform screen in Flutter. Farm, animals, experts, wallet, AI advisory and admin all stay on the web.

One codebase for Android (minimum Android 7, API 24) and iOS (minimum iOS 14).

Use the current stable Flutter and Dart, null-safe, Material 3.

Build in the order of this document. Section 14 is the acceptance checklist; every box must pass.

Anything marked as a server change is not done in the app. Write it into SERVER_TODO.md for the web team.

Every feature must keep working when the web page does not know about the app (no hard dependency on the JavaScript bridge).

What the builder must know about the platform:
Door
Path
Users
Notes for the app
Landing
/
Everyone
Shows Log in and Register
Login
/login, /register
Everyone
Phone or email + password, OTP codes by SMS/WhatsApp; server redirects to the right door
Farmer app
/app
Farmers, livestock owners, extension workers
Mobile-first, bottom tabs; GPS boundary walking, QR scanning, wallet, video calls
Professional
/pro
Experts, buyers, cooperative admins, others
Mobile-first; bookings, video calls, aggregate map
Admin
/admin
Admins
Desktop Filament panel; allow landscape and zoom-friendly layout
2. App identity, branding and icons
Item
Value
App name (home screen and stores)
Softnetics
Android applicationId and iOS bundle ID
ng.softnetics.app
Start URL
https://scsap.softnetics.ng/
Main platform host
scsap.softnetics.ng
Company domain
softnetics.ng
Brand green (the site's theme-color)
#1B7A3E
Background
#FFFFFF
Custom URL scheme
softnetics://
User-agent suffix
 SoftneticsApp/<version> (android) or (ios)
Icons and logo
All icons and the logo are on the developer's Mac at /Users/aliyu/Downloads/scsap_flutter_icons.
Copy the whole folder into the project at assets/branding/. Keep the original file names.

List what is inside before using anything:
Ready-made Android sets (mipmap-* folders) → copy into android/app/src/main/res/.

A ready-made iOS AppIcon.appiconset → replace ios/Runner/Assets.xcassets/AppIcon.appiconset.

Only one large square PNG (1024 × 1024) → generate everything with flutter_launcher_icons, using it as the adaptive-icon foreground on a #FFFFFF background.

Splash logo: use the logo file from that folder (transparent PNG, at least 512 px wide). If none exists, download https://scsap.softnetics.ng/images/softnetics-logo-360.png.

Android notification icon: use a white, single-colour silhouette from the folder if present, named ic_stat_notification. Otherwise create one from the logo shape.

Never stretch or crop the logo; keep its aspect ratio.

Commit the generated icons; do not regenerate on every build.

3. Tech stack and packages
The WebView engine is flutter_inappwebview, because it is the only Flutter WebView that covers geolocation, camera and microphone for video calls, file upload, downloads, cookies, pull-to-refresh and a JavaScript bridge in one package. Pin each package to its latest stable version at build time.
Package
Job in this app
Phase
flutter_inappwebview (v6+)
The WebView: settings, navigation control, permissions, downloads, JS bridge, pull-to-refresh
1
flutter_web_auth_2
Opens Paystack in a secure in-app browser and closes it automatically on the softnetics:// return
1
flutter_custom_tabs
In-app browser (Chrome Custom Tabs / Safari View) for other outside links
1
url_launcher
tel:, mailto:, sms:, WhatsApp, maps apps, USSD codes
1
permission_handler
Runtime permissions: location, camera, microphone, photos, notifications
1
flutter_native_splash
Native launch screen with the logo
1
flutter_launcher_icons
App icons (only if the icon folder has no ready-made sets)
1
connectivity_plus
Online/offline detection
1
shared_preferences
Last visited page, first-run flags
1
path_provider, open_filex, share_plus
Save, open and share downloaded files (Farmer Card PDF, data export)
1
package_info_plus
App version for the user-agent and update checks
1
wakelock_plus
Keep the screen on while walking a farm boundary and during video calls
1
app_links
Android App Links, iOS Universal Links and the custom scheme
1
firebase_core, firebase_messaging, flutter_local_notifications
Push notifications for bookings, chat and climate alerts
2
mobile_scanner
Fast native QR scanner offered to the web page through the bridge
2
local_auth
Optional fingerprint/Face ID app lock
2
upgrader (+ in_app_update on Android)
Prompt users to update the app
2
Phase 1 is the release; phase 2 is added before store submission if possible, because Apple rejects plain website wrappers (see section 15).
4. Project structure
Keep one WebView alive for the whole app session, owned by web_shell_screen.dart. All URL decisions live in one file (navigation_policy.dart) so they are easy to test.
5. Splash screen and launch flow
The user sees the logo centred from the first frame until the first page is ready, with no white flash in between.
Native splash (flutter_native_splash): white #FFFFFF background, logo centred. Configure the Android 12+ splash API too (icon centred, same background). Same look in dark mode.

Flutter splash screen: the same logo at the same size and position, so the hand-over is invisible. Add a soft fade-and-scale (about 600 ms) and small "By Softnetics" text at the bottom. After 1.5 s, show a thin brand-green progress line under the logo.

Preload behind the splash: build the WebView immediately, hidden under the splash (in a Stack), and start loading the start URL. The page loads while the logo shows.

Choose the start URL:
Opened from a link or notification → that URL.

Otherwise → https://scsap.softnetics.ng/. The server sends logged-in users to their door. If it does not, load the last visited page saved in shared_preferences (only paths under /app, /pro or /admin).

Remove the splash when the first page fires onLoadStop. Keep it at least 1.2 s so it doesn't flicker, and at most 8 s. After 8 s, show the WebView with the progress bar still running.

No internet at launch → show the native error screen (logo, "You're offline", Retry button). Retry reloads and returns to the WebView on success.

Status bar: green with light icons on the splash. After that it follows the page colour (section 9).

6. WebView core: settings, URL rules and JavaScript bridge
Platform pages load inside the app; payments open in a secure browser that returns; everything else opens in an in-app browser or the right phone app.
WebView settings (InAppWebViewSettings)
Setting
Value
Why
javaScriptEnabled, domStorageEnabled, databaseEnabled
true
The platform is a modern web app
cacheEnabled, cacheMode
true, LOAD_DEFAULT
Fast repeat loads (section 9)
useShouldOverrideUrlLoading, useOnDownloadStart
true
Lets the app route links and catch downloads
supportMultipleWindows, javaScriptCanOpenWindowsAutomatically
true
Catch target=_blank and window.open in onCreateWindow
geolocationEnabled
true
Farm boundary walking, location-aware advice
mediaPlaybackRequiresUserGesture
false
Daily.co video and audio start without an extra tap
allowsInlineMediaPlayback (iOS)
true
Video calls play inside the page, not full screen
thirdPartyCookiesEnabled (Android)
true
Daily.co and Paystack inline frames
supportZoom, builtInZoomControls
false
Native feel on /app and /pro
allowsLinkPreview (iOS), disableLongPressContextMenuOnLinks
false, true
No browser-style link pop-ups
allowsBackForwardNavigationGestures (iOS)
true
Swipe back like a native app
mixedContentMode
NEVER_ALLOW
HTTPS only
allowFileAccessFromFileURLs, allowUniversalAccessFromFileURLs
false
Security
textZoom (Android)
100
Stable layout regardless of system font settings
applicationNameForUserAgent
SoftneticsApp/<version> (android/ios)
Lets the server know it is the app
isInspectable
debug builds only
Never in release
URL rules (navigation_policy.dart)
Apply the same rules in shouldOverrideUrlLoading and in onCreateWindow, first match wins.
URL
Action
https://scsap.softnetics.ng/...
Load in the WebView
checkout.paystack.com, standard.paystack.co, paystack.com/pay/..., any *.paystack.co / *.paystack.com page navigation
Paystack flow (section 7)
*.daily.co
Load in the WebView (video consultation)
tel:, mailto:, sms:, whatsapp:, wa.me, geo:, maps.google.com, intent:
Hand to the phone with url_launcher; encode # as %23 in USSD codes
Other *.softnetics.ng (e.g. the footer link to softnetics.ng)
In-app browser (Custom Tab / Safari View)
Any other http(s) link
In-app browser; the user returns with one tap
blob: or data:
Download handler (section 11)
Only main-frame navigations are routed. Map tiles from OpenStreetMap, Google Earth Engine images and Paystack inline frames are sub-resources and must load untouched.
JavaScript bridge
Register handlers with addJavaScriptHandler and inject a small script on every page that creates window.SoftneticsApp and fires a softnetics-app-ready event. Handlers answer only when the current page host is scsap.softnetics.ng.
Bridge call
Does
getAppInfo()
Returns app version and platform
setPullToRefresh(on)
Turns pull-to-refresh off on map pages
keepScreenOn(on)
Wakelock during boundary walking and video calls
share({title, text, url})
Native share sheet; also polyfills navigator.share on Android
saveFile(name, mime, base64)
Saves blob: downloads
openExternal(url)
Opens a link outside the app
scanQr() (phase 2)
Native camera scanner, returns the QR text
registerPushToken() (phase 2)
Returns the FCM token for the server
The website must keep working when window.SoftneticsApp is missing (normal browsers).
7. Paystack payments: secure browser and automatic return
Wallet top-ups open Paystack in a secure in-app browser; when payment ends, the server bounces to softnetics://, the browser closes by itself and the app shows the verified result.
Why not pay inside the WebView: bank 3-D Secure pages, OTP pages and popups often break or are blocked in WebViews, and the card details should never pass through the app. Chrome Custom Tabs (Android) and ASWebAuthenticationSession (iOS) are system browsers that users and banks trust.
The payment runs left to right across the top and comes back right to left; only the server's check in the last step decides the result.
App side (paystack_service.dart)
When the URL rules see a Paystack checkout URL, cancel the WebView navigation.

Show a short native overlay: "Opening secure payment…".

Call FlutterWebAuth2.authenticate(url: checkoutUrl, callbackUrlScheme: 'softnetics').

On success the result is softnetics://paystack/callback?reference=XYZ. Read reference and load the platform's existing verify/callback page in the WebView, e.g. https://scsap.softnetics.ng/wallet/topup/callback?reference=XYZ (use the real route from the web code). The server verifies with Paystack and shows the result.

If the user closes the browser (cancel error): reload the wallet page and show a snackbar "Payment cancelled". If the webhook already credited the wallet, the reloaded page shows it.

Never trust a status in the URL. The server verification and the Paystack webhook stay the source of truth.

Android: add the flutter_web_auth_2 CallbackActivity with an intent filter for scheme softnetics in AndroidManifest.xml. iOS needs no extra setup for the callback, but also register softnetics in CFBundleURLTypes for deep links.

Server side (goes into SERVER_TODO.md)
When a top-up is started from the app (user-agent contains SoftneticsApp), set Paystack's callback_url to https://scsap.softnetics.ng/app-return/paystack. The browser tab has no app user-agent, so decide at initialise time, not on return.

Add the route /app-return/paystack. It redirects to softnetics://paystack/callback?reference={reference}.

If the scheme does not open (e.g. the link was opened in a normal browser), the same page shows "Payment received — return to the Softnetics app" with a button to the scheme and a link to the wallet page.

Web users (not the app) keep the current callback URL unchanged.

Cases already covered
Demo/fake checkout (before Paystack keys are entered): it lives on scsap.softnetics.ng, so it simply runs inside the WebView.

Paying for a booking from the wallet: no Paystack page, stays in the WebView.

Withdrawals and payouts: processed on the server; nothing to do in the app.

USSD payment: the dial code opens the phone dialler through url_launcher with # encoded.

8. Permissions: location, camera, microphone, files
Ask for each permission only when the page first needs it, never at launch. If the user has permanently denied it, show a dialog explaining why and an "Open settings" button.
Feature
Permission
Android manifest
iOS Info.plist key and text
Farm boundary walking, location-aware AI advice
Location while in use
ACCESS_FINE_LOCATION, ACCESS_COARSE_LOCATION
NSLocationWhenInUseUsageDescription: "Softnetics uses your location to map your farm boundary and give local farming advice."
Animal QR scanning, photo uploads
Camera
CAMERA
NSCameraUsageDescription: "Softnetics uses the camera to scan animal QR tags and take farm photos."
Video consultations (Daily.co)
Camera + microphone
CAMERA, RECORD_AUDIO, MODIFY_AUDIO_SETTINGS
NSMicrophoneUsageDescription: "Softnetics uses the microphone for calls with experts."
Photo and document uploads
Photo library
Android 13+ system photo picker (no permission); READ_EXTERNAL_STORAGE up to Android 12
NSPhotoLibraryUsageDescription: "Choose photos to upload to your farm and animal records."
Push notifications (phase 2)
Notifications
POST_NOTIFICATIONS
Asked by Firebase on iOS
Everything
Network
INTERNET, ACCESS_NETWORK_STATE
—
How to wire each one:
Geolocation (Android): in onGeolocationPermissionsShowPrompt, request location with permission_handler, then answer allow: true, retain: true for scsap.softnetics.ng. If Android gives only approximate location, show a dialog asking for precise location, because boundary mapping needs it.

Geolocation (iOS): WKWebView asks itself after the app permission is granted. Accept that, or answer it in onPermissionRequest where supported.

Camera and microphone in the page: in onPermissionRequest, request the OS permission first, then grant the requested resources only for scsap.softnetics.ng and *.daily.co. Deny for any other origin.

File inputs: <input type="file"> must open the chooser with Camera and Gallery options. Test accept="image/*" and capture.

Keep the screen awake: turn on the wakelock while a boundary walk or video call is active (bridge call keepScreenOn, or automatically when the URL matches the boundary or call page). Walking needs the app in the foreground; background location is not requested.

9. Caching and native feel
Screens should open instantly after the first visit and never look like a browser.
Caching layers
HTTP cache (biggest win): WebView cache on with LOAD_DEFAULT. It depends on the server headers: hashed CSS/JS/fonts/images get Cache-Control: public, max-age=31536000, immutable; HTML pages get no-cache (server change).

Never cache money pages: wallet, payment and withdrawal pages send Cache-Control: no-store (server change), so balances are always fresh.

Service worker (recommended server change): cache the app shell, icons, fonts, viewed map tiles (capped size) and knowledge articles for offline reading. Android: enable it through ServiceWorkerController. iOS: service workers work only for app-bound domains, so add WKAppBoundDomains with scsap.softnetics.ng and daily.co in Info.plist and set limitsNavigationsToAppBoundDomains: true.

One long-lived WebView: never rebuild it on rotation or resume. Keep cookies persistent and call CookieManager.flush() (Android) when the app goes to the background, so users stay logged in.

Resume: do not reload on resume. If the app was in the background for more than 30 minutes, reload the current page quietly to refresh data and session.

Native-feel checklist
No white flash: WebView background white and hidden until the first page is ready.

Thin 2 px brand-green progress line at the top during page loads; no spinner over content.

Status bar and Android navigation bar take the colour of each page's theme-color meta (read with JS on onLoadStop), with light or dark icons chosen by brightness. Edge-to-edge with safe areas; the site already uses viewport-fit=cover.

No pinch zoom on /app and /pro; no link previews; no grey tap highlight (server CSS for the app user-agent: -webkit-tap-highlight-color: transparent, user-select: none on buttons and navigation).

Swipe back on iOS; predictive back on Android.

Pull-to-refresh in brand green, turned off on map pages so panning the map never reloads.

Keyboard never hides the chat or form field (adjustResize on Android, resizeToAvoidBottomInset in Flutter).

Portrait only on phones for /app and /pro; rotation allowed on tablets, in /admin and during video calls.

Follow the system dark mode if the web supports it; the native splash and error screens match.

Light haptic tap when a native action runs (share, download done).

10. Offline, errors, refresh and the back button
The user must never see a browser error page, a raw URL or a blank screen.
Situation
What the app does
Connection lost while using the app
Slim banner at the top: "You're offline". Cached pages keep working.
Connection comes back
Hide the banner; reload only if the last page failed
Main page fails to load (onReceivedError, main frame only)
Native error screen: logo, plain message, Retry. Never show the WebView's error page
Server error 500–599 on the main page
Same error screen, "Something went wrong, try again"
404
Let the website show its own page
No progress for 20 s
Show a Retry option over the page
SSL/certificate error
Always cancel; show the error screen. Never proceed
WebView process crashed (Android onRenderProcessGone, iOS webViewWebContentProcessDidTerminate)
Rebuild or reload the WebView silently at the same URL
Android back button
First ask the page: call window.SoftneticsBack?.() (server can add it). If it returns true, the page closed a menu or modal; stop.

Else if the WebView can go back, go back.

On root pages (/, /login, /app, /pro, /admin and their main tab pages), show "Press back again to exit"; exit only on a second press within 2 s.

Never go back into Paystack or any page outside scsap.softnetics.ng.

Pull-to-refresh
Reloads the current page. Off on map and boundary pages, and whenever the page turns it off through the bridge.
11. Downloads, sharing, deep links and push
Downloads (Farmer Card PDF, "Download my data", admin backups)
Catch every download in onDownloadStartRequest (URL, file name, MIME type).

Download it natively with the same session: copy cookies for that URL from CookieManager and send the same user-agent. Stream large files (admin backups) straight to disk.

Save to the app's documents folder; on Android also copy into the public Downloads folder (MediaStore) so it shows in the Files app.

Show a snackbar with progress, then "Open" (open_filex) and "Share" (share_plus).

blob: downloads: the injected script reads the blob as base64 and calls saveFile on the bridge.

Sharing
Android WebView has no navigator.share. The injected script adds it, calling the bridge share, which opens the native share sheet (WhatsApp, SMS and so on). On iOS keep the built-in one.
Deep links
Link type
Setup
Used for
Android App Links https://scsap.softnetics.ng/*
intent-filter with autoVerify="true"; server hosts /.well-known/assetlinks.json with ng.softnetics.app and the SHA-256 of the upload and Play signing keys
Password-reset emails, booking links, Farmer Card QR verification
iOS Universal Links
Associated Domains applinks:scsap.softnetics.ng; server hosts /.well-known/apple-app-site-association
Same as Android
Custom scheme softnetics://
Registered on both platforms
Paystack return, fallback links
With app_links: on cold start the link becomes the start URL; while running, load it in the WebView. A Farmer Card QR scanned with the phone camera opens the app straight on the verification page.
Push notifications (phase 2)
Firebase Cloud Messaging for new booking requests, chat messages, booking reminders, payment results and climate alerts. After login, the page calls registerPushToken() and posts the token to the server (server change). Tapping a notification opens the URL it carries. Uses the white notification icon from section 2.
12. Security
HTTPS only: Android network_security_config.xml with cleartextTrafficPermitted="false"; iOS App Transport Security left on.

The JavaScript bridge answers only pages on scsap.softnetics.ng; check the origin inside every handler.

No API keys in the app. All integrations (Paystack, Flutterwave, OpenAI, Daily.co, Earth Engine) stay configured on the server in Admin → Settings → Integrations.

Card details are typed only in the system browser (section 7), never in the WebView.

Release builds: WebView debugging off, Android R8 shrinking on, Flutter --obfuscate --split-debug-info.

Do not log URLs, payment references or tokens in release builds.

Optional: block screenshots on wallet and payment pages (Android FLAG_SECURE) through the bridge.

Optional phase 2: fingerprint/Face ID app lock (local_auth), off by default, switched on from the Me page.

No certificate pinning: it breaks the app whenever the site certificate renews.

Before store release, delete or change the demo accounts' passwords, as the platform manual says.

13. Server changes on scsap.softnetics.ng
Only the first item is required for payments to return to the app; the rest make it faster and more native. The builder copies this table into SERVER_TODO.md.
#
Change
Why
Priority
1
App-initiated Paystack top-ups use callback_url /app-return/paystack, which redirects to softnetics://paystack/callback?reference=… with a fallback page
Payment returns to the app
Required
2
Host /.well-known/assetlinks.json and /.well-known/apple-app-site-association
Links open the app
Required
3
Cache-Control: hashed assets immutable 1 year; HTML no-cache; wallet/payment pages no-store
Fast loads, fresh balances
High
4
Permissions-Policy allowing camera, microphone and geolocation for self and daily.co
Video calls and GPS inside the app
High
5
Detect SoftneticsApp in the user-agent: hide "get the app" prompts, add no-select/no-tap-highlight CSS
Native feel
Medium
6
OTP fields: autocomplete="one-time-code", inputmode="numeric"
SMS code autofill
Medium
7
Downloads send Content-Disposition with a file name
Correct file names
Medium
8
Longer "remember me" session for the app
Users rarely log in again
Medium
9
Service worker and web manifest
Offline shell, cached articles and tiles
Medium
10
Optional window.SoftneticsBack() that closes open modals and returns true
Natural back button
Low
11
Use window.SoftneticsApp.scanQr() when present for animal tags
Faster, more reliable scanning
Phase 2
12
POST /api/devices to store push tokens per user; send pushes for bookings, chat, alerts
Push notifications
Phase 2
14. Testing checklist
Test on a real low-end Android phone (2 GB RAM), a recent Android and an iPhone, using the demo accounts (password password). Put Paystack in test mode in Admin → Integrations and use Paystack's documented test cards.
Launch and shell
Cold start: native splash, then Flutter splash, logo centred, no white flash

Landing page loads; Log in and Register work

Launch in airplane mode → offline screen; Retry recovers

Close and reopen the app → still logged in

Back in the app after 30+ minutes → page refreshes quietly

Farmer — Aisha Bello (+2348031234567)
Lands on /app; all bottom tabs work

Walk a farm boundary: location prompt, points recorded, screen stays on, area calculated

Map pans and zooms without triggering pull-to-refresh

Scan an animal QR tag with the camera

Upload a photo from camera and from gallery

Wallet top-up: secure browser opens, payment completes, browser closes itself, app shows new balance

Cancel a top-up halfway → back in the app, "Payment cancelled", balance unchanged

Book an expert and pay from the wallet

Live chat; the keyboard never covers the input

Video call: camera and microphone work, screen stays on

Farmer Card PDF downloads, opens and shares to WhatsApp

"Download my data" saves a file

AI advisory answers a question

Log out, then log in again with an OTP code

Other roles
Extension worker Musa Ibrahim (+2348032234567): assisted registration of a new farmer

Yakubu Danladi (+2348037234567): claim the pending account by phone verification

Expert Dr. Chioma Eze (+2348033234567): lands on /pro; sets availability; accepts a booking; joins a video call

Buyer Tunde Adebayo (+2348034234567): lands on /pro

Admin Ngozi Okafor (admin@scsap.test): /admin usable, rotates to landscape, backup downloads

Platform behaviour
Android back: goes back, closes modals, double press to exit on root pages

iOS swipe back works

Password-reset email link opens the app on the right page

tel:, mailto: and WhatsApp links open the right phone app

Outside links open in the in-app browser and return with one tap

Turning the network off mid-session shows the offline banner; turning it on hides it

15. Build and release
Android (Google Play)
minSdk 24; targetSdk = the level Google Play currently requires.

Build an App Bundle (.aab), signed with an upload keystore kept outside the repo; enable Play App Signing.

Put the SHA-256 of both the upload key and the Play signing key in assetlinks.json.

Fill in the Play Data safety form: location, photos, financial info (through Paystack), personal info.

iOS (App Store)
Minimum iOS 14. Capabilities: Associated Domains; Push Notifications (phase 2).

Review risk: Apple guideline 4.2 rejects apps that are only a website. Ship the native extras — splash, offline screen, native downloads and sharing, deep links, push notifications, native QR scanner — and mention them in the review notes.

Payments: wallet top-ups pay for person-to-person expert consultations and real farm services, which Apple normally lets go through an outside payment provider. State this in the review notes and give the reviewer a demo farmer account.

Both stores
A public privacy policy URL on softnetics.ng (required by both stores and by Nigeria's data protection law).

Store listing: name "Softnetics", screenshots of farm, animals, experts and wallet.

Version format 1.0.0+1; raise the build number on every upload.

Delivery order
Phase 1: sections 2–12 → internal testing with the section 14 checklist.

Server items 1–4 from section 13 live before public release.

Phase 2: push notifications, native QR scanner, app lock, update prompts → then App Store submission.

