import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    final c = AppColors.darkSet;
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: c.bgDark,
      primaryColor: c.accent,
      colorScheme: ColorScheme.dark(
        primary: c.accent,
        secondary: c.accentLight,
        surface: c.bgSurface,
        error: c.error,
      ),
      cardTheme: CardThemeData(
        color: c.bgCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: c.border, width: 1),
        ),
      ),
      dividerTheme: DividerThemeData(color: c.border, thickness: 1),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return c.accent;
          return c.border;
        }),
        checkColor: WidgetStateProperty.all(c.bgDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return c.accent;
          return c.textDim;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return c.accent.withValues(alpha: 0.3);
          return c.border;
        }),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: c.accent,
        inactiveTrackColor: c.border,
        thumbColor: c.accent,
        overlayColor: c.accent.withValues(alpha: 0.12),
        trackHeight: 4,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: c.accent,
        unselectedLabelColor: c.textDim,
        indicatorColor: c.accent,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.accent,
          foregroundColor: c.bgDark,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: c.accent),
      ),
      iconTheme: IconThemeData(color: c.textSecondary),
      appBarTheme: AppBarTheme(
        backgroundColor: c.bgSurface,
        foregroundColor: c.textPrimary,
        elevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.bgCard,
        contentTextStyle: TextStyle(color: c.textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.bgSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.bgCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: c.accent),
        ),
        labelStyle: TextStyle(color: c.textDim),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: c.bgCard,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: c.border),
        ),
        textStyle: TextStyle(color: c.textPrimary, fontSize: 12),
      ),
    );
  }

  static ThemeData get light {
    final c = AppColors.lightSet;
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: c.bgDark,
      primaryColor: c.accent,
      colorScheme: ColorScheme.light(
        primary: c.accent,
        secondary: c.accentLight,
        surface: c.bgSurface,
        error: c.error,
      ),
      cardTheme: CardThemeData(
        color: c.bgCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: c.border, width: 1),
        ),
      ),
      dividerTheme: DividerThemeData(color: c.border, thickness: 1),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return c.accent;
          return c.border;
        }),
        checkColor: WidgetStateProperty.all(c.bgSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return c.accent;
          return c.textDim;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return c.accent.withValues(alpha: 0.3);
          return c.border;
        }),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: c.accent,
        inactiveTrackColor: c.border,
        thumbColor: c.accent,
        overlayColor: c.accent.withValues(alpha: 0.12),
        trackHeight: 4,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: c.accent,
        unselectedLabelColor: c.textDim,
        indicatorColor: c.accent,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.accent,
          foregroundColor: c.bgSurface,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: c.accent),
      ),
      iconTheme: IconThemeData(color: c.textSecondary),
      appBarTheme: AppBarTheme(
        backgroundColor: c.bgSurface,
        foregroundColor: c.textPrimary,
        elevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.bgCard,
        contentTextStyle: TextStyle(color: c.textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.bgSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.bgCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: c.accent),
        ),
        labelStyle: TextStyle(color: c.textDim),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: c.bgCard,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: c.border),
        ),
        textStyle: TextStyle(color: c.textPrimary, fontSize: 12),
      ),
    );
  }

  static ThemeData get twilight {
    final c = AppColors.twilightSet;
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: c.bgDark,
      primaryColor: c.accent,
      colorScheme: ColorScheme.dark(
        primary: c.accent,
        secondary: c.accentLight,
        surface: c.bgSurface,
        error: c.error,
      ),
      cardTheme: CardThemeData(
        color: c.bgCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: c.border, width: 1),
        ),
      ),
      dividerTheme: DividerThemeData(color: c.border, thickness: 1),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return c.accent;
          return c.border;
        }),
        checkColor: WidgetStateProperty.all(c.bgDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return c.accent;
          return c.textDim;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return c.accent.withValues(alpha: 0.3);
          return c.border;
        }),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: c.accent,
        inactiveTrackColor: c.border,
        thumbColor: c.accent,
        overlayColor: c.accent.withValues(alpha: 0.12),
        trackHeight: 4,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: c.accent,
        unselectedLabelColor: c.textDim,
        indicatorColor: c.accent,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.accent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: c.accent),
      ),
      iconTheme: IconThemeData(color: c.textSecondary),
      appBarTheme: AppBarTheme(
        backgroundColor: c.bgSurface,
        foregroundColor: c.textPrimary,
        elevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.bgCard,
        contentTextStyle: TextStyle(color: c.textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.bgSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.bgCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: c.accent),
        ),
        labelStyle: TextStyle(color: c.textDim),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: c.bgCard,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: c.border),
        ),
        textStyle: TextStyle(color: c.textPrimary, fontSize: 12),
      ),
    );
  }
}
