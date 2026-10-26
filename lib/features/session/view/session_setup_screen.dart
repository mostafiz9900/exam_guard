import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/localization/app_localization.dart';
import 'package:exam_guard/core/navigation/app_navigator.dart';
import 'package:exam_guard/core/navigation/app_routes.dart';
import 'package:exam_guard/core/theme/app_dimens.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';
import 'package:exam_guard/core/widgets/app_settings_menu.dart';
import 'package:exam_guard/core/widgets/custom_text_field.dart';
import 'package:exam_guard/features/session/model/room_profile.dart';
import 'package:exam_guard/features/session/repository/room_profile_repository.dart';
import 'package:exam_guard/features/session/model/session_form_validator.dart';
import 'package:exam_guard/features/session/view/widgets/exam_hall_backdrop.dart';
import 'package:exam_guard/features/session/view/widgets/seat_layout_fields.dart';
import 'package:exam_guard/features/session/view_model/session_view_model.dart';

/// Start of every exam: room (required), institute, supervisor and the
/// optional seat layout. Invalid characters are blocked while typing; the
/// rest is checked on Start, then live as the invigilator corrects it.
class SessionSetupScreen extends HookConsumerWidget {
  const SessionSetupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formKey = useMemoized(GlobalKey<FormState>.new);
    final instituteController = useTextEditingController();
    final supervisorController = useTextEditingController();
    final roomController = useTextEditingController();
    final seatRowsController = useTextEditingController();
    final seatColsController = useTextEditingController();
    final roomFocus = useFocusNode();
    final instituteFocus = useFocusNode();
    final supervisorFocus = useFocusNode();
    final rowsFocus = useFocusNode();
    final colsFocus = useFocusNode();

    final submitted = useState(false);
    // The "fix the highlighted fields" banner follows the text live.
    useListenable(
      useMemoized(
        () => Listenable.merge([
          roomController,
          instituteController,
          supervisorController,
        ]),
        [roomController, instituteController, supervisorController],
      ),
    );
    final seatInput = useState<SeatLayoutInput?>(null);
    final isSubmitting = useState(false);

    final animController = useAnimationController(
      duration: const Duration(milliseconds: 650),
    );
    final fadeAnimation = useMemoized(
      () => CurvedAnimation(parent: animController, curve: Curves.easeOut),
      [animController],
    );
    useEffect(() => fadeAnimation.dispose, [fadeAnimation]);
    final slideAnimation = useMemoized(
      () => Tween(begin: const Offset(0, 0.06), end: Offset.zero).animate(
        CurvedAnimation(parent: animController, curve: Curves.easeOutCubic),
      ),
      [animController],
    );

    // Slow radar sweep in the header illustration (off with reduced
    // motion; started in an effect, not in build).
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final sweepController = useAnimationController(
      duration: const Duration(seconds: 6),
    );
    useEffect(() {
      if (reduceMotion) {
        sweepController.value = 0.15;
      } else {
        sweepController.repeat();
      }
      return null;
    }, [sweepController, reduceMotion]);
    useEffect(() {
      animController.forward();
      return null;
    }, const []);

    // Rebuild when the session changes so the "last report" button stays
    // in sync (e.g. after returning from an ended exam's report).
    ref.watch(sessionViewModelProvider);
    final lastSession = ref.read(sessionViewModelProvider.notifier).lastSession;
    final canViewLastReport = lastSession != null && !lastSession.isActive;

    void viewLastReport() {
      final opened = ref
          .read(sessionViewModelProvider.notifier)
          .openLastSession();
      if (opened) context.goTo(AppRoute.report);
    }

    String? message(String? key) => key?.tr(
      args: {
        'max': switch (key) {
          'room_too_long' => '${SessionFormValidator.roomMaxLength}',
          'institute_too_long' => '${SessionFormValidator.instituteMaxLength}',
          _ => '${SessionFormValidator.supervisorMaxLength}',
        },
        'min': '${SessionFormValidator.supervisorMinLength}',
      },
    );

    String? seatMessage(SeatLayoutInput? input) => input?.errorKey?.tr(
      args: {'min': '${SeatLayoutInput.min}', 'max': '${SeatLayoutInput.max}'},
    );

