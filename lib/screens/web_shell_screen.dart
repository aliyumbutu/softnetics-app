import 'dart:collection';
import 'dart:async';
import 'dart:io';
import 'package:app_links/app_links.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_custom_tabs/flutter_custom_tabs.dart' as tabs;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config.dart';
import '../services/app_lock.dart';
import '../services/bridge.dart';
import '../services/push.dart';
import 'scanner_screen.dart';
import '../services/downloads.dart';
import '../services/navigation_policy.dart';
import '../services/paystack_service.dart';
import '../widgets/error_view.dart';
import '../widgets/splash_overlay.dart';

class WebShellScreen extends StatefulWidget {
  const WebShellScreen({super.key, required this.startUrl, required this.version});
  final String startUrl, version;
  @override
  State<WebShellScreen> createState() => _WebShellScreenState();
}

class _WebShellScreenState extends State<WebShellScreen> with WidgetsBindingObserver {
  InAppWebViewController? _web;
  late final PullToRefreshController _ptr = PullToRefreshController(
    settings: PullToRefreshSettings(color: kGreen),
    onRefresh: () => _web?.reload(),
  );
  final _launch = DateTime.now();
  final _scaffold = GlobalKey<ScaffoldMessengerState>();
  StreamSubscription? _connSub, _linkSub, _pushSub;
  Timer? _splashMax, _stall;
  DateTime? _pausedAt, _lastBack;

  bool _splash = true, _firstLoadDone = false, _offline = false, _stalled = false;
  String? _error;
  double _progress = 0;
  bool _failedLast = false;
  bool _locked = false;

  String get _platform => Platform.isIOS ? 'ios' : 'android';
  String get _ua => 'SoftneticsApp/${widget.version} ($_platform)';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _splashMax = Timer(const Duration(seconds: 8), _hideSplash);
    Connectivity().checkConnectivity().then(_onConn);
    _connSub = Connectivity().onConnectivityChanged.listen(_onConn);
    _pushSub = Push.taps.listen(_openPushUrl);
    AppLock.enabled.then((on) {
      if (on && mounted) _unlock(lock: true);
    });
    _linkSub = AppLinks().uriLinkStream.listen((u) {
      final t = mapDeepLink(u);
      if (t != null) _web?.loadUrl(urlRequest: URLRequest(url: WebUri.uri(t)));
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connSub?.cancel();
    _linkSub?.cancel();
    _pushSub?.cancel();
    _splashMax?.cancel();
    _stall?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
      AppLock.enabled.then((on) {
        if (on && mounted) setState(() => _locked = true);
      });
      // ponytail: Android cookie flush not exposed by the plugin; WebView persists on its own timer.
    } else if (s == AppLifecycleState.resumed && _locked) {
      _unlock();
    }
    if (s == AppLifecycleState.resumed && _pausedAt != null) {
      if (DateTime.now().difference(_pausedAt!) > const Duration(minutes: 30)) _web?.reload();
      _pausedAt = null;
    }
  }

  void _openPushUrl(String url) {
    final t = mapDeepLink(Uri.parse(url));
    if (t != null) _web?.loadUrl(urlRequest: URLRequest(url: WebUri.uri(t)));
  }

  Future<void> _unlock({bool lock = false}) async {
    if (lock) setState(() => _locked = true);
    if (await AppLock.unlock() && mounted) setState(() => _locked = false);
  }

  void _onConn(List<ConnectivityResult> r) {
    final off = r.every((e) => e == ConnectivityResult.none);
    if (!mounted || off == _offline) return;
    setState(() => _offline = off);
    if (!off && _failedLast) _retry();
  }

  void _retry() {
    setState(() {
      _error = null;
      _failedLast = false;
    });
    _web?.reload();
  }

  void _hideSplash() {
    if (!mounted || !_splash) return;
    setState(() => _splash = false);
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
  }

