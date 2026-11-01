import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:exam_guard/core/localization/app_localization.dart';
import 'package:exam_guard/core/navigation/app_navigator.dart';
import 'package:exam_guard/core/theme/app_colors.dart';
import 'package:exam_guard/core/theme/app_dimens.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';
import 'package:exam_guard/core/widgets/app_text_context_menu.dart';
import 'package:exam_guard/features/hall/model/hall_models.dart';
import 'package:exam_guard/features/hall/view_model/hall_view_model.dart';
import 'package:exam_guard/features/node_setup/model/node_setup_protocol.dart';
import 'package:exam_guard/features/node_setup/view_model/node_setup_view_model.dart';
import 'package:exam_guard/features/session/view_model/session_view_model.dart';

/// "Add a sensor node": power it on → find it over Bluetooth → pick the
/// hotspot → the node tests it live → done, joining the hall by itself.
class NodeSetupScreen extends ConsumerWidget {
  const NodeSetupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(nodeSetupViewModelProvider);
    final body = switch (state.step) {
      NodeSetupStep.prepare => _PrepareStep(state: state),
      NodeSetupStep.search => _SearchStep(state: state),
      NodeSetupStep.wifi => _WifiStep(state: state),
      NodeSetupStep.applying => _ApplyingStep(state: state),
      NodeSetupStep.done => _DoneStep(state: state),
    };
    return Scaffold(
      appBar: AppBar(title: Text('node_add_title'.tr())),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              children: [
                _StepBar(step: state.step),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 220),
                    child: KeyedSubtree(key: ValueKey(state.step), child: body),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Step bar ──────────────────────────────────────────────────────────────

class _StepBar extends StatelessWidget {
  const _StepBar({required this.step});

  final NodeSetupStep step;

  static const _labels = [
    'node_step_power',
    'node_step_find',
    'node_step_wifi',
    'node_step_done',
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final current = switch (step) {
      NodeSetupStep.prepare => 0,
      NodeSetupStep.search => 1,
      NodeSetupStep.wifi || NodeSetupStep.applying => 2,
      NodeSetupStep.done => 3,
    };
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppDimens.spacingMedium,
        AppDimens.spacingSmall,
        AppDimens.spacingMedium,
        AppDimens.spacingExtraSmall,
      ),
      child: Row(
        children: [
          for (var i = 0; i < _labels.length; i++)
            Expanded(
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 4.h,
                    margin: EdgeInsets.symmetric(horizontal: 3.w),
                    decoration: BoxDecoration(
                      color: i <= current
                          ? colors.primary
                          : colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    _labels[i].tr(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelSmall?.copyWith(
                      color: i == current
                          ? colors.primary
                          : colors.onSurfaceVariant,
                      fontWeight: i == current ? FontWeight.bold : null,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── Shared pieces ─────────────────────────────────────────────────────────

class _StepScroll extends StatelessWidget {
  const _StepScroll({required this.children, this.bottom});

  final List<Widget> children;

  /// Pinned under the scrolling content (main action).
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.all(AppDimens.spacingMedium),
            children: children,
          ),
        ),
        if (bottom != null)
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppDimens.spacingMedium,
              0,
              AppDimens.spacingMedium,
              AppDimens.spacingMedium,
            ),
            child: bottom,
          ),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.icon,
    required this.title,
    required this.text,
    this.color,
    this.busy = false,
  });

  final IconData icon;
  final String title;
  final String text;
  final Color? color;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final c = color ?? colors.primary;
    return Column(
      children: [
        SizedBox(height: AppDimens.spacingSmall),
        SizedBox(
          width: 88.w,
          height: 88.w,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (busy)
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: c.withValues(alpha: 0.6),
                  ),
                ),
              Container(
                width: 72.w,
                height: 72.w,
                decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 36.w, color: c),
              ),
            ],
          ),
        ),
        SizedBox(height: AppDimens.spacingSmall),
        Text(
          title,
          textAlign: TextAlign.center,
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        SizedBox(height: 4.h),
        Text(
          text,
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        SizedBox(height: AppDimens.spacingMedium),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    super.key,
    required this.text,
    this.title,
    this.icon = Icons.error_outline_rounded,
    this.color,
  });

