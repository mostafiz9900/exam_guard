import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:exam_guard/core/widgets/app_text_context_menu.dart';
import 'package:exam_guard/core/localization/app_localization.dart';
import 'package:exam_guard/core/theme/app_dimens.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';

/// Result of reading the optional seat layout fields.
class SeatLayoutInput {
  const SeatLayoutInput._({
    this.rows,
    this.cols,
    this.errorKey,
    this.badRows = false,
    this.badCols = false,
  });

  static const int min = 1;
  static const int max = 30;

  /// Both fields empty → no layout. Otherwise both must be whole numbers
  /// from [min] to [max].
  factory SeatLayoutInput.parse(String rowsText, String colsText) {
    final r = rowsText.trim();
    final c = colsText.trim();
    if (r.isEmpty && c.isEmpty) return const SeatLayoutInput._();
    final rows = int.tryParse(r);
    final cols = int.tryParse(c);
    bool inRange(int? v) => v != null && v >= min && v <= max;
    // A wrong number first: fixing only the empty field would hit it next.
    final badRows = r.isNotEmpty && !inRange(rows);
    final badCols = c.isNotEmpty && !inRange(cols);
    if (badRows || badCols) {
      return SeatLayoutInput._(
        errorKey: 'setup_seat_err_range',
        badRows: badRows,
        badCols: badCols,
      );
    }
    if (r.isEmpty || c.isEmpty) {
      return SeatLayoutInput._(
        errorKey: 'setup_seat_err_both',
        badRows: r.isEmpty,
        badCols: c.isEmpty,
      );
    }
    return SeatLayoutInput._(rows: rows, cols: cols);
  }

  final int? rows;
  final int? cols;

  /// Translation key of the problem (args: min, max), or null when valid.
  final String? errorKey;

  /// Which field the problem is in (both for a shared problem).
  final bool badRows;
  final bool badCols;

  bool get isValid => errorKey == null;
  bool get hasLayout => rows != null && cols != null;
}

/// Numbered circle for form steps ("1", "2").
class StepBadge extends StatelessWidget {
  const StepBadge({super.key, required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 28.w,
      height: 28.w,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: colors.primary, shape: BoxShape.circle),
      child: Text(
        '$step',
        style: Theme.of(context).textTheme.labelLarge
            ?.copyWith(color: colors.onPrimary, fontWeight: FontWeight.w800),
      ),
    );
  }
}

/// Optional "rows × columns" seat layout of the exam room, with a live
/// summary and a small preview of the seat map.
class SeatLayoutFields extends StatelessWidget {
  const SeatLayoutFields({
    super.key,
    required this.rowsController,
    required this.colsController,
    this.errorText,
    this.badRows = false,
    this.badCols = false,
    this.onChanged,
    this.rowsFocus,
    this.colsFocus,
    this.onDone,
    this.step,
  });

  final TextEditingController rowsController;
  final TextEditingController colsController;
  final String? errorText;

  /// Which field [errorText] is about (red border).
  final bool badRows;
  final bool badCols;
  final VoidCallback? onChanged;
  final FocusNode? rowsFocus;
  final FocusNode? colsFocus;

  /// Keyboard "done" on the columns field.
  final VoidCallback? onDone;

  /// Form step number shown instead of the grid icon.
  final int? step;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final hasError = errorText != null;

    OutlineInputBorder outline(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
          borderSide: BorderSide(color: color, width: width),
        );

    Widget field(
      TextEditingController controller,
      String label,
      String hint,
      Key key,
      bool bad,
      FocusNode? focus,
      bool last,
    ) => Expanded(
      child: TextField(
        contextMenuBuilder: appTextContextMenu,
        key: key,
        controller: controller,
        focusNode: focus,
        keyboardType: TextInputType.number,
        textInputAction: last ? TextInputAction.done : TextInputAction.next,
        onSubmitted: last ? (_) => onDone?.call() : null,
        textAlign: TextAlign.center,
        maxLength: 2,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          floatingLabelBehavior: FloatingLabelBehavior.always,
          isDense: true,
          counterText: '',
          filled: true,
          fillColor: colors.surface,
          border: outline(colors.outline),
          enabledBorder: bad
              ? outline(colors.error, 1.5)
              : outline(colors.outline),
          focusedBorder: outline(bad ? colors.error : colors.primary, 1.5),
        ),
        onChanged: (_) => onChanged?.call(),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (step != null)
              StepBadge(step: step!)
            else
              Icon(Icons.grid_view_rounded, size: 18.w, color: colors.primary),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                'setup_seat_layout'.tr(),
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'setup_optional'.tr(),
                style: textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: AppDimens.spacingMedium),
        Row(
          children: [
            field(
              rowsController,
              'setup_seat_rows'.tr(),
              '6',
              const Key('seat_rows'),
              badRows,
              rowsFocus,
              false,
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 10.w),
              child: Text(
                '×',
                style: textTheme.titleLarge?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
            field(
              colsController,
              'setup_seat_cols'.tr(),
              '5',
              const Key('seat_cols'),
              badCols,
              colsFocus,
              true,
            ),
          ],
        ),
        SizedBox(height: 6.h),
        if (hasError)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 16.w,
                color: colors.error,
              ),
              SizedBox(width: 4.w),
              Expanded(
                child: Text(
                  errorText!,
                  style: textTheme.bodySmall?.copyWith(color: colors.error),
                ),
              ),
            ],
          )
        else
          ListenableBuilder(
            listenable: Listenable.merge([rowsController, colsController]),
            builder: (context, _) {
              final input = SeatLayoutInput.parse(
                rowsController.text,
                colsController.text,
              );
              if (!input.hasLayout) {
                return Text(
                  'setup_seat_hint'.tr(),
                  style: textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                );
              }
              return _SeatPreview(rows: input.rows!, cols: input.cols!);
            },
          ),
      ],
    );
  }
}

/// "6 rows × 5 columns = 30 seats" with a miniature of the room.
class _SeatPreview extends StatelessWidget {
  const _SeatPreview({required this.rows, required this.cols});

  final int rows;
  final int cols;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    // Very large rooms are drawn capped; the summary gives the real size.
    const cap = 12;
    final r = rows.clamp(1, cap);
    final c = cols.clamp(1, cap);
    final dot = 7.w;
    final gap = 3.w;
    return Container(
      key: const Key('seat_preview'),
      width: double.infinity,
      padding: EdgeInsets.all(AppDimens.spacingSmall),
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
      ),
      child: Row(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: c * (dot + gap) - gap,
                height: 3.h,
                margin: EdgeInsets.only(bottom: 4.h),
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              for (var i = 0; i < r; i++)
                Padding(
                  padding: EdgeInsets.only(top: i == 0 ? 0 : gap),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var j = 0; j < c; j++)
                        Container(
                          width: dot,
                          height: dot,
                          margin: EdgeInsetsDirectional.only(
                            start: j == 0 ? 0 : gap,
                          ),
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
          SizedBox(width: AppDimens.spacingMedium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'setup_seat_total'.tr(args: {'count': '${rows * cols}'}),
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.onPrimaryContainer,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  'setup_seat_summary'.tr(
                    args: {'rows': '$rows', 'cols': '$cols'},
                  ),
                  style: textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                Text(
                  'setup_seat_front'.tr(),
                  style: textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
