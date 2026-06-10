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
  
  const PreviewArea({
    super.key,
    this.videoPath,
    required this.isDragging,
    required this.onDragDone,
    required this.onDragEntered,
    required this.onDragExited,
    required this.onTap,
    required this.clips,
  });

  @override
  State<PreviewArea> createState() => _PreviewAreaState();
}

class _PreviewAreaState extends State<PreviewArea> {
  VideoPlayerController? _controller;
  ChewieController? _chewieController;
  bool _isInitializing = false;
  String _errorMessage = '';

  @override
  void didUpdateWidget(PreviewArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.videoPath != oldWidget.videoPath) {
      print('=== PreviewArea: videoPath изменился ===');
      _initializePlayer();
    }
  }

  @override
  void dispose() {
    print('=== PreviewArea: dispose ===');
    _controller?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  Future<void> _initializePlayer() async {
    print('=== PreviewArea: _initializePlayer START ===');
    print('  videoPath: ${widget.videoPath}');
    print('  clips count: ${widget.clips.length}');
    
    if (widget.videoPath == null) {
      print('  videoPath = null, выходим');
      return;
    }
    
    // Проверяем существование файла
    final file = File(widget.videoPath!);
    if (!await file.exists()) {
      print('  ОШИБКА: файл не существует!');
      setState(() {
        _errorMessage = 'Файл не найден: ${widget.videoPath}';
        _isInitializing = false;
      });
      return;
    }
    print('  файл существует, размер: ${await file.length()} байт');
    
    _isInitializing = true;
    _errorMessage = '';
    setState(() {});

    if (_controller != null) {
      print('  disposing old controller');
      _controller!.dispose();
    }
    if (_chewieController != null) {
      print('  disposing old chewie controller');
      _chewieController!.dispose();
    }

    print('  создаём VideoPlayerController...');
    _controller = VideoPlayerController.file(file);
    
    print('  вызываем initialize...');
    try {
      await _controller!.initialize();
      print('  initialize УСПЕШНО завершён');
      print('  duration: ${_controller!.value.duration}');
      print('  aspectRatio: ${_controller!.value.aspectRatio}');
    } catch (e, stackTrace) {
      print('  ОШИБКА initialize: $e');
      print('  stackTrace: $stackTrace');
      setState(() {
        _errorMessage = 'Ошибка загрузки видео: $e';
        _isInitializing = false;
      });
      return;
    }

    print('  создаём ChewieController...');
    try {
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
      print('  ChewieController создан успешно');
    } catch (e, stackTrace) {
      print('  ОШИБКА создания ChewieController: $e');
      print('  stackTrace: $stackTrace');
      setState(() {
        _errorMessage = 'Ошибка создания плеера: $e';
        _isInitializing = false;
      });
      return;
    }

    _isInitializing = false;
    setState(() {});
    print('=== PreviewArea: _initializePlayer SUCCESS ===');
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