import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:path_provider/path_provider.dart';
import 'audio_track.dart';
import 'clip.dart';
import 'ffmpeg_service.dart';
import 'preview_area.dart';
import 'timeline_widget.dart';
import 'tool_panel.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _videoPath;
  List<AudioTrack> _audioTracks = [];
  List<Clip> _clips = [];
  bool _isLoading = false;
  bool _isDragging = false;
  
  bool _trimEnabled = false;
  double _trimSeconds = 10;
  int _trimMode = 0;
  
  bool _audioEnabled = false;
  bool _mixTracks = false;

  Future<void> _pickVideo() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.video);
    if (result != null) {
      await _loadVideo(result.files.single.path!);
    }
  }

  Future<void> _loadVideo(String path) async {
    setState(() {
      _videoPath = path;
      _isLoading = true;
    });
    
    final tracks = await FFmpegService.analyzeAudio(path);
    final duration = await _getVideoDuration(path);
    final clips = [
      Clip(
        id: 0,
        sourcePath: path,
        startTime: 0,
        endTime: duration,
        isVisible: true,
      ),
    ];
    
    setState(() {
      _audioTracks = tracks;
      _clips = clips;
      _isLoading = false;
    });
  }

  Future<double> _getVideoDuration(String path) async {
    final result = await Process.run(
      'ffprobe',
      [
        '-v', 'error',
        '-show_entries', 'format=duration',
        '-of', 'default=noprint_wrappers=1:nokey=1',
        path
      ],
      runInShell: true,
    );
    return double.parse(result.stdout.toString().trim());
  }

  void _splitClip() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Разделение будет добавлено позже')),
    );
  }

  void _deleteClip() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Удаление будет добавлено позже')),
    );
  }

  void _restoreClip() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Восстановление будет добавлено позже')),
    );
  }

  Future<String> _getUniqueFilePath(String directory, String baseName) async {
    final editedName = '${baseName}_edited.mp4';
    String candidatePath = '$directory\\$editedName';
    
    if (!await File(candidatePath).exists()) {
      return candidatePath;
    }
    
    int counter = 1;
    while (true) {
      final candidateName = '${baseName}_edited_$counter.mp4';
      candidatePath = '$directory\\$candidateName';
      if (!await File(candidatePath).exists()) {
        return candidatePath;
      }
      counter++;
    }
  }

  Future<void> _export() async {
    if (_videoPath == null) return;
    setState(() => _isLoading = true);
    final dir = await getDownloadsDirectory();
    
    final originalFileName = _videoPath!.split('\\').last;
    final nameWithoutExt = originalFileName.lastIndexOf('.') != -1
        ? originalFileName.substring(0, originalFileName.lastIndexOf('.'))
        : originalFileName;
    
    final baseName = nameWithoutExt;
    final outPath = await _getUniqueFilePath(dir!.path, baseName);
    
    final success = await FFmpegService.exportVideo(
      inputPath: _videoPath!,
      outputPath: outPath,
      audioTracks: _audioEnabled ? _audioTracks : [],
      mixAudio: _mixTracks,
      trimSeconds: _trimEnabled ? _trimSeconds : null,
      trimMode: _trimMode,
    );
    
    setState(() => _isLoading = false);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(success ? '✅ Экспорт завершён!\n$outPath' : '❌ Ошибка экспорта')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1a1a1a), Color(0xFF0d0d0d)],
          ),
        ),
        child: Column(
          children: [
            // Верхняя панель (только логотип)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text(
                    'SoViCut',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
            ),
            
            // Основная область
            Expanded(
              child: Row(
                children: [
                  // Preview Area (70%)
                  Expanded(
                    flex: 7,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: PreviewArea(
                          videoPath: _videoPath,
                          isDragging: _isDragging,
                          onTap: _pickVideo,
                          onDragEntered: () => setState(() => _isDragging = true),
                          onDragExited: () => setState(() => _isDragging = false),
                          onDragDone: (detail) {
                            setState(() => _isDragging = false);
                            if (detail.files.isNotEmpty) {
                              _loadVideo(detail.files.first.path!);
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                  // Tool Panel (30%)
                  Expanded(
                    flex: 3,
                    child: ToolPanel(
                      trimEnabled: _trimEnabled,
                      onTrimEnabledChanged: (val) => setState(() => _trimEnabled = val),
                      onTrimChanged: (seconds, mode) {
                        setState(() {
                          _trimSeconds = seconds;
                          _trimMode = mode;
                        });
                      },
                      trimSeconds: _trimSeconds,
                      trimMode: _trimMode,
                      audioEnabled: _audioEnabled,
                      onAudioEnabledChanged: (val) => setState(() => _audioEnabled = val),
                      audioTracks: _audioTracks,
                      onAudioTracksChanged: (tracks) => setState(() => _audioTracks = tracks),
                      mixEnabled: _mixTracks,
                      onMixEnabledChanged: (val) => setState(() => _mixTracks = val),
                      clips: _clips,
                      videoPath: _videoPath,
                    ),
                  ),
                ],
              ),
            ),
            
            // Нижняя панель: таймлайн слева, кнопка экспорта справа
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[900],
                border: Border(
                  top: BorderSide(color: Colors.grey[800]!, width: 1),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TimelineWidget(
                      clips: _clips,
                      onSplit: _splitClip,
                      onDelete: _deleteClip,
                      onRestore: _restoreClip,
                    ),
                  ),
                  Container(
                    width: 120,
                    padding: const EdgeInsets.all(8),
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _export,
                      icon: _isLoading
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.save, size: 16),
                      label: Text(_isLoading ? '...' : 'Экспорт'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}