import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// A QR code for [data]. Wraps `qr_flutter` so features never import it.
/// Always black on white (scanners read inverted codes poorly), also in
/// dark mode.
class AppQrImage extends StatelessWidget {
  const AppQrImage({super.key, required this.data, required this.size});

  final String data;
  final double size;

  @override
  Widget build(BuildContext context) {
    return QrImageView(
      data: data,
      size: size,
      backgroundColor: Colors.white,
      errorCorrectionLevel: QrErrorCorrectLevel.M,
      semanticsLabel: data,
    );
  }
}
