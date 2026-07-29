import 'dart:async';
import 'dart:ui';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/widgets/app_settings_menu.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../application/session_provider.dart';

class SessionSetupScreen extends HookConsumerWidget {
  const SessionSetupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final instituteController = useTextEditingController();
    final supervisorController = useTextEditingController();
    final roomController = useTextEditingController();
    final errorText = useState<String?>(null);
    final isSubmitting = useState(false);

    final animController = useAnimationController(
      duration: const Duration(milliseconds: 800),
    );
    final fadeAnimation = useAnimation(
      CurvedAnimation(parent: animController, curve: Curves.easeOut),
    );

    useEffect(() {
      animController.forward();
      return null;
    }, const []);

    Future<void> startSession() async {
      final room = roomController.text.trim();
      if (room.isEmpty) {
        errorText.value = 'room_required'.tr();
        return;
      }
      isSubmitting.value = true;
      try {
        await ref
            .read(sessionProvider.notifier)
            .createSession(
              instituteName: instituteController.text.trim(),
              teacherName: supervisorController.text.trim(),
              roomNumber: room,
            );
        if (context.mounted) context.go('/dashboard');
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('session_start_failed'.tr()),
              backgroundColor: Theme.of(context).colorScheme.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } finally {
        isSubmitting.value = false;
      }
    }

    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      // Dynamic Background Color (Light-এ সাদা/হালকা, Dark-এ কালো/গাঢ়)
      backgroundColor: colors.surface,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: const [AppSettingsMenu()],
        iconTheme: IconThemeData(color: colors.onSurface),
      ),
      body: Stack(
        children: [
          // Dynamic Glow Effects (Light/Dark অনুযায়ী মানিয়ে নেবে)
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.primary.withValues(alpha: 0.1),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            right: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.secondary.withValues(alpha: 0.1),
              ),
            ),
          ),
          // Blur Layer
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: Container(color: Colors.transparent),
          ),
          // Main Content
          SafeArea(
            child: FadeTransition(
              opacity: AlwaysStoppedAnimation(fadeAnimation),
              child: Center(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.all(AppDimens.spacingLarge ?? 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Dynamic Logo
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colors.primaryContainer.withValues(
                              alpha: 0.3,
                            ),
                            border: Border.all(
                              color: colors.primary.withValues(alpha: 0.2),
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            Icons.shield_outlined,
                            size: 48,
                            color: colors.primary,
                          ),
                        ),
                        SizedBox(height: AppDimens.spacingLarge),
                        Text(
                          'app_name'.tr(),
                          style: textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                            color: colors.onSurface, // Dynamic text color
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'setup_welcome'.tr().toUpperCase(),
                          style: textTheme.labelSmall?.copyWith(
                            letterSpacing: 2,
                            color: colors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: AppDimens.spacingExtraLarge),

                        // Dynamic Glassmorphic Card
                        ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                            child: Container(
                              padding: const EdgeInsets.all(32),
                              decoration: BoxDecoration(
                                // Light/Dark অনুযায়ী কার্ডের ব্যাকগ্রাউন্ড কালার
                                color: colors.surfaceContainerHighest
                                    .withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: colors.outlineVariant.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CustomTextField(
                                    hintText: 'room_hint'.tr(),
                                    controller: roomController,
                                    errorText: errorText.value,
                                    textInputAction: TextInputAction.next,
                                    prefixIcon: Icon(
                                      Icons.meeting_room,
                                      color: colors.onSurfaceVariant,
                                    ),
                                    onChanged: (_) => errorText.value = null,
                                  ),
                                  SizedBox(height: AppDimens.spacingLarge),
                                  CustomTextField(
                                    hintText: 'institute_hint'.tr(),
                                    controller: instituteController,
                                    textInputAction: TextInputAction.next,
                                    prefixIcon: Icon(
                                      Icons.account_balance,
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                  SizedBox(height: AppDimens.spacingLarge),
                                  CustomTextField(
                                    hintText: 'supervisor_hint'.tr(),
                                    controller: supervisorController,
                                    textInputAction: TextInputAction.done,
                                    prefixIcon: Icon(
                                      Icons.badge,
                                      color: colors.onSurfaceVariant,
                                    ),
                                    onSubmitted: (_) => startSession(),
                                  ),
                                  SizedBox(height: AppDimens.spacingExtraLarge),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 56,
                                    child: PrimaryButton(
                                      label: 'start_session'.tr(),
                                      isLoading: isSubmitting.value,
                                      onPressed: startSession,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
