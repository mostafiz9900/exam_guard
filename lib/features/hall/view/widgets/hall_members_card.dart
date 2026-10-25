import 'package:flutter/material.dart';

import 'package:exam_guard/core/localization/app_localization.dart';
import 'package:exam_guard/core/theme/app_dimens.dart';
import 'package:exam_guard/features/hall/model/hall_models.dart';

/// Everyone in the hall: invigilator phones and sensor nodes.
class HallMembersCard extends StatelessWidget {
  const HallMembersCard({
    super.key,
    required this.members,
    required this.selfId,
  });

  final List<HallMember> members;
  final String selfId;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: AppDimens.spacingSmall),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppDimens.spacingMedium,
              ),
              child: Text(
                'hall_members_title'.tr(args: {'count': '${members.length}'}),
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            for (final m in members)
              ListTile(
                dense: true,
                leading: Icon(
                  m.kind == HallMemberKind.node
                      ? Icons.sensors_rounded
                      : Icons.smartphone_rounded,
                  color: m.kind == HallMemberKind.node
                      ? colors.tertiary
                      : colors.primary,
                ),
                title: Text(
                  m.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  [
                    (m.kind == HallMemberKind.node
                            ? 'hall_member_node'
                            : 'hall_member_phone')
                        .tr(),
                    if (m.isHost) 'hall_member_host'.tr(),
                    if (m.id == selfId) 'hall_member_you'.tr(),
                  ].join(' · '),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
