import 'package:flutter/material.dart';
import 'package:exam_guard/core/theme/app_dimens.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';

/// Reusable text field component for ExamGuard presentation layer.
///
/// This widget supports prefix/suffix icons, error display, and consistent dark style.
class CustomTextField extends StatelessWidget {
  const CustomTextField({
    super.key,
    required this.hintText,
    this.controller,
    this.keyboardType,
    this.obscureText = false,
    this.errorText,
    this.prefixIcon,
    this.suffixIcon,
    this.onChanged,
    this.onTap,
    this.onSubmitted,
    this.textInputAction,
    this.readOnly = false,
  });

  final String hintText;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final bool obscureText;
  final String? errorText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
      borderSide: BorderSide(
        color: Theme.of(context).colorScheme.outline,
        width: 1.w,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: AppDimens.inputFieldHeight,
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            obscureText: obscureText,
            readOnly: readOnly,
            onChanged: onChanged,
            onTap: onTap,
            onFieldSubmitted: onSubmitted,
            textInputAction: textInputAction,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: AppDimens.bodyLarge,
            ),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: AppDimens.bodyMedium,
              ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
              prefixIcon: prefixIcon != null
                  ? Padding(
                      padding: EdgeInsets.only(right: AppDimens.spacingSmall),
                      child: IconTheme(
                        data: IconThemeData(
                          color: Theme.of(context).colorScheme.primary,
                          size: 20.w,
                        ),
                        child: prefixIcon!,
                      ),
                    )
                  : null,
              suffixIcon: suffixIcon != null
                  ? Padding(
                      padding: EdgeInsets.only(left: AppDimens.spacingSmall),
                      child: IconTheme(
                        data: IconThemeData(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          size: 20.w,
                        ),
                        child: suffixIcon!,
                      ),
                    )
                  : null,
              contentPadding: EdgeInsets.symmetric(
                horizontal: AppDimens.spacingMedium,
                vertical: AppDimens.spacingSmall,
              ),
              border: border,
              enabledBorder: border,
              focusedBorder: border.copyWith(
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                  width: 1.5.w,
                ),
              ),
              errorBorder: border.copyWith(
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.error,
                  width: 1.5.w,
                ),
              ),
              focusedErrorBorder: border.copyWith(
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.error,
                  width: 1.5.w,
                ),
              ),
              errorText: errorText,
              errorStyle: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: AppDimens.bodySmall,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
