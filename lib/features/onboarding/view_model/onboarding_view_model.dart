import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/navigation/app_routes.dart';
import 'package:exam_guard/core/services/logger/app_logger.dart';
import 'package:exam_guard/core/services/permission/i_permission_service.dart';
import 'package:exam_guard/core/services/storage/i_local_storage.dart';
import 'package:exam_guard/features/onboarding/repository/onboarding_repository.dart';

@immutable
class OnboardingState {
  const OnboardingState({
    this.page = 0,
    this.permission,
    this.isRequesting = false,
  });

  final int page;

  /// Result of the Bluetooth/Location request, null until asked.
  final AppPermissionStatus? permission;
  final bool isRequesting;

  OnboardingState copyWith({
    int? page,
    AppPermissionStatus? permission,
    bool? isRequesting,
  }) => OnboardingState(
    page: page ?? this.page,
    permission: permission ?? this.permission,
    isRequesting: isRequesting ?? this.isRequesting,
  );
}

/// The first-run introduction: a few pages, then the scan permissions.
class OnboardingViewModel extends Notifier<OnboardingState> {
  /// Welcome, find, detect, team, permissions.
  static const int pageCount = 5;

  late OnboardingRepository _repo;
  late AppLogger _logger;

  @override
  OnboardingState build() {
    _repo = ref.watch(onboardingRepositoryProvider);
    _logger = ref.watch(appLoggerProvider);
    return const OnboardingState();
  }

  void setPage(int page) =>
      state = state.copyWith(page: page.clamp(0, pageCount - 1));

  bool get isLastPage => state.page == pageCount - 1;

  Future<void> requestPermissions() async {
    if (state.isRequesting) return;
    state = state.copyWith(isRequesting: true);
    try {
      final status = await _repo.requestScanPermissions();
      if (ref.mounted) {
        state = state.copyWith(permission: status, isRequesting: false);
      }
    } catch (e, st) {
      _logger.warning('Permission request failed', e, st);
      if (ref.mounted) {
        state = state.copyWith(
          permission: AppPermissionStatus.denied,
          isRequesting: false,
        );
      }
    }
  }

  Future<void> openSettings() => _repo.openSettings();

  /// Never shown again after this. A failed save only means it shows once
  /// more next launch.
  Future<void> finish() async {
    try {
      await _repo.markDone();
    } on StorageException catch (e, st) {
      _logger.warning('Onboarding flag not saved', e, st);
    }
  }
}

final onboardingViewModelProvider =
    NotifierProvider.autoDispose<OnboardingViewModel, OnboardingState>(
      OnboardingViewModel.new,
    );

/// Where the splash screen goes: the introduction on first run, otherwise
/// exam setup (which the router turns into the dashboard while an exam
/// runs).
final launchRouteProvider = Provider.autoDispose<String>(
  (ref) => ref.watch(onboardingRepositoryProvider).isDone
      ? AppRoute.sessionSetup
      : AppRoute.onboarding,
);
