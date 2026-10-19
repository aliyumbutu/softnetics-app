import '../config.dart';

enum NavAction { webview, paystack, phone, inAppBrowser, download }

bool _isHost(String host, String domain) =>
    host == domain || host.endsWith('.$domain');

/// Single source of truth for URL decisions (section 6). First match wins.
NavAction decide(Uri u) {
  final s = u.scheme;
  if (s == 'blob' || s == 'data') return NavAction.download;
  if (const {'tel', 'mailto', 'sms', 'whatsapp', 'geo', 'intent'}.contains(s)) {
    return NavAction.phone;
  }
  if (s != 'http' && s != 'https') return NavAction.phone;
  final h = u.host.toLowerCase();
  if (h == kHost) return NavAction.webview;
  if (_isHost(h, 'paystack.co') || _isHost(h, 'paystack.com')) {
    return NavAction.paystack;
  }
  if (h == 'wa.me' || h == 'maps.google.com') return NavAction.phone;
  if (_isHost(h, 'daily.co')) return NavAction.webview;
  return NavAction.inAppBrowser; // incl. other *.softnetics.ng
}

bool isRootPath(String path) {
  const roots = {'', '/', '/login', '/register', '/app', '/pro', '/admin'};
  final p = path.length > 1 && path.endsWith('/')
      ? path.substring(0, path.length - 1)
      : path;
  return roots.contains(p);
}

bool isResumablePath(String path) =>
    path.startsWith('/app') || path.startsWith('/pro') || path.startsWith('/admin');
