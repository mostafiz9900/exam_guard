import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Live camera QR scanner. Wraps `mobile_scanner` so features never import
/// it. Calls [onScanned] with each decoded text; [errorBuilder] gets a
/// short reason when the camera can't be used (e.g. permission denied).
class AppQrScanner extends StatefulWidget {
  const AppQrScanner({
    super.key,
    required this.onScanned,
    required this.errorBuilder,
  });

  final ValueChanged<String> onScanned;
  final Widget Function(BuildContext context, String reason) errorBuilder;

  @override
  State<AppQrScanner> createState() => _AppQrScannerState();
}

class _AppQrScannerState extends State<AppQrScanner> {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MobileScanner(
      controller: _controller,
      onDetect: (capture) {
        for (final code in capture.barcodes) {
          final text = code.rawValue;
          if (text != null && text.isNotEmpty) {
            widget.onScanned(text);
            return;
          }
        }
      },
      errorBuilder: (context, error) => widget.errorBuilder(
        context,
        error.errorCode == MobileScannerErrorCode.permissionDenied
            ? 'permission'
            : 'unavailable',
      ),
    );
  }
}
