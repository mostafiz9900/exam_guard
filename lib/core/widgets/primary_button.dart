import 'package:flutter/material.dart';

import 'package:exam_guard/core/theme/app_colors.dart';
import 'package:exam_guard/core/theme/app_dimens.dart';
import 'package:exam_guard/core/widgets/app_loader.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';

/// Primary button used across the app for strong calls to action.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.height,
    this.isLoading = false,
    this.backgroundColor,
    this.foregroundColor,
  });

  final String label;
  final VoidCallback? onPressed;
  final double? height;
  final bool isLoading;
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height ?? AppDimens.buttonHeight,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              backgroundColor ?? Theme.of(context).colorScheme.primary,
          foregroundColor:
              foregroundColor ?? Theme.of(context).colorScheme.onPrimary,
          disabledBackgroundColor: AppColors.disabled,
          disabledForegroundColor: AppColors.textLowEmphasis,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
          ),
        ),
        child: isLoading
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 18.w,
                    height: 18.w,
                    child: const AppLoader.ring(
                      color: AppColors.onPrimary,
                      lineWidth: 2,
                      size: 18,
                    ),
                  ),
                  SizedBox(width: AppDimens.spacingSmall),
                  Text(
                    'Please wait...',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color:
                          foregroundColor ??
                          Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ],
              )
            : Text(
                label,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color:
                      foregroundColor ??
                      Theme.of(context).colorScheme.onPrimary,
                ),
              ),
      ),
    );
  }
}
