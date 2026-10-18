import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:exam_guard/core/localization/app_localization.dart';
import 'package:exam_guard/core/theme/app_dimens.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';

/// Result of reading the optional seat layout fields.
class SeatLayoutInput {
  const SeatLayoutInput._({this.rows, this.cols, this.errorKey});

  static const int min = 1;
  static const int max = 30;

  /// Both fields empty → no layout. Otherwise both must be whole numbers
  /// from [min] to [max].
  factory SeatLayoutInput.parse(String rowsText, String colsText) {
    final r = rowsText.trim();
    final c = colsText.trim();
    if (r.isEmpty && c.isEmpty) return const SeatLayoutInput._();
    if (r.isEmpty || c.isEmpty) {
      return const SeatLayoutInput._(errorKey: 'setup_seat_err_both');
    }
    final rows = int.tryParse(r);
    final cols = int.tryParse(c);
    bool inRange(int? v) => v != null && v >= min && v <= max;
    if (!inRange(rows) || !inRange(cols)) {
      return const SeatLayoutInput._(errorKey: 'setup_seat_err_range');
    }
    return SeatLayoutInput._(rows: rows, cols: cols);
  }

  final int? rows;
  final int? cols;

  /// Translation key of the problem (args: min, max), or null when valid.
  final String? errorKey;

  bool get isValid => errorKey == null;
  bool get hasLayout => rows != null && cols != null;
}

/// Optional "rows × columns" seat layout of the exam room.
class SeatLayoutFields extends StatelessWidget {
  const SeatLayoutFields({
    super.key,
    required this.rowsController,
    required this.colsController,
    this.errorText,
    this.onChanged,
  });

  final TextEditingController rowsController;
  final TextEditingController colsController;
  final String? errorText;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final hasError = errorText != null;

    InputDecoration decoration(String label, String hint) => InputDecoration(
      labelText: label,
      hintText: hint,
      isDense: true,
      counterText: '',
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
      ),
      enabledBorder: hasError
          ? OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
              borderSide: BorderSide(color: colors.error),
            )
          : null,
    );

    Widget field(
      TextEditingController controller,
      String label,
      String hint,
      Key key,
    ) => Expanded(
      child: TextField(
        key: key,
        controller: controller,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.next,
        textAlign: TextAlign.center,
        maxLength: 2,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: decoration(label, hint),
        onChanged: (_) => onChanged?.call(),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.grid_view_rounded,
              size: 18.w,
              color: colors.onSurfaceVariant,
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                'setup_seat_layout'.tr(),
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              'setup_optional'.tr(),
              style: textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
        SizedBox(height: AppDimens.spacingSmall),
        Row(
          children: [
            field(
              rowsController,
              'setup_seat_rows'.tr(),
              '6',
              const Key('seat_rows'),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 10.w),
              child: Text(
                '×',
                style: textTheme.titleMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
            field(
              colsController,
              'setup_seat_cols'.tr(),
              '5',
              const Key('seat_cols'),
            ),
          ],
        ),
        SizedBox(height: 6.h),
        Text(
          errorText ?? 'setup_seat_hint'.tr(),
          style: textTheme.bodySmall?.copyWith(
            color: hasError ? colors.error : colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
