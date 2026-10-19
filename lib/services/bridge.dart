import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../config.dart';
import 'app_lock.dart';
import 'push.dart';

/// Injected on every page. Pages must work when this is absent.
const bridgeScript = r'''
(function () {
  if (window.SoftneticsApp) return;
  var call = function (n, a) { return window.flutter_inappwebview.callHandler(n, a); };
  window.SoftneticsApp = {
    getAppInfo: function () { return call('getAppInfo'); },
    setPullToRefresh: function (on) { return call('setPullToRefresh', on); },
    keepScreenOn: function (on) { return call('keepScreenOn', on); },
    share: function (d) { return call('share', d); },
    saveFile: function (name, mime, b64) { return call('saveFile', {name: name, mime: mime, base64: b64}); },
    openExternal: function (u) { return call('openExternal', u); },
    scanQr: function () { return call('scanQr'); },
    registerPushToken: function () { return call('registerPushToken'); },
    setAppLock: function (on) { return call('setAppLock', on); },
    getAppLock: function () { return call('getAppLock'); }
  };
  if (!navigator.share) {
    navigator.share = function (d) { return call('share', d || {}); };
  }
  document.addEventListener('click', function (e) {
    var a = e.target.closest && e.target.closest('a[href^="blob:"][download]');
    if (!a) return;
    e.preventDefault();
    fetch(a.href).then(function (r) { return r.blob(); }).then(function (b) {
      var fr = new FileReader();
      fr.onload = function () { call('saveFile', {name: a.download, mime: b.type, base64: fr.result}); };
      fr.readAsDataURL(b);
    });
  }, true);
  window.dispatchEvent(new Event('softnetics-app-ready'));
})();
''';

class BridgeHooks {
  BridgeHooks({
    required this.version,
    required this.platform,
    required this.setPullToRefresh,
    required this.saveFile,
  });
  final String version, platform;
  final void Function(bool) setPullToRefresh;
  final void Function(String name, String b64) saveFile;
}

void registerBridge(InAppWebViewController c, BridgeHooks h) {
  // Handlers answer only pages on the platform host.
  Future<dynamic> guarded(Future<dynamic> Function() f) async {
    final u = await c.getUrl();
    if (u?.host != kHost) return null;
    return f();
  }

  c.addJavaScriptHandler(
    handlerName: 'getAppInfo',
    callback: (_) =>
        guarded(() async => {'version': h.version, 'platform': h.platform}),
  );
  c.addJavaScriptHandler(
    handlerName: 'setPullToRefresh',
    callback: (a) => guarded(() async => h.setPullToRefresh(a.first == true)),
  );
  c.addJavaScriptHandler(
    handlerName: 'keepScreenOn',
    callback: (a) => guarded(() async {
      a.first == true
          ? await WakelockPlus.enable()
          : await WakelockPlus.disable();
    }),
  );
  c.addJavaScriptHandler(
    handlerName: 'share',
    callback: (a) => guarded(() async {
      final m = Map<String, dynamic>.from(a.first as Map);
      final text = [
        m['text'],
        m['url'],
      ].where((e) => e != null && '$e'.isNotEmpty).join('\n');
      await SharePlus.instance.share(
        ShareParams(title: m['title'] as String?, text: text),
      );
    }),
  );
  c.addJavaScriptHandler(
    handlerName: 'saveFile',
    callback: (a) => guarded(() async {
      final m = Map<String, dynamic>.from(a.first as Map);
      h.saveFile(m['name'] as String? ?? 'download', m['base64'] as String);
    }),
  );
  c.addJavaScriptHandler(
    handlerName: 'openExternal',
    callback: (a) => guarded(() async {
      final u = Uri.tryParse('${a.first}');
      if (u != null && (u.scheme == 'https' || u.scheme == 'http')) {
        await launchUrl(u, mode: LaunchMode.externalApplication);
      }
    }),
  );
}

void registerPhase2Bridge(
  InAppWebViewController c,
  Future<String?> Function() scanQr,
) {
  Future<dynamic> guarded(Future<dynamic> Function() f) async {
    final u = await c.getUrl();
    return u?.host == kHost ? f() : null;
  }

  c.addJavaScriptHandler(
    handlerName: 'scanQr',
    callback: (_) => guarded(scanQr),
  );
  c.addJavaScriptHandler(
    handlerName: 'registerPushToken',
    callback: (_) => guarded(Push.token),
  );
  c.addJavaScriptHandler(
    handlerName: 'setAppLock',
    callback: (a) => guarded(() => AppLock.set(a.first == true)),
  );
  c.addJavaScriptHandler(
    handlerName: 'getAppLock',
    callback: (_) => guarded(() => AppLock.enabled),
  );
}
