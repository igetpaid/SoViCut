import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';

class PreviewArea extends StatefulWidget {
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

  @override
  State<PreviewArea> createState() => _PreviewAreaState();
}

class _PreviewAreaState extends State<PreviewArea> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: DropTarget(
          onDragEntered: (_) => widget.onDragEntered(),
          onDragExited: (_) => widget.onDragExited(),
          onDragDone: widget.onDragDone,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.black,
            child: Center(
              child: widget.videoPath == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          widget.isDragging ? Icons.file_upload : Icons.video_library,
                          size: 64,
                          color: widget.isDragging || _isHovering ? Colors.orange : Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          widget.isDragging ? 'Отпустите видео' : 'Нажмите или перетащите видео',
                          style: TextStyle(
                            color: widget.isDragging || _isHovering ? Colors.orange : Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (!widget.isDragging && !_isHovering)
                          const Text(
                            'чтобы начать работу',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                      ],
                    )
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        Center(
                          child: Text(
                            'Плеер будет здесь\n${widget.videoPath!.split('\\').last}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.drag_handle,
                              size: 20,
                              color: Colors.grey,
                            ),
                          ),
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