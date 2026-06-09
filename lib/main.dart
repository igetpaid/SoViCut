import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:path_provider/path_provider.dart';
import 'models/audio_track.dart';
import 'widgets/trim_widget.dart';
import 'widgets/audio_panel.dart';
import 'services/ffmpeg_service.dart';

void main() => runApp(const SoViCutApp());

class SoViCutApp extends StatelessWidget {
  const SoViCutApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SoViCut',
      theme: ThemeData.dark().copyWith(primaryColor: Colors.orange),
      home: const MainScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  String? _videoPath;
  List<AudioTrack> _audioTracks = [];
  bool _isLoading = false;
  bool _isDragging = false;
  
  bool _trimEnabled = false;
  double _trimSeconds = 0;
  int _trimMode = 0;
  
  bool _audioEnabled = false;
  bool _mixTracks = false;

  void _loadVideo(String path) async {
    setState(() {
      _videoPath = path;
      _isLoading = true;
    });
    final tracks = await FFmpegService.analyzeAudio(path);
    setState(() {
      _audioTracks = tracks;
      _isLoading = false;
    });
  }

  Future<void> _export() async {
    if (_videoPath == null) return;
    setState(() => _isLoading = true);
    final dir = await getDownloadsDirectory();
    final outPath = '${dir!.path}\\${DateTime.now().millisecondsSinceEpoch}_exported.mp4';
    
    print('=== ЭКСПОРТ ===');
    print('_trimEnabled: $_trimEnabled');
    print('_trimSeconds: $_trimSeconds');
    print('_trimMode: $_trimMode');
    print('_audioEnabled: $_audioEnabled');
    print('_mixTracks: $_mixTracks');
    
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
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Text('SoViCut', style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.orange)),
                const SizedBox(height: 40),
                
                DropTarget(
                  onDragEntered: (_) => setState(() => _isDragging = true),
                  onDragExited: (_) => setState(() => _isDragging = false),
                  onDragDone: (detail) {
                    setState(() => _isDragging = false);
                    if (detail.files.isNotEmpty) _loadVideo(detail.files.first.path!);
                  },
                  child: Container(
                    height: 120,
                    decoration: BoxDecoration(
                      color: _isDragging ? Colors.orange.withOpacity(0.2) : Colors.grey[900],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _isDragging ? Colors.orange : Colors.grey[800]!, width: 2),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(_isDragging ? Icons.file_upload : Icons.drag_handle, size: 40, color: Colors.grey[600]),
                        const SizedBox(height: 8),
                        Text(_isDragging ? 'Отпустите' : 'Перетащите видео сюда', style: TextStyle(color: Colors.grey[500])),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () async {
                    final result = await FilePicker.platform.pickFiles(type: FileType.video);
                    if (result != null) _loadVideo(result.files.single.path!);
                  },
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Выбрать видео'),
                ),
                
                if (_videoPath != null) ...[
                  const SizedBox(height: 24),
                  Text(_videoPath!.split('\\').last, style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 24),
                  
                  TrimWidget(
                    isEnabled: _trimEnabled,
                    onEnabledChanged: (val) => setState(() => _trimEnabled = val),
                    onTrimChanged: (seconds, mode) {
                    print('=== MAIN: received seconds=$seconds, mode=$mode ===');
                    _trimSeconds = seconds;
                    _trimMode = mode;
                    },
                  ),
                  const SizedBox(height: 20),
                  
                  AudioPanel(
                    isEnabled: _audioEnabled,
                    onEnabledChanged: (val) => setState(() => _audioEnabled = val),
                    tracks: _audioTracks,
                    onTracksChanged: (tracks) => setState(() => _audioTracks = tracks),
                    mixEnabled: _mixTracks,
                    onMixEnabledChanged: (val) => setState(() => _mixTracks = val),
                  ),
                  const SizedBox(height: 20),
                  
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _export,
                    icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save),
                    label: Text(_isLoading ? 'Обработка...' : 'Экспортировать'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.black,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}