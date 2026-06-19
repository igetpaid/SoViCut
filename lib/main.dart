import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'providers/export_providers.dart';
import 'providers/locale_provider.dart';
import 'providers/theme_provider.dart';
import 'services/settings_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  final settings = await SettingsService.load();

  runApp(
    ProviderScope(
      overrides: [
        localeProvider.overrideWith(
          (ref) => LocaleNotifier(Locale(settings.language)),
        ),
        themeModeProvider.overrideWith(
          (ref) => ThemeModeNotifier(
            switch (settings.themeMode) {
              'light' => AppThemeMode.light,
              'twilight' => AppThemeMode.twilight,
              _ => AppThemeMode.dark,
            },
          ),
        ),
        fastExportProvider.overrideWith(
          (ref) => settings.effectiveFastExport,
        ),
        saveExportModeProvider.overrideWith(
          (ref) => settings.saveExportMode,
        ),
        showScrubThumbnailsProvider.overrideWith(
          (ref) => settings.showScrubThumbnails,
        ),
      ],
      child: const SoViCutApp(),
    ),
  );
}
