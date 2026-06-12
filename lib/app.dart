import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/localization/app_localizations.dart';
import 'core/theme/app_theme.dart';
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
    return MaterialApp(
      title: 'SoViCut',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      localizationsDelegates: _delegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('ru'),
      home: const HomeScreen(),
    );
  }
}
