import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/localization/app_localizations.dart';
import '../../providers/theme_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/export_providers.dart';
import '../../services/settings_service.dart';

class SettingsPanel extends ConsumerWidget {
  const SettingsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTheme = ref.watch(themeModeProvider);
    final currentLocale = ref.watch(localeProvider);

    return Dialog(
      backgroundColor: AppColors.bgSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.border),
      ),
      child: Container(
        width: 340,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
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
            const SizedBox(height: 20),
            Text(
              AppLocalizations.t('settings.language'),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            _LangOption(
              code: 'ru',
              label: 'Русский',
              selected: currentLocale.languageCode == 'ru',
              onTap: () {
                ref.read(localeProvider.notifier).setLocale(const Locale('ru'));
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 8),
            _LangOption(
              code: 'en',
              label: 'English',
              selected: currentLocale.languageCode == 'en',
              onTap: () {
                ref.read(localeProvider.notifier).setLocale(const Locale('en'));
                _saveAll(ref);
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 20),
            // --- Export mode toggle ---
            Text(
              'Export',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            _ExportModeOption(
              selected: ref.watch(fastExportProvider),
              onTap: () {
                final current = ref.read(fastExportProvider);
                ref.read(fastExportProvider.notifier).state = !current;
                _saveAll(ref);
              },
            ),
            const SizedBox(height: 12),
            // --- Save export mode toggle ---
            _SaveExportToggle(),
            const SizedBox(height: 4),
          ],
        ),
      ),
    ),
  );
  }
}

class _LangOption extends StatelessWidget {
  final String code;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _LangOption({
    required this.code,
    required this.label,
    required this.selected,
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
                ? AppColors.accent.withValues(alpha: 0.12)
                : AppColors.bgCard.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    code.toUpperCase(),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.accent,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (selected)
                Icon(Icons.check_circle, size: 18, color: AppColors.accent),
            ],
          ),
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

// --- Helpers ---

void _saveAll(WidgetRef ref) {
  final l = ref.read(localeProvider);
  final t = ref.read(themeModeProvider);
  final f = ref.read(fastExportProvider);
  final s = ref.read(saveExportModeProvider);
  SettingsService.save(AppSettings(
    language: l.languageCode,
    themeMode: t.name,
    fastExport: f,
    saveExportMode: s,
  ));
}

class _ExportModeOption extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;

  const _ExportModeOption({required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final icon = selected ? Icons.bolt : Icons.shield_outlined;
    final label = selected ? 'Fast Export' : 'Standard Export';
    final desc = selected
        ? 'Larger file, faster processing'
        : 'Smaller file, standard processing';
    final accent = AppColors.accent;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.bgCard.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: accent),
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
                      desc,
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textDim,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios,
                  size: 12, color: AppColors.textDim),
            ],
          ),
        ),
      ),
    );
  }
}

class _SaveExportToggle extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(saveExportModeProvider);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: SwitchListTile(
        title: Text(
          'Save export settings',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Text(
          'Remember Fast / Standard Export choice',
          style: TextStyle(fontSize: 10, color: AppColors.textDim),
        ),
        value: value,
        onChanged: (v) {
          ref.read(saveExportModeProvider.notifier).state = v;
          _saveAll(ref);
        },
        activeThumbColor: AppColors.accent,
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      ),
    );
  }
}
