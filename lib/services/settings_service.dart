import 'dart:convert';
import 'dart:io';

class AppSettings {
  final String language; // 'en', 'ru'
  final String themeMode; // 'dark', 'light', 'twilight'
  final bool fastExport;
  final bool saveExportMode;

  const AppSettings({
    this.language = 'ru',
    this.themeMode = 'dark',
    this.fastExport = true,
    this.saveExportMode = true,
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        language: json['language'] as String? ?? 'ru',
        themeMode: json['themeMode'] as String? ?? 'dark',
        fastExport: json['fastExport'] as bool? ?? true,
        saveExportMode: json['saveExportMode'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'language': language,
        'themeMode': themeMode,
        'fastExport': fastExport,
        'saveExportMode': saveExportMode,
      };

  /// Returns export mode with saveExportMode respected:
  /// if saveExportMode is false, always return true (fast).
  bool get effectiveFastExport =>
      saveExportMode ? fastExport : true;
}

class SettingsService {
  static String get _dir {
    final appData = Platform.environment['APPDATA'] ??
        '${Platform.environment['USERPROFILE']}\\AppData\\Roaming';
    return '$appData\\SoViCut';
  }

  static String get _file => '$_dir\\settings.json';

  static Future<AppSettings> load() async {
    try {
      final f = File(_file);
      if (!await f.exists()) return const AppSettings();
      return AppSettings.fromJson(
        jsonDecode(await f.readAsString()) as Map<String, dynamic>,
      );
    } catch (_) {
      return const AppSettings();
    }
  }

  static Future<void> save(AppSettings settings) async {
    final d = Directory(_dir);
    if (!await d.exists()) {
      await d.create(recursive: true);
    }
    await File(_file).writeAsString(jsonEncode(settings.toJson()));
  }
}
