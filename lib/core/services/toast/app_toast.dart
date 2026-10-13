import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';

import 'package:exam_guard/core/theme/app_colors.dart';

/// Simple status toast wrapper using BotToast.
class AppToast {
  AppToast._();

  static TransitionBuilder init() => BotToastInit();

  static void showSuccess(String message) {
    BotToast.showText(
      text: message,
      contentColor: AppColors.success,
      textStyle: const TextStyle(color: AppColors.textHighEmphasis),
      duration: const Duration(seconds: 2),
    );
  }

  static void showError(String message) {
    BotToast.showText(
      text: message,
      contentColor: AppColors.error,
      textStyle: const TextStyle(color: AppColors.textHighEmphasis),
      duration: const Duration(seconds: 2),
    );
  }

  static void showInfo(String message) {
    BotToast.showText(
      text: message,
      contentColor: AppColors.primaryDark,
      textStyle: const TextStyle(color: AppColors.textHighEmphasis),
      duration: const Duration(seconds: 2),
    );
  }
}