  void _toast(String m) => _scaffold.currentState
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m)));

  // ---- navigation -------------------------------------------------------

  Future<void> _route(Uri u) async {
    switch (decide(u)) {
      case NavAction.webview:
        await _web?.loadUrl(urlRequest: URLRequest(url: WebUri.uri(u)));
      case NavAction.paystack:
        await _pay(u);
      case NavAction.phone:
        // USSD: '#' must be encoded for the dialler.
        final s = u.toString().replaceAll('#', '%23');
        try {
          await launchUrl(Uri.parse(s), mode: LaunchMode.externalApplication);
        } catch (_) {
          _toast('No app found to open this link');
        }
      case NavAction.inAppBrowser:
        await tabs.launchUrl(u);
      case NavAction.download:
        break; // handled by bridge / onDownloadStart
    }
  }

  Future<void> _pay(Uri checkout) async {
    _toast('Opening secure payment…');
    final ref = await payWithPaystack(checkout.toString());
    if (ref == null) {
      _toast('Payment cancelled');
      _web?.reload();
    } else {
      final cb = Uri.https(kHost, kPaystackVerifyPath, {'reference': ref});
      _web?.loadUrl(urlRequest: URLRequest(url: WebUri.uri(cb)));
    }
  }

  // ---- permissions ------------------------------------------------------

  bool _trusted(Uri? o) =>
      o != null && (o.host == kHost || o.host == 'daily.co' || o.host.endsWith('.daily.co'));

  Future<void> _settingsDialog(String what) async {
    if (!mounted) return;
    final go = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('$what permission needed'),
        content: Text('Softnetics needs $what access for this feature. Enable it in Settings.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Not now')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Open settings')),
        ],
      ),
    );
    if (go == true) openAppSettings();
  }

  Future<bool> _ask(Permission p, String label) async {
    var s = await p.request();
    if (s.isPermanentlyDenied) await _settingsDialog(label);
    return s.isGranted || s.isLimited;
  }

  Future<GeolocationPermissionShowPromptResponse?> _geo(
      InAppWebViewController c, String origin) async {
    final ok = _trusted(Uri.tryParse(origin)) && await _ask(Permission.locationWhenInUse, 'location');
    if (ok && Platform.isAndroid) {
      // Boundary mapping needs precise location.
      final acc = await Permission.location.serviceStatus;
      if (acc != ServiceStatus.enabled) _toast('Turn on location for accurate farm mapping');
    }
    return GeolocationPermissionShowPromptResponse(origin: origin, allow: ok, retain: ok);
  }

  Future<PermissionResponse?> _perm(InAppWebViewController c, PermissionRequest r) async {
    if (!_trusted(Uri.tryParse(r.origin.toString()))) {
      return PermissionResponse(resources: r.resources, action: PermissionResponseAction.DENY);
    }
    final granted = <PermissionResourceType>[];
    for (final res in r.resources) {
      if (res == PermissionResourceType.CAMERA && await _ask(Permission.camera, 'camera')) {
        granted.add(res);
      } else if (res == PermissionResourceType.MICROPHONE &&
          await _ask(Permission.microphone, 'microphone')) {
        granted.add(res);
      } else if (res == PermissionResourceType.CAMERA_AND_MICROPHONE) {
        final cam = await _ask(Permission.camera, 'camera');
        final mic = await _ask(Permission.microphone, 'microphone');
        if (cam && mic) granted.add(res);
      }
    }
    return PermissionResponse(
      resources: granted,
      action: granted.isEmpty ? PermissionResponseAction.DENY : PermissionResponseAction.GRANT,
    );
  }

  // ---- page events ------------------------------------------------------

  Future<void> _onStop(InAppWebViewController c, WebUri? url) async {
    _stall?.cancel();
    _ptr.endRefreshing();
    if (mounted) setState(() => _stalled = false);
    final path = url?.path ?? '';
    final host = url?.host ?? '';

    if (!_firstLoadDone) {
      _firstLoadDone = true;
      final prefs = await SharedPreferences.getInstance();
      final last = prefs.getString('lastPath');
      if (widget.startUrl == kStartUrl && path == '/' && last != null) {
        c.loadUrl(urlRequest: URLRequest(url: WebUri('https://$kHost$last')));
      }
      final wait = const Duration(milliseconds: 1200) - DateTime.now().difference(_launch);
      Timer(wait.isNegative ? Duration.zero : wait, _hideSplash);
    }
    if (host == kHost) {
      if (isResumablePath(path)) {
        (await SharedPreferences.getInstance()).setString('lastPath', path);
      }
      _ptr.setEnabled(!isMapPage(path));
      _applyTheme(c);
      _applyOrientation(path);
    }
  }

  Future<void> _applyTheme(InAppWebViewController c) async {
    final v = await c.evaluateJavascript(
        source: "document.querySelector('meta[name=theme-color]')?.content || ''");
    final col = _parseColor('$v');
    if (col == null || !mounted) return;
    final dark = col.computeLuminance() < 0.5;
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: col,
      statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      statusBarBrightness: dark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: col,
      systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark,
    ));
  }

  Color? _parseColor(String s) {
    final m = RegExp(r'^#([0-9a-fA-F]{6})$').firstMatch(s.trim());
    return m == null ? null : Color(0xFF000000 | int.parse(m.group(1)!, radix: 16));
  }

  void _applyOrientation(String path) {
    if (!mounted) return;
    final phone = MediaQuery.of(context).size.shortestSide < 600;
    final lock = phone && !path.startsWith('/admin');
    SystemChrome.setPreferredOrientations(
        lock ? [DeviceOrientation.portraitUp] : DeviceOrientation.values);
  }

  Future<void> _onBack() async {
    final c = _web;
    if (c != null) {
      final r = await c.evaluateJavascript(
          source: 'typeof window.SoftneticsBack === "function" ? window.SoftneticsBack() : false');
      if (r == true) return;
      final path = (await c.getUrl())?.path ?? '/';
      if (!isRootPath(path) && await c.canGoBack()) {
        await c.goBack();
        return;
      }
    }
    final now = DateTime.now();
    if (_lastBack != null && now.difference(_lastBack!) < const Duration(seconds: 2)) {
      SystemNavigator.pop();
    } else {
      _lastBack = now;
      _toast('Press back again to exit');
    }
  }

  void _fail(String msg) {
    _failedLast = true;
    if (mounted) setState(() => _error = msg);
    _hideSplash();
  }

  @override
  Widget build(BuildContext context) {
    final settings = InAppWebViewSettings(
      javaScriptEnabled: true,
      domStorageEnabled: true,
      databaseEnabled: true,
      cacheEnabled: true,
      cacheMode: CacheMode.LOAD_DEFAULT,
      useShouldOverrideUrlLoading: true,
      useOnDownloadStart: true,
      supportMultipleWindows: true,
      javaScriptCanOpenWindowsAutomatically: true,
      geolocationEnabled: true,
      mediaPlaybackRequiresUserGesture: false,
      allowsInlineMediaPlayback: true,
      thirdPartyCookiesEnabled: true,
      supportZoom: false,
      builtInZoomControls: false,
      allowsLinkPreview: false,
      disableLongPressContextMenuOnLinks: true,
      allowsBackForwardNavigationGestures: true,
      mixedContentMode: MixedContentMode.MIXED_CONTENT_NEVER_ALLOW,
      allowFileAccessFromFileURLs: false,
      allowUniversalAccessFromFileURLs: false,
      textZoom: 100,
      applicationNameForUserAgent: 'SoftneticsApp/${widget.version} ($_platform)',
      isInspectable: kDebugMode,
      limitsNavigationsToAppBoundDomains: Platform.isIOS,
      transparentBackground: false,
    );

    return ScaffoldMessenger(
      key: _scaffold,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _onBack();
        },
        child: Scaffold(
          backgroundColor: Colors.white,
          resizeToAvoidBottomInset: true,
          body: Stack(children: [
            // Built immediately, hidden under the splash, so the page loads while the logo shows.
            Positioned.fill(
              child: SafeArea(
                top: false,
                child: InAppWebView(
                  initialUrlRequest: URLRequest(url: WebUri(widget.startUrl)),
                  initialSettings: settings,
                  initialUserScripts: UnmodifiableListView([
                    UserScript(
                        source: bridgeScript,
                        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
                        forMainFrameOnly: false)
                  ]),
                  pullToRefreshController: _ptr,
                  onWebViewCreated: (c) {
                    _web = c;
                    registerBridge(
                      c,
                      BridgeHooks(
                        version: widget.version,
                        platform: _platform,
                        setPullToRefresh: (on) => _ptr.setEnabled(on),
                        saveFile: (n, b) => saveBase64(context, n, b),
                      ),
                    );
                    registerPhase2Bridge(c, () async {
                      if (!await _ask(Permission.camera, 'camera')) return null;
                      if (!mounted) return null;
                      return Navigator.push<String>(
                          context, MaterialPageRoute(builder: (_) => const ScannerScreen()));
                    });
                  },
                  onLoadStart: (c, u) {
                    _stall?.cancel();
                    _stall = Timer(const Duration(seconds: 20), () {
                      if (mounted && _error == null) setState(() => _stalled = true);
                    });
                    if (_error != null) setState(() => _error = null);
                  },
                  onLoadStop: _onStop,
                  onProgressChanged: (c, p) {
                    if (mounted) setState(() => _progress = p / 100);
                    if (p == 100) _ptr.endRefreshing();
                  },
                  shouldOverrideUrlLoading: (c, a) async {
                    if (!a.isForMainFrame) return NavigationActionPolicy.ALLOW;
                    final u = a.request.url;
                    if (u == null) return NavigationActionPolicy.CANCEL;
                    final act = decide(u);
                    if (act == NavAction.webview) return NavigationActionPolicy.ALLOW;
                    if (act == NavAction.download) return NavigationActionPolicy.ALLOW;
                    _route(u);
                    return NavigationActionPolicy.CANCEL;
                  },
                  onCreateWindow: (c, a) async {
                    final u = a.request.url;
                    if (u != null) _route(u);
                    return true; // never open a native popup window
                  },
                  onDownloadStartRequest: (c, r) =>
                      downloadUrl(context, r.url, r.suggestedFilename ?? r.url.pathSegments.last, _ua),
                  onGeolocationPermissionsShowPrompt: _geo,
                  onPermissionRequest: _perm,
                  onReceivedError: (c, r, e) {
                    if (r.isForMainFrame != true) return;
                    if (e.type == WebResourceErrorType.CANCELLED) return;
                    _fail(_offline ? "You're offline" : "Couldn't load the page. Check your connection.");
                  },
                  onReceivedHttpError: (c, r, res) {
                    final code = res.statusCode ?? 0;
                    if (r.isForMainFrame == true && code >= 500 && code < 600) {
                      _fail('Something went wrong, try again');
                    }
                  },
                  onReceivedServerTrustAuthRequest: (c, ch) async =>
                      ServerTrustAuthResponse(action: ServerTrustAuthResponseAction.CANCEL),
                  onRenderProcessGone: (c, d) => c.reload(),
                  onWebContentProcessDidTerminate: (c) => c.reload(),
                ),
              ),
            ),
            if (_progress < 1 && !_splash)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: LinearProgressIndicator(
                      value: _progress, minHeight: 2, color: kGreen, backgroundColor: Colors.transparent),
                ),
              ),
            if (_offline && _error == null)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Material(
                  color: Colors.black87,
                  child: SafeArea(
                    bottom: false,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      child: Text("You're offline",
                          textAlign: TextAlign.center, style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ),
              ),
            if (_stalled && _error == null)
              Positioned(
                bottom: 24,
                left: 24,
                right: 24,
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(8),
                  child: ListTile(
                    title: const Text('Taking longer than usual'),
                    trailing: TextButton(onPressed: _retry, child: const Text('Retry')),
                  ),
                ),
              ),
            if (_error != null) Positioned.fill(child: ErrorView(message: _error!, onRetry: _retry)),
            if (_locked)
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.white,
                  child: Center(
                    child: FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: kGreen),
                      onPressed: _unlock,
                      child: const Text('Unlock'),
                    ),
                  ),
                ),
              ),
            if (_splash) const Positioned.fill(child: SplashOverlay()),
          ]),
        ),
      ),
    );
  }
}

/// https://scsap… -> as is; softnetics://app/x -> https://scsap…/app/x.
/// The paystack return is consumed by flutter_web_auth_2, not here.
Uri? mapDeepLink(Uri u) {
  if (u.scheme == 'https' && u.host == kHost) return u;
  if (u.scheme == kScheme && u.host != 'paystack') {
    return Uri.https(kHost, '/${u.host}${u.path}', u.hasQuery ? u.queryParameters : null);
  }
  return null;
}
