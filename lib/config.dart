import 'package:flutter/material.dart';

const kHost = 'scsap.softnetics.ng';
const kStartUrl = 'https://$kHost/';
const kScheme = 'softnetics';
const kGreen = Color(0xFF1B7A3E);

// ponytail: route for the Paystack verify page; confirm against the web code.
const kPaystackVerifyPath = '/wallet/topup/callback';

// Pages where pull-to-refresh and zoom make no sense.
bool isMapPage(String path) =>
    path.contains('boundary') || path.contains('map');
