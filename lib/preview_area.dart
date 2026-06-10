import 'dart:io';
import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'clip.dart';

class PreviewArea extends StatefulWidget {
  final String? videoPath;
  final bool isDragging;
  final Function(DropDoneDetails) onDragDone;
  final Function() onDragEntered;
  final Function() onDragExited;
  final VoidCallback onTap;
  final List<Clip> clips;
  final double cursorPosition;
  final Function(double) onPositionChanged;
  
  const PreviewArea({
    super.key,
    this.videoPath,
    required this.isDragging,
    required this.onDragDone,
    required this.onDragEntered,
    required this.onDragExited,
    required this.onTap,
    required this.clips,
    required this.cursorPosition,
    required this.onPositionChanged,
  });

  @override
  State<PreviewArea> createState() => _PreviewAreaState();
}

class _PreviewAreaState extends State<PreviewArea> {
  VideoPlayerController? _controller;
  ChewieController? _chewieController;
  bool _isInitializing = false;
  String _errorMessage = '';
  bool _isSeeking = false;
  double _currentPlaybackPosition = 0;

  double get _totalDuration {
    double total = 0;
    for (final clip in widget.clips) {
      if (clip.isVisible) {
        total += clip.duration;
      }
    }
    return total;
  }

  double _mapTimelineToOriginal(double timelinePosition) {
    if (_totalDuration <= 0) return 0;
    final targetTime = timelinePosition * _totalDuration;
    double accumulated = 0;
    for (final clip in widget.clips) {
      if (!clip.isVisible) continue;
      if (targetTime <= accumulated + clip.duration) {
        return clip.startTime + (targetTime - accumulated);
      }
      accumulated += clip.duration;
    }
    return 0;
  }

  double _mapOriginalToTimeline(double originalSeconds) {
    double accumulated = 0;
    for (final clip in widget.clips) {
      if (!clip.isVisible) continue;
      if (originalSeconds >= clip.startTime && originalSeconds <= clip.endTime) {
        final timelineSeconds = accumulated + (originalSeconds - clip.startTime);
        return timelineSeconds / _totalDuration;
      }
      accumulated += clip.duration;
    }
    return 0;
  }

  @override
  void didUpdateWidget(PreviewArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.videoPath != oldWidget.videoPath) {
      _initializePlayer();
    } else if (widget.clips != oldWidget.clips) {
      _initializePlayer();
    } else if (widget.cursorPosition != oldWidget.cursorPosition && !_isSeeking) {
      _seekToTimelinePosition(widget.cursorPosition);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  Future<void> _seekToTimelinePosition(double timelinePosition) async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    final originalSeconds = _mapTimelineToOriginal(timelinePosition);
    _isSeeking = true;
    await _controller!.seekTo(Duration(milliseconds: (originalSeconds * 1000).toInt()));
    _isSeeking = false;
  }

  Future<void> _initializePlayer() async {
    if (widget.videoPath == null) return;
    
    _isInitializing = true;
    _errorMessage = '';
    setState(() {});

    if (_controller != null) {
      _controller!.dispose();
    }
    if (_chewieController != null) {
      _chewieController!.dispose();
    }

    final file = File(widget.videoPath!);
    if (!await file.exists()) {
      setState(() {
        _errorMessage = 'Файл не найден';
        _isInitializing = false;
      });
      return;
    }

    _controller = VideoPlayerController.file(file);
    
    try {
      await _controller!.initialize();
    } catch (e) {
      setState(() {
        _errorMessage = 'Ошибка загрузки: $e';
        _isInitializing = false;
      });
      return;
    }

    _controller!.addListener(() {
      if (!mounted) return;
      if (_isSeeking) return;
      
      final currentOriginal = _controller!.value.position.inMilliseconds / 1000;
      final newTimelinePosition = _mapOriginalToTimeline(currentOriginal);
      if (newTimelinePosition != _currentPlaybackPosition) {
        _currentPlaybackPosition = newTimelinePosition;
        widget.onPositionChanged(newTimelinePosition);
      }
    });

    _chewieController = ChewieController(
      videoPlayerController: _controller!,
      autoPlay: false,
      looping: false,
      showControls: true,
      materialProgressColors: ChewieProgressColors(
        playedColor: Colors.orange,
        handleColor: Colors.orange,
        backgroundColor: Colors.grey,
        bufferedColor: Colors.grey[700]!,
      ),
      showControlsOnInitialize: true,
    );

    _isInitializing = false;
    setState(() {});
    
    if (widget.cursorPosition > 0) {
      _seekToTimelinePosition(widget.cursorPosition);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      child: GestureDetector(
        onTap: widget.videoPath == null ? widget.onTap : null,
        child: DropTarget(
          onDragEntered: (_) => widget.onDragEntered(),
          onDragExited: (_) => widget.onDragExited(),
          onDragDone: widget.onDragDone,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.black,
            child: widget.videoPath == null
                ? _buildPlaceholder()
                : _isInitializing
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Загрузка видео...', style: TextStyle(color: Colors.white)),
                          ],
                        ),
                      )
                    : _errorMessage.isNotEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.error, size: 48, color: Colors.orange),
                                SizedBox(height: 16),
                                Text(_errorMessage, style: TextStyle(color: Colors.white)),
                                SizedBox(height: 16),
                                TextButton(
                                  onPressed: _initializePlayer,
                                  child: Text('Повторить', style: TextStyle(color: Colors.orange)),
                                ),
                              ],
                            ),
                          )
                        : _chewieController == null || !_chewieController!.videoPlayerController.value.isInitialized
                            ? const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.error, size: 48, color: Colors.orange),
                                    SizedBox(height: 16),
                                    Text('Не удалось загрузить видео', style: TextStyle(color: Colors.white)),
                                  ],
                                ),
                              )
                            : Chewie(controller: _chewieController!),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            widget.isDragging ? Icons.file_upload : Icons.video_library,
            size: 64,
            color: widget.isDragging ? Colors.orange : Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            widget.isDragging ? 'Отпустите видео' : 'Нажмите или перетащите видео',
            style: TextStyle(
              color: widget.isDragging ? Colors.orange : Colors.grey,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          if (!widget.isDragging)
            const Text(
              'чтобы начать работу',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
        ],
      ),
    );
  }
}