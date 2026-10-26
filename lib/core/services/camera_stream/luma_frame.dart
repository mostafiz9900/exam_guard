import 'dart:typed_data';

/// One camera frame reduced to brightness (luma, 0–255 per pixel).
///
/// Pixel (x, y) is `luma[y * bytesPerRow + x]`; [bytesPerRow] can be larger
/// than [width] (row padding). Coordinates are in the camera's buffer
/// orientation; [rotationDegrees] (0, 90, 180, 270) is the clockwise turn
/// that makes the frame upright on screen.
class LumaFrame {
  const LumaFrame({
    required this.width,
    required this.height,
    required this.bytesPerRow,
    required this.luma,
    this.rotationDegrees = 0,
    this.timestamp = Duration.zero,
  });

  final int width;
  final int height;
  final int bytesPerRow;
  final Uint8List luma;
  final int rotationDegrees;

  /// Time since the stream started (monotonic).
  final Duration timestamp;

  int at(int x, int y) => luma[y * bytesPerRow + x];
}
