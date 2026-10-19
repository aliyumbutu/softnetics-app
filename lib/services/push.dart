import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Push is optional: without google-services.json / GoogleService-Info.plist
/// Firebase fails to init and everything here quietly does nothing.
class Push {
  static bool ready = false;
  static final _local = FlutterLocalNotificationsPlugin();
  static final _taps = StreamController<String>.broadcast();
  static String? initialUrl;

  /// URLs carried by tapped notifications.
  static Stream<String> get taps => _taps.stream;

  static Future<void> init() async {
    try {
      await Firebase.initializeApp();
      ready = true;
    } catch (e) {
      debugPrint('Firebase not configured, push disabled');
      return;
    }
    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_notification'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (r) {
        if (r.payload?.isNotEmpty == true) _taps.add(r.payload!);
      },
    );
    final m = FirebaseMessaging.instance;
    final first = await m.getInitialMessage();
    initialUrl = first?.data['url'] as String?;
    FirebaseMessaging.onMessageOpenedApp.listen((x) {
      final u = x.data['url'] as String?;
      if (u != null) _taps.add(u);
    });
    // Foreground: FCM shows nothing on its own, so show it locally.
    FirebaseMessaging.onMessage.listen((x) {
      final n = x.notification;
      if (n == null) return;
      _local.show(
        id: x.hashCode,
        title: n.title,
        body: n.body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails('default', 'Softnetics',
              importance: Importance.high, icon: 'ic_stat_notification'),
          iOS: DarwinNotificationDetails(),
        ),
        payload: x.data['url'] as String?,
      );
    });
  }

  /// Asks for permission (when the page needs it) and returns the FCM token.
  static Future<String?> token() async {
    if (!ready) return null;
    final m = FirebaseMessaging.instance;
    await m.requestPermission();
    return m.getToken();
  }
}
