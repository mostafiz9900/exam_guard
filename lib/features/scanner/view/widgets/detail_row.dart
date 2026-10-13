import 'package:exam_guard/core/utils/size_extensions.dart';
import 'package:flutter/material.dart';

class DetailRow extends StatelessWidget {
  const DetailRow({super.key, required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: Colors.grey),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                fontFamily: label.contains('MAC') ? 'monospace' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Interactive Multi-Target Radar Chart Widget with Gesture Detector
