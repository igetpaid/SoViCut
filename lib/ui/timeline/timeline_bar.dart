import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../clip.dart';
import '../../services/ffmpeg/thumbnail_service.dart';

class TimelineBar extends StatefulWidget {
  final List<Clip> clips;
  final double totalDuration;
  final double cursorPosition;
  final int? selectedClipIndex;
  final double? currentTime;
  final bool isPlaying;
  final VoidCallback? onPlayPause;
  final ValueChanged<double> onSeek;
  final List<ThumbnailEntry> thumbnails;

  const TimelineBar({
    super.key,
    required this.clips,
    required this.totalDuration,
    required this.cursorPosition,
    this.selectedClipIndex,
    this.currentTime,
    this.isPlaying = false,
    this.onPlayPause,
    required this.onSeek,
    this.thumbnails = const [],
  });

  @override
  State<TimelineBar> createState() => _TimelineBarState();
}

class _TimelineBarState extends State<TimelineBar> {
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _showThumbnail(double position) {
    if (widget.thumbnails.isEmpty) return;

    final totalSec = position * widget.totalDuration;
    ThumbnailEntry? best;
    for (final entry in widget.thumbnails) {
      if (best == null || (entry.timeInSeconds - totalSec).abs() < (best.timeInSeconds - totalSec).abs()) {
        best = entry;
      }
    }
    if (best == null || !File(best.path).existsSync()) return;

    final thumbFile = File(best.path);
    _removeOverlay();

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: 160,
        height: 100,
        child: CompositedTransformFollower(
          link: _layerLink,
          targetAnchor: Alignment.bottomCenter,
          followerAnchor: Alignment.topCenter,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppColors.border),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: Image.file(
                thumbFile,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      color: AppColors.timelineBg,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          _buildPlayButton(),
          const SizedBox(width: 8),
          _buildTimeDisplay(),
          const SizedBox(width: 8),
          Expanded(child: _buildScrubBar()),
          const SizedBox(width: 8),
          _buildTotalTime(),
        ],
      ),
    );
  }

  Widget _buildPlayButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: widget.onPlayPause,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.accent.withOpacity(0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            widget.isPlaying ? Icons.pause : Icons.play_arrow,
            size: 18,
            color: AppColors.accent,
          ),
        ),
      ),
    );
  }

  Widget _buildTimeDisplay() {
    final time = widget.currentTime ?? widget.cursorPosition * widget.totalDuration;
    return SizedBox(
      width: 50,
      child: Text(
        _formatTime(time),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
          fontFamily: 'monospace',
        ),
      ),
    );
  }

  Widget _buildTotalTime() {
    return SizedBox(
      width: 50,
      child: Text(
        _formatTime(widget.totalDuration),
        style: TextStyle(
          fontSize: 12,
          color: AppColors.textDim,
          fontFamily: 'monospace',
        ),
        textAlign: TextAlign.right,
      ),
    );
  }

  Widget _buildScrubBar() {
    return CompositedTransformTarget(
      link: _layerLink,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return GestureDetector(
            onTapDown: (details) {
              final ratio = (details.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0);
              _showThumbnail(ratio);
              widget.onSeek(ratio * widget.totalDuration);
            },
            onHorizontalDragStart: (details) {
              final ratio = (details.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0);
              _showThumbnail(ratio);
            },
            onHorizontalDragUpdate: (details) {
              final ratio = ((details.localPosition.dx) / constraints.maxWidth).clamp(0.0, 1.0);
              _showThumbnail(ratio);
              widget.onSeek(ratio * widget.totalDuration);
            },
            onHorizontalDragEnd: (_) {
              _removeOverlay();
            },
            child: Container(
              height: 32,
              alignment: Alignment.center,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: CustomPaint(
                  size: Size(constraints.maxWidth, 8),
                  painter: _ScrubBarPainter(
                    cursorPosition: widget.cursorPosition,
                    clips: widget.clips,
                    totalDuration: widget.totalDuration,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatTime(double seconds) {
    if (seconds.isNaN || seconds.isInfinite) return '0:00';
    final dur = Duration(milliseconds: (seconds * 1000).toInt());
    final min = dur.inMinutes.remainder(60);
    final sec = dur.inSeconds.remainder(60);
    return '${min.toString().padLeft(1, '0')}:${sec.toString().padLeft(2, '0')}';
  }
}

class _ScrubBarPainter extends CustomPainter {
  final double cursorPosition;
  final List<Clip> clips;
  final double totalDuration;

  _ScrubBarPainter({
    required this.cursorPosition,
    required this.clips,
    required this.totalDuration,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (totalDuration <= 0) return;

    final bgPaint = Paint()..color = AppColors.border;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.width, size.height), const Radius.circular(3)),
      bgPaint,
    );

    double visibleAccumulated = 0;
    for (final clip in clips) {
      if (!clip.isVisible) continue;
      final clipWidth = (clip.duration / totalDuration) * size.width;
      final paint = Paint()..color = AppColors.accent.withOpacity(0.7);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(visibleAccumulated / totalDuration * size.width, 0, clipWidth, size.height),
          const Radius.circular(2),
        ),
        paint,
      );
      visibleAccumulated += clip.duration;
    }

    final cursorX = cursorPosition * size.width;
    final cursorPaint = Paint()
      ..color = AppColors.timelineCursor
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(cursorX, 0),
      Offset(cursorX, size.height),
      cursorPaint,
    );
  }

  @override
  bool shouldRepaint(_ScrubBarPainter oldDelegate) =>
      oldDelegate.cursorPosition != cursorPosition ||
      oldDelegate.clips != clips ||
      oldDelegate.totalDuration != totalDuration;
}
