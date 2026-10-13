import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/services/logger/app_logger.dart';
import 'package:exam_guard/core/services/share/i_share_service.dart';
import 'package:exam_guard/features/report/repository/report_repository.dart';
import 'package:exam_guard/features/session/model/session_model.dart';

class ReportState {
  const ReportState({this.isExporting = false, this.message});

  final bool isExporting;

  /// One-off message for the view to show, e.g. an export error.
  final String? message;
}

class ReportViewModel extends Notifier<ReportState> {
  @override
  ReportState build() => const ReportState();

  Future<void> exportPdf(SessionModel session) async {
    if (state.isExporting) return;
    state = const ReportState(isExporting: true);
    try {
      final outcome = await ref
          .read(reportRepositoryProvider)
          .exportSessionPdf(session);
      if (!ref.mounted) return;
      state = ReportState(
        message: outcome == ShareOutcome.unavailable
            ? 'Sharing is not available on this device'
            : null,
      );
    } catch (e, st) {
      ref.read(appLoggerProvider).error('PDF export failed', e, st);
      if (ref.mounted) {
        state = ReportState(message: 'Could not export report: $e');
      }
    }
  }
}

final reportViewModelProvider =
    NotifierProvider.autoDispose<ReportViewModel, ReportState>(
      ReportViewModel.new,
    );
