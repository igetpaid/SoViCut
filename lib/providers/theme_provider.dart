import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_colors.dart';

enum AppThemeMode { light, dark, twilight }

class ThemeModeNotifier extends StateNotifier<AppThemeMode> {
  ThemeModeNotifier() : super(AppThemeMode.dark) {
    _apply(state);
  }

  void setTheme(AppThemeMode mode) {
    state = mode;
    _apply(mode);
  }

  void _apply(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        AppColors.applyLight();
      case AppThemeMode.dark:
        AppColors.applyDark();
      case AppThemeMode.twilight:
        AppColors.applyTwilight();
    }
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, AppThemeMode>((ref) {
  return ThemeModeNotifier();
});
