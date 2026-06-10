import 'package:flutter/material.dart';
import 'export_strategy.dart';
import 'concat_strategy.dart';
import 'transcode_strategy.dart';

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
      title: const Row(
        children: [
          Icon(Icons.warning_amber, color: Colors.orange),
          SizedBox(width: 8),
          Text('Обнаружены короткие фрагменты'),
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
          const Text(
            'Выберите способ обработки:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: onCancel,
          child: const Text('Отмена экспорта'),
        ),
        ElevatedButton.icon(
          onPressed: () => onStrategySelected(ConcatStrategy()),
          icon: const Icon(Icons.speed),
          label: const Text('Округление до ключевых кадров (быстро)'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
        ),
        ElevatedButton.icon(
          onPressed: () => onStrategySelected(TranscodeStrategy()),
          icon: const Icon(Icons.build),  // ← заменил Icons.quality на Icons.build
          label: const Text('Перекодировать (медленно, но надёжно)'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[800]),
        ),
      ],
    );
  }
}