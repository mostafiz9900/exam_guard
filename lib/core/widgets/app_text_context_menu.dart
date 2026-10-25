import 'package:flutter/material.dart';

/// Copy / paste / select menu for every text field in the app.
///
/// Flutter's default on iOS is the native `SystemContextMenu`, which asserts
/// ("Attempted to show while another instance was still visible") when the
/// menu is rebuilt within one frame — e.g. an input formatter rewrites a
/// paste, so the old menu hides and a new one shows at once. The
/// Flutter-drawn adaptive toolbar (Cupertino-style on iOS) has no such
/// limit. Pass this as `contextMenuBuilder` to every TextField.
Widget appTextContextMenu(BuildContext context, EditableTextState state) =>
    AdaptiveTextSelectionToolbar.editableText(editableTextState: state);
