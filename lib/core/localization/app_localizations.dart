import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class AppLocalizations {
  AppLocalizations._();

  static late Map<String, dynamic> _strings;
  static late Locale _locale;

  static const List<Locale> supportedLocales = [
    Locale('ru'),
    Locale('en'),
  ];

  static Locale get locale => _locale;

  static Future<void> load(Locale locale) async {
    _locale = locale;
    final code = locale.languageCode;
    final jsonStr = await rootBundle.loadString('assets/locales/$code.json');
    _strings = jsonDecode(jsonStr) as Map<String, dynamic>;
  }

  static String t(String key, [Map<String, dynamic>? params]) {
    final keys = key.split('.');
    dynamic value = _strings;
    for (final k in keys) {
      if (value is Map) {
        value = value[k];
      } else {
        return key;
      }
    }
    if (value is String) {
      if (params != null) {
        for (final entry in params.entries) {
          value = value.replaceAll('{${entry.key}}', entry.value.toString());
        }
      }
      return value;
    }
    return key;
  }

  static String get appName => t('appName');
  static String get appSubtitle => t('appSubtitle');
}

class AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      AppLocalizations.supportedLocales.any((l) => l.languageCode == locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    await AppLocalizations.load(locale);
    return AppLocalizations._();
  }

  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
}
