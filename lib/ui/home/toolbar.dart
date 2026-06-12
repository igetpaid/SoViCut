import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/localization/app_localizations.dart';

enum AppMode { single, batch }

class Toolbar extends StatelessWidget {
  final AppMode currentMode;
  final ValueChanged<AppMode> onModeChanged;
  final String? currentFileName;
  final VoidCallback onExport;
  final bool isExporting;
  final VoidCallback? onCloseVideo;

  const Toolbar({
    super.key,
    required this.currentMode,
    required this.onModeChanged,
    this.currentFileName,
    required this.onExport,
    required this.isExporting,
    this.onCloseVideo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Row(
        children: [
          _buildLogo(),
          const SizedBox(width: 24),
          _buildModeToggle(),
          if (currentFileName != null) ...[
            const SizedBox(width: 16),
            _buildFileName(),
            const SizedBox(width: 4),
            _iconButton(Icons.close, AppLocalizations.t('menu.closeVideo'), onCloseVideo),
          ],
          const Spacer(),
          _buildExportButton(),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Center(
            child: Text(
              'S',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'SoViCut',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 16,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildModeToggle() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _modeButton(AppMode.single, AppLocalizations.t('menu.singleMode'), Icons.movie_outlined),
          Container(width: 1, height: 20, color: AppColors.border),
          _modeButton(AppMode.batch, AppLocalizations.t('menu.batchMode'), Icons.queue_play_next_outlined),
        ],
      ),
    );
  }

  Widget _modeButton(AppMode mode, String label, IconData icon) {
    final isActive = currentMode == mode;
    return GestureDetector(
      onTap: () => onModeChanged(mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppColors.accent.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isActive ? AppColors.accent : AppColors.textDim),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isActive ? AppColors.accent : AppColors.textDim,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileName() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.link, size: 12, color: AppColors.textDim),
          const SizedBox(width: 4),
          Text(
            currentFileName!,
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _iconButton(IconData icon, String tooltip, VoidCallback? onPressed) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 18, color: AppColors.textDim),
        ),
      ),
    );
  }

  Widget _buildExportButton() {
    return SizedBox(
      height: 32,
      child: ElevatedButton.icon(
        onPressed: isExporting ? null : onExport,
        icon: isExporting
            ? SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.bgDark,
                ),
              )
            : const Icon(Icons.save, size: 14),
        label: Text(isExporting ? '...' : AppLocalizations.t('menu.export')),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.bgDark,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
    );
  }
}
