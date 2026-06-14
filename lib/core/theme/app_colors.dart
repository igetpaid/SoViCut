import 'package:flutter/material.dart';

class AppColorSet {
  final Color accent;
  final Color accentLight;
  final Color accentDark;

  final Color bgDark;
  final Color bgSurface;
  final Color bgCard;
  final Color bgHover;

  final Color textPrimary;
  final Color textSecondary;
  final Color textDim;

  final Color border;
  final Color borderLight;

  final Color success;
  final Color warning;
  final Color error;

  final Color timelineBg;
  final Color timelineClip;
  final Color timelineClipSelected;
  final Color timelineClipDeleted;
  final Color timelineCursor;

  final Color scrollbarThumb;
  final Color scrollbarTrack;

  const AppColorSet({
    required this.accent,
    required this.accentLight,
    required this.accentDark,
    required this.bgDark,
    required this.bgSurface,
    required this.bgCard,
    required this.bgHover,
    required this.textPrimary,
    required this.textSecondary,
    required this.textDim,
    required this.border,
    required this.borderLight,
    required this.success,
    required this.warning,
    required this.error,
    required this.timelineBg,
    required this.timelineClip,
    required this.timelineClipSelected,
    required this.timelineClipDeleted,
    required this.timelineCursor,
    required this.scrollbarThumb,
    required this.scrollbarTrack,
  });
}

class AppColors {
  AppColors._();

  static AppColorSet current = _darkSet;

  static const AppColorSet _darkSet = AppColorSet(
    accent: Color(0xFFF57C00),
    accentLight: Color(0xFFFFA040),
    accentDark: Color(0xFFBB4D00),
    bgDark: Color(0xFF121212),
    bgSurface: Color(0xFF1E1E1E),
    bgCard: Color(0xFF2A2A2A),
    bgHover: Color(0xFF333333),
    textPrimary: Color(0xFFF5F5F5),
    textSecondary: Color(0xFFB0B0B0),
    textDim: Color(0xFF707070),
    border: Color(0xFF3A3A3A),
    borderLight: Color(0xFF4A4A4A),
    success: Color(0xFF4CAF50),
    warning: Color(0xFFFFC107),
    error: Color(0xFFEF5350),
    timelineBg: Color(0xFF1A1A1A),
    timelineClip: Color(0xFF333333),
    timelineClipSelected: Color(0xFFF57C00),
    timelineClipDeleted: Color(0xFF555555),
    timelineCursor: Color(0xFFFFFFFF),
    scrollbarThumb: Color(0xFF555555),
    scrollbarTrack: Color(0xFF2A2A2A),
  );

  static const AppColorSet _lightSet = AppColorSet(
    accent: Color(0xFFF57C00),
    accentLight: Color(0xFFFFA040),
    accentDark: Color(0xFFBB4D00),
    bgDark: Color(0xFFF2F2F2),
    bgSurface: Color(0xFFFFFFFF),
    bgCard: Color(0xFFE8E8E8),
    bgHover: Color(0xFFDCDCDC),
    textPrimary: Color(0xFF1A1A1A),
    textSecondary: Color(0xFF555555),
    textDim: Color(0xFF888888),
    border: Color(0xFFCCCCCC),
    borderLight: Color(0xFFDDDDDD),
    success: Color(0xFF2E7D32),
    warning: Color(0xFFF9A825),
    error: Color(0xFFD32F2F),
    timelineBg: Color(0xFFE4E4E4),
    timelineClip: Color(0xFFBDBDBD),
    timelineClipSelected: Color(0xFFF57C00),
    timelineClipDeleted: Color(0xFF9E9E9E),
    timelineCursor: Color(0xFF333333),
    scrollbarThumb: Color(0xFF999999),
    scrollbarTrack: Color(0xFFE0E0E0),
  );

  static const AppColorSet _twilightSet = AppColorSet(
    accent: Color(0xFF7C4DFF),
    accentLight: Color(0xFFB388FF),
    accentDark: Color(0xFF5600E8),
    bgDark: Color(0xFF0D0D1A),
    bgSurface: Color(0xFF16162B),
    bgCard: Color(0xFF1E1E3A),
    bgHover: Color(0xFF2A2A4A),
    textPrimary: Color(0xFFEEEEFF),
    textSecondary: Color(0xFFB0B0CC),
    textDim: Color(0xFF707088),
    border: Color(0xFF2E2E4A),
    borderLight: Color(0xFF3E3E5A),
    success: Color(0xFF4CAF50),
    warning: Color(0xFFFFC107),
    error: Color(0xFFEF5350),
    timelineBg: Color(0xFF0F0F1F),
    timelineClip: Color(0xFF252540),
    timelineClipSelected: Color(0xFF7C4DFF),
    timelineClipDeleted: Color(0xFF404060),
    timelineCursor: Color(0xFFFFFFFF),
    scrollbarThumb: Color(0xFF404060),
    scrollbarTrack: Color(0xFF1E1E3A),
  );

  static AppColorSet get darkSet => _darkSet;
  static AppColorSet get lightSet => _lightSet;
  static AppColorSet get twilightSet => _twilightSet;

  static void applyDark() => current = _darkSet;
  static void applyLight() => current = _lightSet;
  static void applyTwilight() => current = _twilightSet;

  static Color get accent => current.accent;
  static Color get accentLight => current.accentLight;
  static Color get accentDark => current.accentDark;
  static Color get bgDark => current.bgDark;
  static Color get bgSurface => current.bgSurface;
  static Color get bgCard => current.bgCard;
  static Color get bgHover => current.bgHover;
  static Color get textPrimary => current.textPrimary;
  static Color get textSecondary => current.textSecondary;
  static Color get textDim => current.textDim;
  static Color get border => current.border;
  static Color get borderLight => current.borderLight;
  static Color get success => current.success;
  static Color get warning => current.warning;
  static Color get error => current.error;
  static Color get timelineBg => current.timelineBg;
  static Color get timelineClip => current.timelineClip;
  static Color get timelineClipSelected => current.timelineClipSelected;
  static Color get timelineClipDeleted => current.timelineClipDeleted;
  static Color get timelineCursor => current.timelineCursor;
  static Color get scrollbarThumb => current.scrollbarThumb;
  static Color get scrollbarTrack => current.scrollbarTrack;
}
