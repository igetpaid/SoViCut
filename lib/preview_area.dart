import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';

class PreviewArea extends StatelessWidget {
  final String? videoPath;
  final bool isDragging;
  final Function(DropDoneDetails) onDragDone;
  final Function() onDragEntered;
  final Function() onDragExited;
  final VoidCallback onTap;
  
  const PreviewArea({
    super.key,
    this.videoPath,
    required this.isDragging,
    required this.onDragDone,
    required this.onDragEntered,
    required this.onDragExited,
    required this.onTap,
  });

  String get _fileName {
    if (videoPath == null) return '';
    return videoPath!.split('\\').last;
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      child: GestureDetector(
        onTap: videoPath == null ? onTap : null,
        child: DropTarget(
          onDragEntered: (_) => onDragEntered(),
          onDragExited: (_) => onDragExited(),
          onDragDone: onDragDone,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.black,
            child: videoPath == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isDragging ? Icons.file_upload : Icons.video_library,
                          size: 64,
                          color: isDragging ? Colors.orange : Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          isDragging ? 'Отпустите видео' : 'Нажмите или перетащите видео',
                          style: TextStyle(
                            color: isDragging ? Colors.orange : Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (!isDragging)
                          const Text(
                            'чтобы начать работу',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                      ],
                    ),
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.play_circle_filled, size: 64, color: Colors.orange),
                        const SizedBox(height: 16),
                        Text(
                          _fileName,
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Плеер временно отключён',
                          style: TextStyle(color: Colors.grey, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}