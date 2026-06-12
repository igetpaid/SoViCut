import 'package:flutter/material.dart';
import 'clip.dart';
import 'core/localization/app_localizations.dart';

class ClipsTab extends StatelessWidget {
  final List<Clip> clips;
  final Function(int) onDelete;
  final Function(int) onRestore;
  final Function(int)? onSelect;
  final int? selectedIndex;

  const ClipsTab({
    super.key,
    required this.clips,
    required this.onDelete,
    required this.onRestore,
    this.onSelect,
    this.selectedIndex,
  });

  String formatDuration(double seconds) {
    final duration = Duration(seconds: seconds.toInt());
    final minutes = duration.inMinutes.remainder(60);
    final secs = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.content_cut, size: 20, color: Colors.orange),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  AppLocalizations.t('tabs.clips'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    AppLocalizations.t('timeline.clipsCount', {'count': '${clips.length}', 'visible': '${clips.where((c) => c.isVisible).length}'}),
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...clips.asMap().entries.map((entry) {
            final index = entry.key;
            final clip = entry.value;
            return GestureDetector(
              onTap: onSelect != null ? () => onSelect!(index) : null,
              child: Card(
              margin: const EdgeInsets.only(bottom: 8),
              color: index == selectedIndex ? Colors.orange[900] : (clip.isVisible ? Colors.grey[800] : Colors.grey[800]!.withOpacity(0.4)),
              shape: index == selectedIndex
                  ? RoundedRectangleBorder(
                      side: BorderSide(color: Colors.orange, width: 1.5),
                      borderRadius: BorderRadius.circular(12),
                    )
                  : null,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 4,
                          height: 40,
                          color: clip.isVisible ? Colors.orange : Colors.grey,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppLocalizations.t('timeline.clipNumber', {'number': '${index + 1}'}),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: clip.isVisible ? Colors.white : Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${formatDuration(clip.startTime)} — ${formatDuration(clip.endTime)} (${formatDuration(clip.duration)})',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: clip.isVisible ? Colors.grey : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!clip.isVisible)
                          Chip(
                            label: Text(AppLocalizations.t('timeline.delete'), style: const TextStyle(fontSize: 10)),
                            backgroundColor: Colors.red,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        IconButton(
                          onPressed: clip.isVisible
                              ? () => onDelete(index)
                              : () => onRestore(index),
                          icon: Icon(
                            clip.isVisible ? Icons.delete_outline : Icons.restore,
                            size: 20,
                            color: Colors.orange,
                          ),
                          tooltip: clip.isVisible ? AppLocalizations.t('timeline.delete') : AppLocalizations.t('timeline.restore'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              ),
            );
          }),
        ],
      ),
    );
  }
}