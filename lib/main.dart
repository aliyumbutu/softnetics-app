import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'config.dart';
import 'screens/web_shell_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: kGreen,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
  ));
  final info = await PackageInfo.fromPlatform();
  final link = await AppLinks().getInitialLink();
  final start = (link == null ? null : mapDeepLink(link))?.toString() ?? kStartUrl;
  runApp(SoftneticsApp(startUrl: start, version: info.version));
}

class SoftneticsApp extends StatelessWidget {
  const SoftneticsApp({super.key, required this.startUrl, required this.version});
  final String startUrl, version;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Softnetics',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: kGreen),
        home: WebShellScreen(startUrl: startUrl, version: version),
      );
}
