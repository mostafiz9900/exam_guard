import 'package:exam_guard/core/utils/size_extensions.dart';
import 'package:flutter/material.dart';

class MetaInfo extends StatelessWidget {
  const MetaInfo({super.key, required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: Colors.grey),
        ),
        SizedBox(height: 2.h),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
