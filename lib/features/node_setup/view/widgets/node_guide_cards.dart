import 'package:flutter/material.dart';

import 'package:exam_guard/core/localization/app_localization.dart';
import 'package:exam_guard/core/theme/app_dimens.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';

/// Expandable help card used by the sensor node screens.
class NodeGuideCard extends StatelessWidget {
  const NodeGuideCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.children,
    this.initiallyExpanded = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> children;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
    );
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: colors.surfaceContainerLow,
      shape: shape.copyWith(side: BorderSide(color: colors.outlineVariant)),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        shape: shape,
        collapsedShape: shape,
        leading: CircleAvatar(
          radius: 18.r,
          backgroundColor: colors.primaryContainer,
          child: Icon(icon, size: 18.w, color: colors.onPrimaryContainer),
        ),
        title: Text(
          title,
          style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          subtitle,
          style: textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
        ),
        childrenPadding: EdgeInsets.fromLTRB(
          AppDimens.spacingMedium,
          0,
          AppDimens.spacingMedium,
          AppDimens.spacingMedium,
        ),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

/// One line with an icon: a thing to buy, a tip, an LED pattern.
class NodeGuideRow extends StatelessWidget {
  const NodeGuideRow({
    super.key,
    required this.icon,
    required this.title,
    this.text,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final String? text;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(top: AppDimens.spacingSmall),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20.w, color: iconColor ?? colors.primary),
          SizedBox(width: AppDimens.spacingSmall),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (text != null)
                  Text(
                    text!,
                    style: textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.35,
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

/// Numbered step.
class NodeGuideStep extends StatelessWidget {
  const NodeGuideStep({super.key, required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(top: AppDimens.spacingSmall),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 11.r,
            backgroundColor: colors.primary,
            child: Text(
              '$number',
              style: textTheme.labelSmall?.copyWith(
                color: colors.onPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(width: AppDimens.spacingSmall),
          Expanded(
            child: Text(
              text,
              style: textTheme.bodySmall?.copyWith(height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

/// What to buy for one node.
class NodeShoppingCard extends StatelessWidget {
  const NodeShoppingCard({super.key, this.initiallyExpanded = false});

  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return NodeGuideCard(
      key: const Key('node_guide_buy'),
      icon: Icons.shopping_bag_outlined,
      title: 'node_buy_title'.tr(),
      subtitle: 'node_buy_subtitle'.tr(),
      initiallyExpanded: initiallyExpanded,
      children: [
        NodeGuideRow(
          icon: Icons.memory_rounded,
          title: 'node_buy_board'.tr(),
          text: 'node_buy_board_text'.tr(),
        ),
        NodeGuideRow(
          icon: Icons.cable_rounded,
          title: 'node_buy_cable'.tr(),
          text: 'node_buy_cable_text'.tr(),
        ),
        NodeGuideRow(
          icon: Icons.battery_charging_full_rounded,
          title: 'node_buy_power'.tr(),
          text: 'node_buy_power_text'.tr(),
        ),
        NodeGuideRow(
          icon: Icons.inventory_2_outlined,
          title: 'node_buy_case'.tr(),
          text: 'node_buy_case_text'.tr(),
          iconColor: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ],
    );
  }
}

/// Installing the firmware, once per board.
class NodeFirmwareCard extends StatelessWidget {
  const NodeFirmwareCard({super.key});

  @override
  Widget build(BuildContext context) {
    return NodeGuideCard(
      key: const Key('node_guide_flash'),
      icon: Icons.developer_board_rounded,
      title: 'node_flash_title'.tr(),
      subtitle: 'node_flash_subtitle'.tr(),
      children: [
        for (final (i, key) in const [
          'node_flash_step1',
          'node_flash_step2',
          'node_flash_step3',
          'node_flash_step4',
        ].indexed)
          NodeGuideStep(number: i + 1, text: key.tr()),
      ],
    );
  }
}

/// What the light on the node means.
class NodeLedCard extends StatelessWidget {
  const NodeLedCard({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return NodeGuideCard(
      key: const Key('node_guide_led'),
      icon: Icons.lightbulb_outline_rounded,
      title: 'node_led_title'.tr(),
      subtitle: 'node_led_subtitle'.tr(),
      children: [
        NodeGuideRow(
          icon: Icons.circle,
          iconColor: Colors.green,
          title: 'node_led_solid'.tr(),
          text: 'node_led_solid_text'.tr(),
        ),
        NodeGuideRow(
          icon: Icons.blur_on_rounded,
          iconColor: Colors.orange,
          title: 'node_led_fast'.tr(),
          text: 'node_led_fast_text'.tr(),
        ),
        NodeGuideRow(
          icon: Icons.blur_circular_rounded,
          iconColor: colors.error,
          title: 'node_led_slow'.tr(),
          text: 'node_led_slow_text'.tr(),
        ),
        NodeGuideRow(
          icon: Icons.settings_bluetooth_rounded,
          iconColor: colors.primary,
          title: 'node_led_double'.tr(),
          text: 'node_led_double_text'.tr(),
        ),
      ],
    );
  }
}

/// Where to put nodes in the hall.
class NodePlacementCard extends StatelessWidget {
  const NodePlacementCard({super.key});

  @override
  Widget build(BuildContext context) {
    return NodeGuideCard(
      key: const Key('node_guide_place'),
      icon: Icons.place_outlined,
      title: 'node_place_title'.tr(),
      subtitle: 'node_place_subtitle'.tr(),
      children: [
        NodeGuideRow(
          icon: Icons.event_seat_outlined,
          title: 'node_place_rows'.tr(),
          text: 'node_place_rows_text'.tr(),
        ),
        NodeGuideRow(
          icon: Icons.height_rounded,
          title: 'node_place_height'.tr(),
          text: 'node_place_height_text'.tr(),
        ),
        NodeGuideRow(
          icon: Icons.radar_rounded,
          title: 'node_place_range'.tr(),
          text: 'node_place_range_text'.tr(),
        ),
      ],
    );
  }
}
