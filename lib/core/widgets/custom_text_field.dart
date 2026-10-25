import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:exam_guard/core/widgets/app_text_context_menu.dart';
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
    this.labelText,
    this.isRequired = false,
    this.helperText,
    this.maxLength,
    this.inputFormatters,
    this.validator,
    this.autovalidateMode,
    this.textCapitalization = TextCapitalization.none,
    this.focusNode,
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

  /// Floating label above the field; [isRequired] adds a " *".
  final String? labelText;
  final bool isRequired;

  /// Grey hint under the field while there is no error.
  final String? helperText;

  /// Hard limit with a "12/20" counter.
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;

  /// Form validation (inside a [Form]); returns the message or null.
  final FormFieldValidator<String>? validator;
  final AutovalidateMode? autovalidateMode;
  final TextCapitalization textCapitalization;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
      borderSide: BorderSide(
        color: Theme.of(context).colorScheme.outline,
        width: 1.w,
      ),
    );

    return TextFormField(
      controller: controller,
      contextMenuBuilder: appTextContextMenu,
      keyboardType: keyboardType,
      obscureText: obscureText,
      readOnly: readOnly,
      onChanged: onChanged,
      onTap: onTap,
      onFieldSubmitted: onSubmitted,
      textInputAction: textInputAction,
      maxLength: maxLength,
      maxLengthEnforcement: MaxLengthEnforcement.enforced,
      inputFormatters: inputFormatters,
      validator: validator,
      autovalidateMode: autovalidateMode,
      textCapitalization: textCapitalization,
      focusNode: focusNode,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurface,
        fontSize: AppDimens.bodyLarge,
      ),
      decoration: InputDecoration(
        isDense: true,
        hintText: hintText,
        labelText: labelText == null
            ? null
            : isRequired
            ? '$labelText *'
            : labelText,
        helperText: helperText,
        helperMaxLines: 2,
        floatingLabelBehavior: labelText == null
            ? null
            : FloatingLabelBehavior.always,
        hintStyle: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: AppDimens.bodyMedium,
        ),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
        prefixIcon: prefixIcon != null
            ? Padding(
                padding: EdgeInsetsDirectional.only(
                  start: AppDimens.spacingSmall,
                  end: AppDimens.spacingExtraSmall,
                ),
                child: IconTheme(
                  data: IconThemeData(
                    color: Theme.of(context).colorScheme.primary,
                    size: 20.w,
                  ),
                  child: prefixIcon!,
                ),
              )
            : null,
        prefixIconConstraints: BoxConstraints(minWidth: 40.w, minHeight: 40.w),
        suffixIcon: suffixIcon != null
            ? Padding(
                padding: EdgeInsetsDirectional.only(
                  start: AppDimens.spacingExtraSmall,
                  end: AppDimens.spacingSmall,
                ),
                child: IconTheme(
                  data: IconThemeData(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    size: 20.w,
                  ),
                  child: suffixIcon!,
                ),
              )
            : null,
        suffixIconConstraints: BoxConstraints(minWidth: 40.w, minHeight: 40.w),
        contentPadding: EdgeInsetsDirectional.symmetric(
          horizontal: AppDimens.spacingMedium,
          vertical: AppDimens.spacingMedium,
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
        errorMaxLines: 2,
        errorStyle: TextStyle(
          color: Theme.of(context).colorScheme.error,
          fontSize: AppDimens.bodySmall,
        ),
      ),
    );
  }
}
