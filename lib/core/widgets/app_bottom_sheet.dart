import 'package:flutter/material.dart';

/// Every bottom sheet in the app. Tall sheets must never trap the user:
/// the sheet stays inside the safe area, stops at [maxHeightFraction] of
/// the screen (the page behind stays visible — tap it to close) and always
/// has a drag handle. Use this instead of `showModalBottomSheet`.
Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  ShapeBorder? shape,
  bool showDragHandle = true,
  double maxHeightFraction = 0.9,
}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: showDragHandle,
  shape: shape,
  constraints: BoxConstraints(
    maxHeight: MediaQuery.sizeOf(context).height * maxHeightFraction,
  ),
  builder: builder,
);