    Future<void> startSession() async {
      if (isSubmitting.value) return;
      submitted.value = true;
      final fieldsOk = formKey.currentState?.validate() ?? false;
      final seats = SeatLayoutInput.parse(
        seatRowsController.text,
        seatColsController.text,
      );
      seatInput.value = seats;

      if (!fieldsOk || !seats.isValid) {
        HapticFeedback.mediumImpact();
        // Take the invigilator straight to the first thing to fix.
        final first = [
          if (SessionFormValidator.room(roomController.text) != null) roomFocus,
          if (SessionFormValidator.institute(instituteController.text) != null)
            instituteFocus,
          if (SessionFormValidator.supervisor(supervisorController.text) !=
              null)
            supervisorFocus,
          if (seats.badRows) rowsFocus,
          if (seats.badCols) colsFocus,
        ];
        if (first.isNotEmpty) first.first.requestFocus();
        return;
      }

      FocusScope.of(context).unfocus();
      isSubmitting.value = true;
      try {
        await ref
            .read(sessionViewModelProvider.notifier)
            .createSession(
              instituteName: SessionFormValidator.clean(
                instituteController.text,
              ),
              teacherName: SessionFormValidator.clean(
                supervisorController.text,
              ),
              roomNumber: SessionFormValidator.clean(roomController.text),
              seatRows: seats.rows,
              seatCols: seats.cols,
            );
        if (context.mounted) context.goTo(AppRoute.dashboard);
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
        if (context.mounted) isSubmitting.value = false;
      }
    }

    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final autovalidate = submitted.value
        ? AutovalidateMode.onUserInteraction
        : AutovalidateMode.disabled;
    final seats = seatInput.value;
    final hasErrors =
        submitted.value &&
        (SessionFormValidator.room(roomController.text) != null ||
            SessionFormValidator.institute(instituteController.text) != null ||
            SessionFormValidator.supervisor(supervisorController.text) !=
                null ||
            !(seats?.isValid ?? true));
    final gap = SizedBox(height: AppDimens.spacingMedium);

    final dark = Theme.of(context).brightness == Brightness.dark;
    const overlap = 36.0;

