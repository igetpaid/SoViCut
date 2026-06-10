import 'package:flutter/material.dart';
import 'clip.dart';

class TimelineWidget extends StatefulWidget {
  final List<Clip> clips;
  final Function(int, double) onSplit;
  final Function(int) onDelete;
  final Function(int) onRestore;
  final Function(int, double) onSelectClip;
  final Function(double) onCursorMoved;
  final double externalCursorPosition;
  
  const TimelineWidget({
    super.key,
    required this.clips,
    required this.onSplit,
    required this.onDelete,
    required this.onRestore,
    required this.onSelectClip,
    required this.onCursorMoved,
    required this.externalCursorPosition,
  });

  @override
  State<TimelineWidget> createState() => _TimelineWidgetState();
}

class _TimelineWidgetState extends State<TimelineWidget> {
  double _cursorPosition = 0;
  int? _selectedClipIndex;
  double _cursorInClip = 0;
  
  double get totalDuration {
    return widget.clips.fold(0.0, (sum, clip) => sum + clip.duration);
  }

  @override
  void initState() {
    super.initState();
    _cursorPosition = widget.externalCursorPosition;
  }

  @override
  void didUpdateWidget(TimelineWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.externalCursorPosition != oldWidget.externalCursorPosition) {
      setState(() {
        _cursorPosition = widget.externalCursorPosition;
      });
    }
  }
  
  String formatDuration(double seconds) {
    final duration = Duration(seconds: seconds.toInt());
    final minutes = duration.inMinutes.remainder(60);
    final secs = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  void _onTimelineTap(double x, double width) {
    if (width <= 0) return;
    final position = (x / width).clamp(0.0, 1.0);
    setState(() {
      _cursorPosition = position;
    });
    widget.onCursorMoved(position * totalDuration);
    
    double accumulated = 0;
    for (int i = 0; i < widget.clips.length; i++) {
      final clip = widget.clips[i];
      final clipEnd = accumulated + clip.duration;
      if (position * totalDuration >= accumulated && position * totalDuration <= clipEnd) {
        setState(() {
          _selectedClipIndex = i;
          _cursorInClip = position * totalDuration - accumulated;
        });
        widget.onSelectClip(i, _cursorInClip);
        break;
      }
      accumulated = clipEnd;
    }
  }

  void _splitAtCursor() {
    if (_selectedClipIndex == null) return;
    final clip = widget.clips[_selectedClipIndex!];
    if (!clip.isVisible) return;
    widget.onSplit(_selectedClipIndex!, _cursorInClip);
  }

  @override
  Widget build(BuildContext context) {
    final totalDur = totalDuration;
    
    return Container(
      height: 120,
      color: Colors.grey[900],
      child: Column(
        children: [
          Expanded(
            child: GestureDetector(
              onTapDown: (details) {
                final box = context.findRenderObject() as RenderBox?;
                if (box != null && box.hasSize) {
                  _onTimelineTap(details.localPosition.dx, box.size.width);
                }
              },
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return CustomPaint(
                    painter: TimelinePainter(
                      clips: widget.clips,
                      totalDuration: totalDur,
                      cursorPosition: _cursorPosition,
                      selectedClipIndex: _selectedClipIndex,
                      width: constraints.maxWidth,
                      height: constraints.maxHeight,
                    ),
                    size: Size(constraints.maxWidth, constraints.maxHeight),
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('0:00', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                Text(formatDuration(totalDur / 4), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                Text(formatDuration(totalDur / 2), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                Text(formatDuration(totalDur * 3 / 4), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                Text(formatDuration(totalDur), style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: (_selectedClipIndex != null && _cursorInClip > 0 && _cursorInClip < widget.clips[_selectedClipIndex!].duration)
                    ? _splitAtCursor
                    : null,
                icon: const Icon(Icons.content_cut, size: 20),
                tooltip: 'Разделить в позиции курсора',
              ),
              IconButton(
                onPressed: _selectedClipIndex != null && widget.clips[_selectedClipIndex!].isVisible
                    ? () => widget.onDelete(_selectedClipIndex!)
                    : null,
                icon: const Icon(Icons.delete, size: 20),
                tooltip: 'Удалить выбранный фрагмент',
              ),
              IconButton(
                onPressed: _selectedClipIndex != null && !widget.clips[_selectedClipIndex!].isVisible
                    ? () => widget.onRestore(_selectedClipIndex!)
                    : null,
                icon: const Icon(Icons.restore, size: 20),
                tooltip: 'Восстановить выбранный фрагмент',
              ),
              const VerticalDivider(),
              if (widget.clips.isNotEmpty)
                Text(
                  'Фрагментов: ${widget.clips.length} (${widget.clips.where((c) => c.isVisible).length} видимых)',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class TimelinePainter extends CustomPainter {
  final List<Clip> clips;
  final double totalDuration;
  final double cursorPosition;
  final int? selectedClipIndex;
  final double width;
  final double height;

  TimelinePainter({
    required this.clips,
    required this.totalDuration,
    required this.cursorPosition,
    required this.selectedClipIndex,
    required this.width,
    required this.height,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (width <= 0 || height <= 0) return;
    
    double accumulatedX = 0;
    
    for (int i = 0; i < clips.length; i++) {
      final clip = clips[i];
      final clipWidth = (clip.duration / totalDuration) * width;
      final rect = Rect.fromLTWH(accumulatedX, 0, clipWidth, height);
      
      Paint paint;
      if (!clip.isVisible) {
        paint = Paint()..color = Colors.grey[700]!.withOpacity(0.5);
      } else if (selectedClipIndex == i) {
        paint = Paint()..color = Colors.orange.withOpacity(0.8);
      } else {
        paint = Paint()..color = Colors.grey[800]!;
      }
      
      canvas.drawRect(rect, paint);
      
      final borderPaint = Paint()
        ..color = Colors.grey[600]!
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      canvas.drawRect(rect, borderPaint);
      
      if (!clip.isVisible) {
        final linesPaint = Paint()
          ..color = Colors.white.withOpacity(0.3)
          ..strokeWidth = 2;
        canvas.drawLine(
          Offset(accumulatedX, 0),
          Offset(accumulatedX + clipWidth, height),
          linesPaint,
        );
        canvas.drawLine(
          Offset(accumulatedX + clipWidth, 0),
          Offset(accumulatedX, height),
          linesPaint,
        );
      }
      
      accumulatedX += clipWidth;
    }
    
    final cursorX = cursorPosition * width;
    final cursorPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(cursorX, 0),
      Offset(cursorX, height),
      cursorPaint,
    );
  }

  @override
  bool shouldRepaint(covariant TimelinePainter oldDelegate) {
    return oldDelegate.clips != clips ||
        oldDelegate.totalDuration != totalDuration ||
        oldDelegate.cursorPosition != cursorPosition ||
        oldDelegate.selectedClipIndex != selectedClipIndex ||
        oldDelegate.width != width ||
        oldDelegate.height != height;
  }
}