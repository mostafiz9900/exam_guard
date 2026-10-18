import 'dart:io' show File;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:exam_guard/core/localization/app_localization.dart';
import 'package:exam_guard/core/utils/size_extensions.dart';

/// Opens [paths] full screen (swipe between, pinch to zoom), starting at
/// [initialIndex]. [caption] is shown under the photos.
Future<void> showPhotoViewer(
  BuildContext context, {
  required List<String> paths,
  int initialIndex = 0,
  String? caption,
}) {
  return showDialog<void>(
    context: context,
    useSafeArea: false,
    builder: (_) => Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: _PhotoViewer(
        paths: paths,
        initialIndex: initialIndex,
        caption: caption,
      ),
    ),
  );
}

class _PhotoViewer extends HookWidget {
  const _PhotoViewer({
    required this.paths,
    required this.initialIndex,
    this.caption,
  });

  final List<String> paths;
  final int initialIndex;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final index = useState(initialIndex);
    final controller = usePageController(initialPage: initialIndex);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          'report_photo_viewer_title'.tr(
            args: {'index': '${index.value + 1}', 'total': '${paths.length}'},
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: controller,
              itemCount: paths.length,
              onPageChanged: (i) => index.value = i,
              itemBuilder: (_, i) => InteractiveViewer(
                maxScale: 5,
                child: Center(
                  child: Image.file(
                    File(paths[i]),
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.broken_image_outlined,
                          color: Colors.white70,
                          size: 48.w,
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          'report_photo_missing'.tr(),
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (caption != null)
            SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.all(12.w),
                child: Text(
                  caption!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
