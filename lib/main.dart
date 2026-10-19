import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:upgrader/upgrader.dart';
import 'config.dart';
import 'services/push.dart';
import 'screens/web_shell_screen.dart';

// White status + navigation bars with dark icons, everywhere.
const whiteBars = SystemUiOverlayStyle(
  statusBarColor: Colors.white,
  statusBarIconBrightness: Brightness.dark,
  statusBarBrightness: Brightness.light,
  systemNavigationBarColor: Colors.white,
  systemNavigationBarIconBrightness: Brightness.dark,
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(whiteBars);
  await Push.init();
  final info = await PackageInfo.fromPlatform();
  final link = await AppLinks().getInitialLink();
  final start =
      (link == null ? null : mapDeepLink(link))?.toString() ??
      (Push.initialUrl == null
              ? null
              : mapDeepLink(Uri.parse(Push.initialUrl!)))
          ?.toString() ??
      kStartUrl;
  runApp(SoftneticsApp(startUrl: start, version: info.version));
}

class SoftneticsApp extends StatelessWidget {
  const SoftneticsApp({
    super.key,
    required this.startUrl,
    required this.version,
  });
  final String startUrl, version;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Softnetics',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true, colorSchemeSeed: kGreen),
    home: UpgradeAlert(
      child: WebShellScreen(startUrl: startUrl, version: version),
    ),
  );
}