  final String? title;
  final String text;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final c = color ?? colors.error;
    return Container(
      margin: EdgeInsets.only(bottom: AppDimens.spacingSmall),
      padding: EdgeInsets.all(AppDimens.spacingSmall),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
        border: Border.all(color: c.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: c, size: 20.w),
          SizedBox(width: AppDimens.spacingSmall),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  Text(
                    title!,
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: c,
                    ),
                  ),
                Text(text, style: textTheme.bodySmall?.copyWith(height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Check extends StatelessWidget {
  const _Check({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: AppDimens.spacingSmall),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20.w, color: colors.primary),
          SizedBox(width: AppDimens.spacingSmall),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

ButtonStyle _bigButton() => FilledButton.styleFrom(
  minimumSize: Size.fromHeight(AppDimens.buttonHeight),
);

// ── 1. Power on ───────────────────────────────────────────────────────────

class _PrepareStep extends ConsumerWidget {
  const _PrepareStep({required this.state});

  final NodeSetupState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _StepScroll(
      bottom: FilledButton.icon(
        key: const Key('node_find_button'),
        style: _bigButton(),
        onPressed: () =>
            ref.read(nodeSetupViewModelProvider.notifier).startSearch(),
        icon: const Icon(Icons.bluetooth_searching_rounded),
        label: Text('node_find'.tr()),
      ),
      children: [
        _Hero(
          icon: Icons.power_rounded,
          title: 'node_prepare_title'.tr(),
          text: 'node_prepare_text'.tr(),
        ),
        if (state.errorKey != null) _Notice(text: state.errorKey!.tr()),
        _Check(icon: Icons.power_outlined, text: 'node_prepare_power'.tr()),
        _Check(icon: Icons.touch_app_outlined, text: 'node_prepare_mode'.tr()),
        _Check(
          icon: Icons.wifi_tethering_rounded,
          text: 'node_prepare_hotspot'.tr(),
        ),
        _Check(icon: Icons.near_me_outlined, text: 'node_prepare_near'.tr()),
      ],
    );
  }
}

// ── 2. Find ───────────────────────────────────────────────────────────────

class _SearchStep extends ConsumerWidget {
  const _SearchStep({required this.state});

  final NodeSetupState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.read(nodeSetupViewModelProvider.notifier);
    final colors = Theme.of(context).colorScheme;
    final found = state.candidates;
    return _StepScroll(
      bottom: OutlinedButton(
        style: OutlinedButton.styleFrom(
          minimumSize: Size.fromHeight(AppDimens.buttonHeight),
        ),
        onPressed: vm.addAnother,
        child: Text('node_back'.tr()),
      ),
      children: [
        _Hero(
          icon: Icons.bluetooth_searching_rounded,
          title: 'node_search_title'.tr(),
          text: found.isEmpty
              ? 'node_search_text'.tr()
              : 'node_search_pick'.tr(),
          busy: found.isEmpty && !state.bluetoothOff,
        ),
        if (state.bluetoothOff)
          _Notice(
            icon: Icons.bluetooth_disabled_rounded,
            text: 'node_bt_off'.tr(),
          ),
        if (state.errorKey != null) _Notice(text: state.errorKey!.tr()),
        for (final (i, c) in found.indexed)
          Card(
            margin: EdgeInsets.only(bottom: AppDimens.spacingSmall),
            child: ListTile(
              key: Key('node_candidate_${c.deviceId}'),
              enabled: !state.isConnecting,
              onTap: () => vm.select(c),
              leading: CircleAvatar(
                backgroundColor: colors.primaryContainer,
                child: Icon(
                  Icons.sensors_rounded,
                  color: colors.onPrimaryContainer,
                ),
              ),
              title: Text(
                'node_candidate'.tr(args: {'code': c.code}),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                [
                  _signalWord(c.rssi).tr(),
                  if (i == 0 && found.length > 1) 'node_closest'.tr(),
                ].join(' · '),
              ),
              trailing: state.connectingId == c.deviceId
                  ? SizedBox(
                      width: 22.w,
                      height: 22.w,
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.chevron_right_rounded),
            ),
          ),
        if (found.isEmpty) ...[
          SizedBox(height: AppDimens.spacingSmall),
          _Notice(
            icon: Icons.tips_and_updates_outlined,
            color: colors.primary,
            title: 'node_search_tips_title'.tr(),
            text: 'node_search_tips'.tr(),
          ),
        ],
      ],
    );
  }
}

String _signalWord(int rssi) => rssi >= -60
    ? 'node_signal_close'
    : rssi >= -75
    ? 'node_signal_near'
    : 'node_signal_far';

// ── 3. Wi-Fi ──────────────────────────────────────────────────────────────

class _WifiStep extends HookConsumerWidget {
  const _WifiStep({required this.state});

  final NodeSetupState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.read(nodeSetupViewModelProvider.notifier);
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final info = state.info;

    final draft = state.draft;
    final seen = {for (final n in state.networks) n.ssid};
    final selected = useState<String?>(
      state.suggestedSsid ??
          (state.networks.isNotEmpty ? state.networks.first.ssid : null),
    );
    final manual = useState(
      state.networks.isEmpty ||
          (draft != null && (draft.isManual || !seen.contains(draft.ssid))),
    );
    final ssidCtl = useTextEditingController(
      text: manual.value ? (draft?.ssid ?? '') : '',
    );
    final passCtl = useTextEditingController(text: draft?.password ?? '');
    final nameCtl = useTextEditingController(text: draft?.name ?? '');
    final hubCtl = useTextEditingController(text: draft?.hub ?? '');
    final obscure = useState(true);

    final ssid = manual.value ? ssidCtl.text : (selected.value ?? '');
    final chosen = state.networks.where((n) => n.ssid == ssid);
    final isOpen = !manual.value && chosen.isNotEmpty && chosen.first.isOpen;

    void submit() {
      FocusScope.of(context).unfocus();
      vm.submit(
        ssid: manual.value ? ssidCtl.text : (selected.value ?? ''),
        password: isOpen ? '' : passCtl.text,
        name: nameCtl.text,
        hub: hubCtl.text,
        isManual: manual.value,
      );
    }

    InputDecoration deco(String label, {String? hint, Widget? suffix}) =>
        InputDecoration(
          labelText: label,
          hintText: hint,
          suffixIcon: suffix,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
          ),
        );

    return _StepScroll(
      bottom: FilledButton.icon(
        key: const Key('node_connect_button'),
        style: _bigButton(),
        onPressed: submit,
        icon: const Icon(Icons.link_rounded),
        label: Text('node_connect'.tr()),
      ),
      children: [
        if (info != null)
          Container(
            padding: EdgeInsets.all(AppDimens.spacingSmall),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.bluetooth_connected_rounded,
                  color: AppColors.success,
                ),
                SizedBox(width: AppDimens.spacingSmall),
                Expanded(
                  child: Text(
                    'node_connected_to'.tr(
                      args: {'name': info.name, 'fw': info.firmware},
                    ),
                    style: textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        SizedBox(height: AppDimens.spacingMedium),
        Row(
          children: [
            Expanded(
              child: Text(
                'node_wifi_title'.tr(),
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            IconButton(
              tooltip: 'node_wifi_rescan'.tr(),
              onPressed: state.isRescanning ? null : vm.rescanNetworks,
              icon: state.isRescanning
                  ? SizedBox(
                      width: 18.w,
                      height: 18.w,
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        Text(
          'node_wifi_text'.tr(),
          style: textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
        ),
        SizedBox(height: AppDimens.spacingSmall),
        Wrap(
          spacing: 8.w,
          runSpacing: 8.h,
          children: [
            for (final n in state.networks.take(8))
              ChoiceChip(
                key: Key('node_net_${n.ssid}'),
                selected: !manual.value && selected.value == n.ssid,
                onSelected: (_) {
                  manual.value = false;
                  selected.value = n.ssid;
                  vm.clearError();
                },
                avatar: Icon(
                  n.isOpen ? Icons.wifi_rounded : Icons.wifi_password_rounded,
                  size: 18.w,
                ),
                label: Text(n.ssid),
              ),
            ChoiceChip(
              key: const Key('node_net_other'),
              selected: manual.value,
              onSelected: (_) {
                manual.value = true;
                vm.clearError();
              },
              avatar: Icon(Icons.edit_rounded, size: 18.w),
              label: Text('node_wifi_other'.tr()),
            ),
          ],
        ),
        SizedBox(height: AppDimens.spacingMedium),
        if (manual.value) ...[
          TextField(
            key: const Key('node_ssid_field'),
            controller: ssidCtl,
            contextMenuBuilder: appTextContextMenu,
            textInputAction: TextInputAction.next,
            onChanged: (_) => vm.clearError(),
            decoration: deco('node_wifi_ssid'.tr()),
          ),
          SizedBox(height: AppDimens.spacingSmall),
        ],
        if (!isOpen) ...[
          TextField(
            key: const Key('node_password_field'),
            controller: passCtl,
            contextMenuBuilder: appTextContextMenu,
            obscureText: obscure.value,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.next,
            onChanged: (_) => vm.clearError(),
            decoration: deco(
              'node_wifi_password'.tr(),
              suffix: IconButton(
                tooltip: (obscure.value ? 'node_show' : 'node_hide').tr(),
                onPressed: () => obscure.value = !obscure.value,
                icon: Icon(
                  obscure.value
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_rounded,
                ),
              ),
            ),
          ),
          SizedBox(height: AppDimens.spacingSmall),
        ],
        if (state.errorKey != null)
          _Notice(
            text: state.errorKey!.tr(
              args: {'min': '${NodeSetupViewModel.minPasswordLength}'},
            ),
          ),
        TextField(
          key: const Key('node_name_field'),
          controller: nameCtl,
          contextMenuBuilder: appTextContextMenu,
          textInputAction: TextInputAction.done,
          maxLength: 24,
          decoration: deco('node_name'.tr(), hint: 'node_name_hint'.tr()),
        ),
        _Notice(
          icon: Icons.key_rounded,
          color: colors.primary,
          text: 'node_key_auto'.tr(),
        ),
        _Notice(
          icon: Icons.network_check_rounded,
          color: Colors.orange.shade700,
          text: 'node_wifi_24ghz'.tr(),
        ),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text('node_advanced'.tr(), style: textTheme.bodyMedium),
            children: [
              TextField(
                key: const Key('node_hub_field'),
                controller: hubCtl,
                contextMenuBuilder: appTextContextMenu,
                keyboardType: TextInputType.url,
                decoration: deco('node_hub'.tr(), hint: '192.168.1.20'),
              ),
              SizedBox(height: 4.h),
              Text(
                'node_hub_hint'.tr(),
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

// ── Applying ──────────────────────────────────────────────────────────────

enum _Row { waiting, active, done, warning, failed }

class _ApplyingStep extends ConsumerWidget {
  const _ApplyingStep({required this.state});

  final NodeSetupState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.read(nodeSetupViewModelProvider.notifier);
    final p = state.progress;
    final failure = state.failure;
    final wifiFailed = failure != null;
    final wifiOk = p.contains(NodeSetupStatus.wifiOk);
    final hostKnown = state.hostReachable != null;
    final saved = p.contains(NodeSetupStatus.saved);

    final send = p.isEmpty && !wifiFailed ? _Row.active : _Row.done;
    final wifi = wifiFailed
        ? _Row.failed
        : wifiOk
        ? _Row.done
        : p.isEmpty
        ? _Row.waiting
        : _Row.active;
    final host = !wifiOk
        ? _Row.waiting
        : !hostKnown
        ? _Row.active
        : state.hostReachable!
        ? _Row.done
        : _Row.warning;
    final save = saved
        ? _Row.done
        : hostKnown
        ? _Row.active
        : _Row.waiting;

    final ssid = state.failedSsid ?? '';
    final failText = switch (failure) {
      NodeSetupStatus.noNetwork => 'node_fail_no_network',
      NodeSetupStatus.badPassword => 'node_fail_password',
      NodeSetupStatus.badRequest => 'node_fail_request',
      _ => state.errorKey ?? 'node_fail_wifi',
    }.tr(args: {'ssid': ssid});

    return _StepScroll(
      bottom: wifiFailed
          ? FilledButton.icon(
              key: const Key('node_retry_button'),
              style: _bigButton(),
              onPressed: vm.editWifi,
              icon: const Icon(Icons.edit_rounded),
              label: Text('node_fix_wifi'.tr()),
            )
          : null,
      children: [
        _Hero(
          icon: wifiFailed ? Icons.wifi_off_rounded : Icons.settings_ethernet,
          color: wifiFailed ? Theme.of(context).colorScheme.error : null,
          title: (wifiFailed ? 'node_apply_failed' : 'node_apply_title').tr(),
          text: wifiFailed ? failText : 'node_apply_text'.tr(),
          busy: !wifiFailed,
        ),
        _ProgressRow(state: send, text: 'node_progress_send'.tr()),
        _ProgressRow(state: wifi, text: 'node_progress_wifi'.tr()),
        _ProgressRow(
          state: host,
          text: host == _Row.warning
              ? 'node_progress_host_later'.tr()
              : 'node_progress_host'.tr(),
        ),
        _ProgressRow(state: save, text: 'node_progress_save'.tr()),
      ],
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({required this.state, required this.text});

  final _Row state;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final icon = switch (state) {
      _Row.waiting => Icon(
        Icons.radio_button_unchecked_rounded,
        color: colors.outline,
      ),
      _Row.active => SizedBox(
        width: 22.w,
        height: 22.w,
        child: const Padding(
          padding: EdgeInsets.all(2),
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      ),
      _Row.done => const Icon(
        Icons.check_circle_rounded,
        color: AppColors.success,
      ),
      _Row.warning => Icon(Icons.info_rounded, color: Colors.orange.shade700),
      _Row.failed => Icon(Icons.cancel_rounded, color: colors.error),
    };
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Row(
        children: [
          SizedBox(
            width: 24.w,
            child: Center(child: icon),
          ),
          SizedBox(width: AppDimens.spacingSmall),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: state == _Row.waiting ? colors.onSurfaceVariant : null,
                fontWeight: state == _Row.active ? FontWeight.w600 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 4. Done ───────────────────────────────────────────────────────────────

class _DoneStep extends ConsumerWidget {
  const _DoneStep({required this.state});

  final NodeSetupState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.read(nodeSetupViewModelProvider.notifier);
    final hall = ref.watch(hallViewModelProvider);
    final examRunning = ref.watch(
      sessionViewModelProvider.select((s) => s?.isActive ?? false),
    );
    final colors = Theme.of(context).colorScheme;
    final id = state.info?.id;
    final live = hall.members.any(
      (m) => m.kind == HallMemberKind.node && m.id == id,
    );
    final hosting = hall.role == HallRole.host && hall.status.isLive;

    final Widget status = live
        ? _Notice(
            key: const Key('node_done_live'),
            icon: Icons.sensors_rounded,
            color: AppColors.success,
            title: 'node_done_live_title'.tr(),
            text: 'node_done_live_text'.tr(),
          )
        : hosting
        ? Row(
            key: const Key('node_done_waiting'),
            children: [
              SizedBox(
                width: 18.w,
                height: 18.w,
                child: const CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: AppDimens.spacingSmall),
              Expanded(child: Text('node_done_waiting'.tr())),
            ],
          )
        : _Notice(
            key: const Key('node_done_host'),
            icon: Icons.hub_outlined,
            color: colors.primary,
            text: (examRunning ? 'node_done_host' : 'node_done_later').tr(),
          );

    return _StepScroll(
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton(
            key: const Key('node_done_button'),
            style: _bigButton(),
            onPressed: () => context.popBack(),
            child: Text('node_done'.tr()),
          ),
          SizedBox(height: AppDimens.spacingExtraSmall),
          OutlinedButton.icon(
            key: const Key('node_add_another'),
            style: OutlinedButton.styleFrom(
              minimumSize: Size.fromHeight(AppDimens.buttonHeight),
            ),
            onPressed: vm.addAnother,
            icon: const Icon(Icons.add_rounded),
            label: Text('node_add_another'.tr()),
          ),
        ],
      ),
      children: [
        _Hero(
          icon: Icons.check_rounded,
          color: AppColors.success,
          title: 'node_done_title'.tr(),
          text: 'node_done_text'.tr(args: {'name': state.savedName ?? ''}),
        ),
        status,
        if (!live && !hosting && examRunning) ...[
          SizedBox(height: AppDimens.spacingSmall),
          FilledButton.tonalIcon(
            key: const Key('node_done_host_button'),
            onPressed: hall.status == HallLinkStatus.starting
                ? null
                : () => ref.read(hallViewModelProvider.notifier).host(),
            icon: const Icon(Icons.hub_rounded),
            label: Text('hall_host'.tr()),
          ),
        ],
      ],
    );
  }
}
