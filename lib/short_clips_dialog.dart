import 'package:flutter/material.dart';
import 'export_strategy.dart';
import 'concat_strategy.dart';
import 'transcode_strategy.dart';
import 'core/localization/app_localizations.dart';

class ShortClipsDialog extends StatelessWidget {
  final ShortClipCheckResult checkResult;
  final Function(ExportStrategy) onStrategySelected;
  final VoidCallback onCancel;

  const ShortClipsDialog({
    super.key,
    required this.checkResult,
    required this.onStrategySelected,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.warning_amber, color: Colors.orange),
          const SizedBox(width: 8),
          Text(AppLocalizations.t('dialog.shortClipsFound')),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(checkResult.getWarningMessage()),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.t('dialog.chooseAction'),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: onCancel,
          child: Text(AppLocalizations.t('dialog.cancelExport')),
        ),
        ElevatedButton.icon(
          onPressed: () => onStrategySelected(ConcatStrategy()),
          icon: const Icon(Icons.speed),
          label: Text(AppLocalizations.t('dialog.roundToKeyframes')),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
        ),
        ElevatedButton.icon(
          onPressed: () => onStrategySelected(TranscodeStrategy()),
          icon: const Icon(Icons.build),  // ← заменил Icons.quality на Icons.build
          label: Text(AppLocalizations.t('dialog.transcode')),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[800]),
        ),
      ],
    );
  }
}