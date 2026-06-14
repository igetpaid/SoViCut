import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/localization/app_localizations.dart';
import '../../providers/theme_provider.dart';

class SettingsPanel extends ConsumerWidget {
  const SettingsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTheme = ref.watch(themeModeProvider);

    return Dialog(
      backgroundColor: AppColors.bgSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.border),
      ),
      child: Container(
        width: 340,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.settings, size: 20, color: AppColors.textPrimary),
                const SizedBox(width: 8),
                Text(
                  AppLocalizations.t('settings.title'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () => Navigator.pop(context),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.close, size: 18, color: AppColors.textDim),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              AppLocalizations.t('settings.theme'),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            _ThemeOption(
              icon: Icons.light_mode,
              label: AppLocalizations.t('settings.themeLight'),
              description: AppLocalizations.t('settings.themeLightDesc'),
              selected: currentTheme == AppThemeMode.light,
              accentColor: AppColors.lightSet.accent,
              onTap: () {
                ref.read(themeModeProvider.notifier).setTheme(AppThemeMode.light);
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 8),
            _ThemeOption(
              icon: Icons.dark_mode,
              label: AppLocalizations.t('settings.themeDark'),
              description: AppLocalizations.t('settings.themeDarkDesc'),
              selected: currentTheme == AppThemeMode.dark,
              accentColor: AppColors.darkSet.accent,
              onTap: () {
                ref.read(themeModeProvider.notifier).setTheme(AppThemeMode.dark);
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 8),
            _ThemeOption(
              icon: Icons.color_lens_outlined,
              label: AppLocalizations.t('settings.themeTwilight'),
              description: AppLocalizations.t('settings.themeTwilightDesc'),
              selected: currentTheme == AppThemeMode.twilight,
              accentColor: AppColors.twilightSet.accent,
              onTap: () {
                ref.read(themeModeProvider.notifier).setTheme(AppThemeMode.twilight);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final bool selected;
  final Color accentColor;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.icon,
    required this.label,
    required this.description,
    required this.selected,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? accentColor.withValues(alpha: 0.12)
                : AppColors.bgCard.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? accentColor : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: accentColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textDim,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle, size: 18, color: accentColor),
            ],
          ),
        ),
      ),
    );
  }
}
