import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/localization/app_localizations.dart';
import 'core/theme/app_theme.dart';
import 'providers/theme_provider.dart';
import 'providers/locale_provider.dart';
import 'home_screen.dart';

class SoViCutApp extends ConsumerWidget {
  const SoViCutApp({super.key});

  static const List<LocalizationsDelegate<dynamic>> _delegates = [
    AppLocalizationsDelegate(),
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);

    return MaterialApp(
      title: 'SoViCut',
      debugShowCheckedModeBanner: false,
      themeMode: mode == AppThemeMode.light ? ThemeMode.light : ThemeMode.dark,
      theme: AppTheme.light,
      darkTheme: mode == AppThemeMode.twilight ? AppTheme.twilight : AppTheme.dark,
      localizationsDelegates: _delegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      home: const HomeScreen(),
    );
  }
}
