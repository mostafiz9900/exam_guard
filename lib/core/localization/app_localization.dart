import 'package:easy_localization/easy_localization.dart' as easy;
import 'package:flutter/widgets.dart';

/// Translations and locale switching. Wraps `easy_localization` so features
/// never import it.
class AppLocalization extends StatelessWidget {
  const AppLocalization({super.key, required this.child});

  static const Locale english = Locale('en');
  static const Locale bangla = Locale('bn');
  static const Locale arabic = Locale('ar');
  static const List<Locale> supportedLocales = [english, bangla, arabic];

  final Widget child;

  /// Loads the saved locale. Call once before `runApp`.
  static Future<void> init() => easy.EasyLocalization.ensureInitialized();

  @override
  Widget build(BuildContext context) {
    return easy.EasyLocalization(
      supportedLocales: supportedLocales,
      path: 'assets/translations',
      fallbackLocale: english,
      child: child,
    );
  }
}

extension AppTranslateExtension on String {
  /// The translation for this key in the current locale. Placeholders are
  /// written `{name}` in the JSON files and filled from [args].
  String tr({Map<String, String>? args}) => easy.tr(this, namedArgs: args);
}

extension AppLocaleContext on BuildContext {
  Locale get appLocale =>
      easy.BuildContextEasyLocalizationExtension(this).locale;

  List<Locale> get appSupportedLocales =>
      easy.BuildContextEasyLocalizationExtension(this).supportedLocales;

  List<LocalizationsDelegate<dynamic>> get appLocalizationDelegates =>
      easy.BuildContextEasyLocalizationExtension(this).localizationDelegates;

  Future<void> setAppLocale(Locale locale) =>
      easy.BuildContextEasyLocalizationExtension(this).setLocale(locale);
}
