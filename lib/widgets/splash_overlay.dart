import 'package:flutter/material.dart';
import '../config.dart';

/// Same logo, size and position as the native splash so the hand-over is invisible.
class SplashOverlay extends StatefulWidget {
  const SplashOverlay({super.key});
  @override
  State<SplashOverlay> createState() => _SplashOverlayState();
}

class _SplashOverlayState extends State<SplashOverlay> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..forward();
  bool _showBar = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _showBar = true);
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(parent: _c, curve: Curves.easeOut);
    return ColoredBox(
      color: Colors.white,
      child: Stack(children: [
        Center(
          child: FadeTransition(
            opacity: curve,
            child: ScaleTransition(
              scale: Tween(begin: 0.92, end: 1.0).animate(curve),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Image.asset('assets/logo.png', width: 220),
                const SizedBox(height: 24),
                SizedBox(
                  width: 120,
                  height: 2,
                  child: _showBar
                      ? const LinearProgressIndicator(color: kGreen, backgroundColor: Color(0x221B7A3E))
                      : null,
                ),
              ]),
            ),
          ),
        ),
        Positioned(
          bottom: 32 + MediaQuery.of(context).padding.bottom,
          left: 0,
          right: 0,
          child: const Text('By Softnetics',
              textAlign: TextAlign.center, style: TextStyle(color: Colors.black45, fontSize: 12)),
        ),
      ]),
    );
  }
}
