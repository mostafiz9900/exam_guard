import 'dart:ui' show Rect;

import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/services/logger/app_logger.dart';
import 'package:exam_guard/core/services/share/i_share_service.dart';
import 'package:exam_guard/features/report/repository/report_repository.dart';
import 'package:exam_guard/features/session/model/session_model.dart';

class ReportState {
  const ReportState({this.isExporting = false, this.messageKey});

  final bool isExporting;

  /// Translation key of a one-off message for the view to show, e.g. an
  /// export error. The view translates it.
  final String? messageKey;
}

class ReportViewModel extends Notifier<ReportState> {
  @override
  ReportState build() => const ReportState();

  /// [origin] anchors the iPad share popover (global rect of the button).
  Future<void> exportPdf(SessionModel session, {Rect? origin}) async {
    if (state.isExporting) return;
    state = const ReportState(isExporting: true);
    try {
      final outcome = await ref
          .read(reportRepositoryProvider)
          .exportSessionPdf(session, origin: origin);
      if (!ref.mounted) return;
      state = ReportState(
        messageKey: outcome == ShareOutcome.unavailable
            ? 'report_share_unavailable'
            : null,
      );
    } catch (e, st) {
      ref.read(appLoggerProvider).error('PDF export failed', e, st);
      if (ref.mounted) {
        state = const ReportState(messageKey: 'report_export_failed');
      }
    }
  }
}

final reportViewModelProvider =
    NotifierProvider.autoDispose<ReportViewModel, ReportState>(
      ReportViewModel.new,
    );
