import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Screen navigation. Wraps `go_router` so features never import it.
/// Route paths live in `AppRoute`.
extension AppNavigator on BuildContext {
  /// Replaces the current stack with [route].
  void goTo(String route, {Object? extra}) =>
      GoRouter.of(this).go(route, extra: extra);

  /// Pushes [route] on top of the current screen.
  Future<T?> pushTo<T extends Object?>(String route, {Object? extra}) =>
      GoRouter.of(this).push<T>(route, extra: extra);

  /// Closes the current screen.
  void popBack<T extends Object?>([T? result]) =>
      GoRouter.of(this).pop<T>(result);

  bool get canPopBack => GoRouter.of(this).canPop();
}
