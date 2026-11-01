import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:exam_guard/core/localization/app_localization.dart';
import 'package:exam_guard/core/theme/app_colors.dart';
import 'package:exam_guard/core/theme/app_dimens.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';
import 'package:exam_guard/features/action_log/model/seat_map.dart';
import 'package:exam_guard/features/hall_map/view_model/hall_map_view_model.dart';

/// The seat map with nodes on their seats and each device's approximate
/// area (circle) and best guess (dot). Scrolls sideways in wide rooms.
class HallMapCanvas extends StatelessWidget {
  const HallMapCanvas({
    super.key,
    required this.data,
    required this.placing,
    required this.selectedNode,
    required this.onSeatTap,
    required this.onDeviceTap,
  });

  final HallMapData data;
  final bool placing;
  final String? selectedNode;
  final void Function(int row, int col) onSeatTap;
  final ValueChanged<LocatedDevice> onDeviceTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final labelW = 20.w;
    final labelH = 16.h;

    return LayoutBuilder(
      builder: (context, c) {
        final cell = ((c.maxWidth - labelW) / data.cols).clamp(30.0, 48.0);
        final gridW = cell * data.cols;
        final gridH = cell * data.rows;
        final node = 26.0.clamp(0.0, cell * 0.8);
        final dot = 22.0.clamp(0.0, cell * 0.7);

        final nodeSpots = [
          for (final n in data.nodes)
            if (n.seat != null) (n.seat!.$2 + 0.5, n.seat!.$1 + 0.5),
        ];
        // A device right at a node would hide it: show its dot a little
        // towards the middle of the room (its area circle stays true).
        (double, double) dotAt(LocatedDevice d) {
          final (x, y) = (d.result.at.x, d.result.at.y);
          for (final (nx, ny) in nodeSpots) {
            if ((x - nx).abs() < 0.4 && (y - ny).abs() < 0.4) {
              final cx = data.cols / 2, cy = data.rows / 2;
              final dx = cx - nx, dy = cy - ny;
              final len = math.sqrt(dx * dx + dy * dy);
              if (len < 1e-6) return (x + 0.55, y);
              return (nx + 0.55 * dx / len, ny + 0.55 * dy / len);
            }
          }
          return (x, y);
        }

        Positioned centred(double x, double y, double size, Widget child) =>
            Positioned(
              left: x * cell - size / 2,
              top: y * cell - size / 2,
              width: size,
              height: size,
              child: child,
            );

        final grid = SizedBox(
          width: gridW,
          height: gridH,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned.fill(
                child: GestureDetector(
                  key: const Key('hall_map_grid'),
                  behavior: HitTestBehavior.opaque,
                  onTapUp: placing
                      ? (e) => onSeatTap(
                          (e.localPosition.dy / cell).floor().clamp(
                            0,
                            data.rows - 1,
                          ),
                          (e.localPosition.dx / cell).floor().clamp(
                            0,
                            data.cols - 1,
                          ),
                        )
                      : null,
                  child: CustomPaint(
                    painter: _SeatsPainter(
                      rows: data.rows,
                      cols: data.cols,
                      cell: cell,
                      fill: placing
                          ? colors.primary.withValues(alpha: 0.10)
                          : colors.surfaceContainerHighest,
                      label: (textTheme.labelSmall ?? const TextStyle())
                          .copyWith(
                            fontSize: cell * 0.22,
                            color: colors.onSurfaceVariant.withValues(
                              alpha: 0.7,
                            ),
                          ),
                      showLabels: cell >= 34,
                    ),
                  ),
                ),
              ),
              // Areas first (under everything), then nodes, then dots.
              for (final d in data.devices)
                () {
                  final color = d.isAlert
                      ? colors.error
                      : Colors.orange.shade700;
                  final size = d.result.radius * cell * 2;
                  return centred(
                    d.result.at.x,
                    d.result.at.y,
                    size,
                    IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color.withValues(alpha: 0.10),
                          border: Border.all(
                            color: color.withValues(alpha: 0.45),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  );
                }(),
              for (final n in data.nodes)
                if (n.seat != null)
                  centred(
                    n.seat!.$2 + 0.5,
                    n.seat!.$1 + 0.5,
                    node,
                    IgnorePointer(
                      child: Tooltip(
                        message: n.member.name,
                        child: Container(
                          key: Key('hall_map_node_marker_${n.member.id}'),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: n.isLive ? AppColors.success : colors.error,
                            border: Border.all(
                              color: placing && n.member.id == selectedNode
                                  ? colors.primary
                                  : colors.surface,
                              width: placing && n.member.id == selectedNode
                                  ? 3
                                  : 2,
                            ),
                          ),
                          child: Icon(
                            n.isLive
                                ? Icons.sensors_rounded
                                : Icons.sensors_off_rounded,
                            size: node * 0.6,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
              for (final d in data.devices)
                centred(
                  dotAt(d).$1,
                  dotAt(d).$2,
                  math.max(dot, 32),
                  IgnorePointer(
                    ignoring: placing,
                    child: GestureDetector(
                      key: Key('hall_map_dot_${d.device.id}'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onDeviceTap(d),
                      child: Center(
                        child: Container(
                          width: dot,
                          height: dot,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: d.isAlert
                                ? colors.error
                                : Colors.orange.shade700,
                            border: Border.all(color: colors.surface, width: 2),
                            boxShadow: const [
                              BoxShadow(blurRadius: 4, color: Colors.black26),
                            ],
                          ),
                          child: Icon(
                            d.isAlert
                                ? Icons.priority_high_rounded
                                : Icons.bluetooth_rounded,
                            size: dot * 0.6,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );

        final label = textTheme.labelSmall?.copyWith(
          color: colors.onSurfaceVariant,
          fontWeight: FontWeight.bold,
        );
        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Front of the room.
            Container(
              margin: EdgeInsetsDirectional.only(start: labelW, bottom: 4.h),
              width: gridW,
              padding: EdgeInsets.symmetric(vertical: 6.h),
              decoration: BoxDecoration(
                color: colors.secondaryContainer,
                borderRadius: BorderRadius.circular(AppDimens.radiusSmall),
              ),
              child: Text(
                'incident_seat_front'.tr(),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.labelMedium?.copyWith(
                  color: colors.onSecondaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Row(
              children: [
                SizedBox(width: labelW),
                for (var col = 0; col < data.cols; col++)
                  SizedBox(
                    width: cell,
                    height: labelH,
                    child: Center(
                      child: Text(SeatId.colLabel(col), style: label),
                    ),
                  ),
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    for (var row = 0; row < data.rows; row++)
                      SizedBox(
                        width: labelW,
                        height: cell,
                        child: Center(
                          child: Text(SeatId.rowLabel(row), style: label),
                        ),
                      ),
                  ],
                ),
                grid,
              ],
            ),
          ],
        );
        // Map space is physical: keep it left-to-right in every language.
        return Directionality(
          textDirection: TextDirection.ltr,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: content,
          ),
        );
      },
    );
  }
}

class _SeatsPainter extends CustomPainter {
  _SeatsPainter({
    required this.rows,
    required this.cols,
    required this.cell,
    required this.fill,
    required this.label,
    required this.showLabels,
  });

  final int rows;
  final int cols;
  final double cell;
  final Color fill;
  final TextStyle label;
  final bool showLabels;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = fill;
    final gap = cell * 0.1;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final rect = Rect.fromLTWH(
          c * cell + gap / 2,
          r * cell + gap / 2,
          cell - gap,
          cell - gap,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(cell * 0.15)),
          paint,
        );
        if (!showLabels) continue;
        final tp = TextPainter(
          text: TextSpan(text: SeatId.format(r, c), style: label),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(rect.left + 3, rect.bottom - tp.height - 2));
      }
    }
  }

  @override
  bool shouldRepaint(_SeatsPainter old) =>
      old.rows != rows ||
      old.cols != cols ||
      old.cell != cell ||
      old.fill != fill ||
      old.label != label ||
      old.showLabels != showLabels;
}