    final startButton = SizedBox(
      height: 56,
      child: FilledButton.icon(
        key: const Key('setup_start'),
        onPressed: isSubmitting.value ? null : startSession,
        icon: isSubmitting.value
            ? SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: colors.onPrimary,
                ),
              )
            : const Icon(Icons.radar_rounded),
        label: Text(
          'start_session'.tr(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        style: FilledButton.styleFrom(
          textStyle: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );

    // Sheet over the header. A thin border instead of a shadow: renders
    // the same on every device.
    final form = Material(
      color: dark ? colors.surfaceContainer : colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: colors.outlineVariant.withValues(alpha: dark ? 1 : 0.7),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppDimens.spacingLarge,
          AppDimens.spacingLarge,
          AppDimens.spacingLarge,
          AppDimens.spacingLarge,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StepTitle(
              step: 1,
              title: 'setup_exam_details'.tr(),
              subtitle: 'setup_required_note'.tr(),
            ),
            SizedBox(height: AppDimens.spacingLarge),
            CustomTextField(
              key: const Key('setup_room'),
              labelText: 'room_number'.tr(),
              isRequired: true,
              hintText: 'room_hint'.tr(),
              helperText: 'setup_room_helper'.tr(),
              controller: roomController,
              focusNode: roomFocus,
              maxLength: SessionFormValidator.roomMaxLength,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                  SessionFormValidator.roomAllowed,
                ),
              ],
              validator: (v) => message(SessionFormValidator.room(v ?? '')),
              textInputAction: TextInputAction.next,
              autovalidateMode: autovalidate,
              prefixIcon: const Icon(Icons.meeting_room_outlined),
            ),
            _SavedRoomHint(
              controller: roomController,
              profileOf: ref.read(roomProfileRepositoryProvider).load,
            ),
            gap,
            CustomTextField(
              key: const Key('setup_institute'),
              labelText: 'institute_name'.tr(),
              hintText: 'institute_hint'.tr(),
              controller: instituteController,
              focusNode: instituteFocus,
              maxLength: SessionFormValidator.instituteMaxLength,
              textCapitalization: TextCapitalization.words,
              inputFormatters: [
                FilteringTextInputFormatter.deny(
                  SessionFormValidator.instituteBlocked,
                ),
                FilteringTextInputFormatter.singleLineFormatter,
              ],
              validator: (v) =>
                  message(SessionFormValidator.institute(v ?? '')),
              textInputAction: TextInputAction.next,
              autovalidateMode: autovalidate,
              prefixIcon: const Icon(Icons.account_balance_outlined),
            ),
            gap,
            CustomTextField(
              key: const Key('setup_supervisor'),
              labelText: 'supervisor_name'.tr(),
              hintText: 'supervisor_hint'.tr(),
              controller: supervisorController,
              focusNode: supervisorFocus,
              maxLength: SessionFormValidator.supervisorMaxLength,
              textCapitalization: TextCapitalization.words,
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                  SessionFormValidator.nameAllowed,
                ),
              ],
              validator: (v) =>
                  message(SessionFormValidator.supervisor(v ?? '')),
              textInputAction: TextInputAction.next,
              autovalidateMode: autovalidate,
              prefixIcon: const Icon(Icons.badge_outlined),
            ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: AppDimens.spacingMedium),
              child: Divider(color: colors.outlineVariant),
            ),
            SeatLayoutFields(
              step: 2,
              rowsController: seatRowsController,
              colsController: seatColsController,
              rowsFocus: rowsFocus,
              colsFocus: colsFocus,
              errorText: seatMessage(seats),
              badRows: seats?.badRows ?? false,
              badCols: seats?.badCols ?? false,
              onChanged: () {
                if (!submitted.value) return;
                seatInput.value = SeatLayoutInput.parse(
                  seatRowsController.text,
                  seatColsController.text,
                );
              },
              onDone: startSession,
            ),
            SizedBox(height: AppDimens.spacingLarge),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: hasErrors
                  ? Padding(
                      padding: EdgeInsets.only(bottom: AppDimens.spacingSmall),
                      child: _FixBanner(text: 'setup_fix_errors'.tr()),
                    )
                  : const SizedBox(width: double.infinity),
            ),
            startButton,
          ],
        ),
      ),
    );

    return Scaffold(
      backgroundColor: colors.surface,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: Colors.white,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        actions: const [AppSettingsMenu()],
      ),
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Form(
          key: formKey,
          autovalidateMode: autovalidate,
          child: Column(
            children: [
              // Hero: exam hall illustration behind the title.
              Stack(
                children: [
                  Positioned.fill(
                    child: ExamHallBackdrop(sweep: sweepController, dark: dark),
                  ),
                  SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        kToolbarHeight - 12,
                        20,
                        overlap + 20,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 520),
                          child: FadeTransition(
                            opacity: fadeAnimation,
                            child: const _Hero(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Transform.translate(
                offset: const Offset(0, -overlap),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppDimens.spacingMedium,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SlideTransition(
                            position: slideAnimation,
                            child: FadeTransition(
                              opacity: fadeAnimation,
                              child: form,
                            ),
                          ),
                          SizedBox(height: AppDimens.spacingMedium),
                          if (canViewLastReport) ...[
                            FilledButton.tonalIcon(
                              onPressed: viewLastReport,
                              icon: const Icon(Icons.description_outlined),
                              label: Text(
                                'view_last_report'.tr(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                            SizedBox(height: AppDimens.spacingSmall),
                          ],
                          TextButton.icon(
                            onPressed: () => context.pushTo(AppRoute.history),
                            icon: const Icon(Icons.history_rounded),
                            label: Text(
                              'setup_exam_history'.tr(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(height: AppDimens.spacingSmall),
                          Text.rich(
                            TextSpan(
                              children: [
                                WidgetSpan(
                                  alignment: PlaceholderAlignment.middle,
                                  child: Padding(
                                    padding: EdgeInsetsDirectional.only(
                                      end: 6.w,
                                    ),
                                    child: Icon(
                                      Icons.lock_outline_rounded,
                                      size: 14.w,
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                                TextSpan(text: 'setup_privacy'.tr()),
                              ],
                            ),
                            textAlign: TextAlign.center,
                            style: textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
              ),
              child: Icon(
                Icons.shield_outlined,
                size: 30.w,
                color: Colors.white,
              ),
            ),
            SizedBox(width: AppDimens.spacingMedium),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'app_name'.tr(),
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'setup_new_exam'.tr(),
                    style: textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: AppDimens.spacingMedium),
        Text(
          'setup_welcome'.tr(),
          style: textTheme.bodyMedium?.copyWith(
            color: Colors.white.withValues(alpha: 0.92),
            height: 1.35,
          ),
        ),
        SizedBox(height: AppDimens.spacingMedium),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: const [
            _Pill(
              icon: Icons.bluetooth_searching_rounded,
              label: 'setup_chip_detect',
            ),
            _Pill(
              icon: Icons.notifications_active_outlined,
              label: 'setup_chip_alerts',
            ),
            _Pill(
              icon: Icons.picture_as_pdf_outlined,
              label: 'setup_chip_report',
            ),
          ],
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14.w, color: Colors.white),
          SizedBox(width: 6.w),
          Text(
            label.tr(),
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// "① Exam details" style heading of a form step.
class _StepTitle extends StatelessWidget {
  const _StepTitle({
    required this.step,
    required this.title,
    required this.subtitle,
  });

  final int step;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        StepBadge(step: step),
        SizedBox(width: AppDimens.spacingSmall),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                subtitle,
                style: textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FixBanner extends StatelessWidget {
  const _FixBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      key: const Key('setup_fix_banner'),
      padding: EdgeInsets.all(AppDimens.spacingSmall),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(AppDimens.radiusSmall),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: colors.onErrorContainer),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(text, style: TextStyle(color: colors.onErrorContainer)),
          ),
        ],
      ),
    );
  }
}

/// "Saved room · 9 known devices" under the room field when this room has
/// remembered equipment.
class _SavedRoomHint extends StatelessWidget {
  const _SavedRoomHint({required this.controller, required this.profileOf});

  final TextEditingController controller;
  final RoomProfile? Function(String room) profileOf;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final profile = profileOf(controller.text);
        if (profile == null) return const SizedBox.shrink();
        final colors = Theme.of(context).colorScheme;
        return Container(
          key: const Key('setup_saved_room'),
          margin: EdgeInsets.only(top: 4.h),
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: colors.primaryContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(AppDimens.radiusSmall),
          ),
          child: Row(
            children: [
              Icon(
                Icons.inventory_2_outlined,
                size: 16.w,
                color: colors.primary,
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  'setup_saved_room'.tr(
                    args: {'count': '${profile.items.length}'},
                  ),
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: colors.onPrimaryContainer),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
