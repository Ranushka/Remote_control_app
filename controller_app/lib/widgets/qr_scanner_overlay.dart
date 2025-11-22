import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QrScannerOverlay extends StatelessWidget {
  const QrScannerOverlay({super.key, required this.onDetect, required this.onClose});

  final ValueChanged<String?> onDetect;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withOpacity(0.8),
      child: SafeArea(
        child: Stack(
          children: [
            MobileScanner(
              onDetect: (capture) {
                final barcode = capture.barcodes.isNotEmpty ? capture.barcodes.first : null;
                if (barcode != null) {
                  onDetect(barcode.rawValue);
                }
              },
            ),
            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                style: IconButton.styleFrom(backgroundColor: Colors.black54, foregroundColor: Colors.white),
                onPressed: onClose,
                icon: const Icon(Icons.close),
              ),
            )
          ],
        ),
      ),
    );
  }
}
