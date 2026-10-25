import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:exam_guard/core/widgets/app_text_context_menu.dart';
import 'package:exam_guard/core/localization/app_localization.dart';
import 'package:exam_guard/core/navigation/app_navigator.dart';
import 'package:exam_guard/core/theme/app_dimens.dart';
import 'package:exam_guard/core/widgets/app_qr_scanner.dart';
import 'package:exam_guard/features/hall/model/hall_models.dart';
import 'package:exam_guard/features/hall/repository/hall_repository.dart';

/// Scans the host's hall QR code and pops with its text. The address and
/// code can also be typed in (no camera, or a damaged screen).
class HallScanScreen extends HookWidget {
  const HallScanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final done = useRef(false);
    final manual = useState(false);

    void finish(String text) {
      if (done.value) return;
      done.value = true;
      context.popBack(text);
    }

    return Scaffold(
      appBar: AppBar(title: Text('hall_scan_title'.tr())),
      body: SafeArea(
        child: manual.value
            ? _ManualEntry(onJoin: finish)
            : Column(
                children: [
                  Expanded(
                    child: AppQrScanner(
                      onScanned: (text) {
                        // Ignore unrelated QR codes; keep scanning.
                        if (HallInvite.parse(text) != null) finish(text);
                      },
                      errorBuilder: (context, reason) => Center(
                        child: Padding(
                          padding: EdgeInsets.all(AppDimens.spacingLarge),
                          child: Text(
                            (reason == 'permission'
                                    ? 'hall_scan_camera_denied'
                                    : 'hall_scan_camera_unavailable')
                                .tr(),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(AppDimens.spacingMedium),
                    child: TextButton.icon(
                      onPressed: () => manual.value = true,
                      icon: const Icon(Icons.keyboard_rounded),
                      label: Text('hall_scan_manual'.tr()),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _ManualEntry extends HookWidget {
  const _ManualEntry({required this.onJoin});

  final ValueChanged<String> onJoin;

  @override
  Widget build(BuildContext context) {
    final address = useTextEditingController();
    final code = useTextEditingController();
    final error = useState(false);

    void join() {
      // "192.168.43.1" or "192.168.43.1:47800"
      final parts = address.text.trim().split(':');
      final port = parts.length > 1
          ? int.tryParse(parts[1])
          : HallRepository.defaultPort;
      final token = code.text.trim().toUpperCase();
      if (parts.first.isEmpty || port == null || token.isEmpty) {
        error.value = true;
        return;
      }
      onJoin(
        HallInvite(
          host: parts.first,
          port: port,
          token: token,
          room: '',
        ).encode(),
      );
    }

    return ListView(
      padding: EdgeInsets.all(AppDimens.spacingMedium),
      children: [
        Text('hall_scan_manual_hint'.tr()),
        SizedBox(height: AppDimens.spacingMedium),
        TextField(
          contextMenuBuilder: appTextContextMenu,
          controller: address,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(
            labelText: 'hall_scan_address'.tr(),
            hintText: '192.168.43.1:47800',
            border: const OutlineInputBorder(),
          ),
        ),
        SizedBox(height: AppDimens.spacingSmall),
        TextField(
          contextMenuBuilder: appTextContextMenu,
          controller: code,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            labelText: 'hall_scan_code'.tr(),
            border: const OutlineInputBorder(),
            errorText: error.value ? 'hall_scan_manual_invalid'.tr() : null,
          ),
          onSubmitted: (_) => join(),
        ),
        SizedBox(height: AppDimens.spacingMedium),
        FilledButton(onPressed: join, child: Text('hall_scan_join'.tr())),
      ],
    );
  }
}
