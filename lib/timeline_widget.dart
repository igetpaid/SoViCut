import 'package:flutter/material.dart';
import 'clip.dart';

class TimelineWidget extends StatelessWidget {
  final List<Clip> clips;
  final VoidCallback onSplit;
  final VoidCallback onDelete;
  final VoidCallback onRestore;
  
  const TimelineWidget({
    super.key,
    required this.clips,
    required this.onSplit,
    required this.onDelete,
    required this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Кнопки управления таймлайном
        IconButton(
          onPressed: onSplit,
          icon: const Icon(Icons.content_cut, size: 20),
          tooltip: 'Разделить',
        ),
        IconButton(
          onPressed: onDelete,
          icon: const Icon(Icons.delete, size: 20),
          tooltip: 'Удалить фрагмент',
        ),
        IconButton(
          onPressed: onRestore,
          icon: const Icon(Icons.restore, size: 20),
          tooltip: 'Восстановить',
        ),
        const VerticalDivider(),
        Expanded(
          child: Container(
            height: 50,
            color: Colors.grey[850],
            child: Center(
              child: Text(
                'Таймлайн (${clips.length} фрагментов)',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}