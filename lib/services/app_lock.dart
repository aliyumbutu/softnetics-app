import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Optional fingerprint / Face ID lock, off by default.
class AppLock {
  static final _auth = LocalAuthentication();
  static const _key = 'appLock';

  static Future<bool> get enabled async =>
      (await SharedPreferences.getInstance()).getBool(_key) ?? false;

  /// Turning on requires a successful check first, so users can't lock themselves out.
  static Future<bool> set(bool on) async {
    if (on && !(await unlock())) return false;
    (await SharedPreferences.getInstance()).setBool(_key, on);
    return true;
  }

  static Future<bool> unlock() async {
    try {
      if (!await _auth.isDeviceSupported()) return false;
      return await _auth.authenticate(localizedReason: 'Unlock Softnetics');
    } catch (_) {
      return false;
    }
  }
}
