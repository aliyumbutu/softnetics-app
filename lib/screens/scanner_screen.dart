import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Pops with the first QR text found, or null if the user backs out.
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});
  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  bool _done = false;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: const Text('Scan QR code')),
        body: MobileScanner(
          onDetect: (cap) {
            final v = cap.barcodes.map((b) => b.rawValue).whereType<String>().firstOrNull;
            if (v == null || _done) return;
            _done = true;
            Navigator.pop(context, v);
          },
        ),
      );
}
