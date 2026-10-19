import 'package:flutter/material.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import '../config.dart';

/// Opens Paystack in the system browser. Returns the reference on success,
/// null if the user cancelled. Server verification stays the source of truth.
Future<String?> payWithPaystack(String checkoutUrl) async {
  try {
    final result = await FlutterWebAuth2.authenticate(
      url: checkoutUrl,
      callbackUrlScheme: kScheme,
    );
    return Uri.parse(result).queryParameters['reference'] ?? '';
  } catch (e) {
    debugPrint('paystack closed: $e');
    return null;
  }
}
