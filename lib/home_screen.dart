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
import 'export_settings_tab.dart';
import 'export_strategy.dart';
import 'concat_strategy.dart';
import 'transcode_strategy.dart';
import 'short_clips_dialog.dart';

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
  
  int _nextClipId = 1;
  
  int _originalAudioBitrate = 192000;
  int _originalSampleRate = 48000;
  int _originalChannels = 2;
  ExportSettings _exportSettings = ExportSettings.defaults(
    originalBitrate: 192000,
    originalSampleRate: 48000,
    originalChannels: 2,
  );
  
  double _previewPosition = 0;

  double _getTotalDuration() {
    double total = 0;
    for (final clip in _clips) {
      if (clip.isVisible) {
        total += clip.duration;
      }
    }
    return total;
  }

  void _onPreviewPositionChanged(double position) {
    setState(() {
      _previewPosition = position;
    });
  }

  void _onTimelineCursorMoved(double timeInSeconds) {
    final totalDur = _getTotalDuration();
    if (totalDur > 0) {
      setState(() {
        _previewPosition = timeInSeconds / totalDur;
      });
    }
  }

  /// Проверяет наличие коротких фрагментов (< 0.5 сек)
  ShortClipCheckResult _checkShortClips() {
    final List<int> shortIndices = [];
    final List<double> shortDurations = [];
    for (int i = 0; i < _clips.length; i++) {
      final clip = _clips[i];
      if (clip.isVisible && clip.duration < 0.5) {
        shortIndices.add(i);
        shortDurations.add(clip.duration);
      }
    }
    return ShortClipCheckResult(
      hasShortClips: shortIndices.isNotEmpty,
      shortClipIndices: shortIndices,
      shortClipDurations: shortDurations,
      threshold: 0.5,
    );
  }

  Future<void> _exportWithStrategy(ExportStrategy strategy) async {
    if (_videoPath == null) return;
    
    setState(() => _isLoading = true);
    
    final dir = await getDownloadsDirectory();
    final originalFileName = _videoPath!.split('\\').last;
    final nameWithoutExt = originalFileName.lastIndexOf('.') != -1
        ? originalFileName.substring(0, originalFileName.lastIndexOf('.'))
        : originalFileName;
    final baseName = nameWithoutExt;
    final outPath = await _getUniqueFilePath(dir!.path, baseName);
    
    final success = await strategy.export(
      inputPath: _videoPath!,
      outputPath: outPath,
      audioTracks: _audioEnabled ? _audioTracks : [],
      mixAudio: _mixTracks,
      trimSeconds: _trimEnabled ? _trimSeconds : null,
      trimMode: _trimMode,
      clips: _clips,
      exportSettings: _exportSettings,
    );
    
    setState(() => _isLoading = false);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(success ? '✅ Экспорт завершён!\n$outPath' : '❌ Ошибка экспорта')),
    );
  }

  Future<void> _export() async {
    if (_videoPath == null) return;
    
    final shortClipsCheck = _checkShortClips();
    
    if (shortClipsCheck.hasShortClips) {
      // Показываем диалог выбора стратегии
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => ShortClipsDialog(
          checkResult: shortClipsCheck,
          onStrategySelected: (strategy) {
            Navigator.pop(context);
            _exportWithStrategy(strategy);
          },
          onCancel: () {
            Navigator.pop(context);
          },
        ),
      );
    } else {
      // Нет коротких фрагментов — используем стандартную стратегию ConcatStrategy
      await _exportWithStrategy(ConcatStrategy());
    }
  }

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
    final audioInfo = await _getAudioInfo(path);
    
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
      _nextClipId = 1;
      _originalAudioBitrate = audioInfo.bitrate;
      _originalSampleRate = audioInfo.sampleRate;
      _originalChannels = audioInfo.channels;
      _exportSettings = ExportSettings.defaults(
        originalBitrate: audioInfo.bitrate,
        originalSampleRate: audioInfo.sampleRate,
        originalChannels: audioInfo.channels,
      );
      _previewPosition = 0;
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

  Future<AudioInfo> _getAudioInfo(String path) async {
    final result = await Process.run(
      'ffprobe',
      [
        '-v', 'error',
        '-show_entries', 'stream=codec_type,bit_rate,sample_rate,channels',
        '-of', 'default=noprint_wrappers=1',
        path
      ],
      runInShell: true,
    );
    
    int bitrate = 192000;
    int sampleRate = 48000;
    int channels = 2;
    
    final lines = result.stdout.toString().split('\n');
    for (int i = 0; i < lines.length; i++) {
      if (lines[i].contains('codec_type=audio')) {
        if (i + 1 < lines.length && lines[i + 1].startsWith('bit_rate=')) {
          final br = int.tryParse(lines[i + 1].split('=')[1]);
          if (br != null && br > 0) bitrate = br;
        }
        if (i + 2 < lines.length && lines[i + 2].startsWith('sample_rate=')) {
          final sr = int.tryParse(lines[i + 2].split('=')[1]);
          if (sr != null && sr > 0) sampleRate = sr;
        }
        if (i + 3 < lines.length && lines[i + 3].startsWith('channels=')) {
          final ch = int.tryParse(lines[i + 3].split('=')[1]);
          if (ch != null && ch > 0) channels = ch;
        }
        break;
      }
    }
    
    return AudioInfo(bitrate: bitrate, sampleRate: sampleRate, channels: channels);
  }

  void _splitClip(int clipIndex, double splitTimeInClip) {
    if (clipIndex < 0 || clipIndex >= _clips.length) return;
    final clip = _clips[clipIndex];
    if (!clip.isVisible) return;
    
    final splitAbsolute = clip.startTime + splitTimeInClip;
    
    final newClips = List<Clip>.from(_clips);
    final clip1 = Clip(
      id: _nextClipId++,
      sourcePath: clip.sourcePath,
      startTime: clip.startTime,
      endTime: splitAbsolute,
      isVisible: true,
    );
    final clip2 = Clip(
      id: _nextClipId++,
      sourcePath: clip.sourcePath,
      startTime: splitAbsolute,
      endTime: clip.endTime,
      isVisible: true,
    );
    newClips.removeAt(clipIndex);
    newClips.insert(clipIndex, clip2);
    newClips.insert(clipIndex, clip1);
    
    setState(() {
      _clips = newClips;
    });
  }

  void _deleteClip(int clipIndex) {
    if (clipIndex < 0 || clipIndex >= _clips.length) return;
    setState(() {
      _clips[clipIndex].isVisible = false;
    });
  }

  void _restoreClip(int clipIndex) {
    if (clipIndex < 0 || clipIndex >= _clips.length) return;
    setState(() {
      _clips[clipIndex].isVisible = true;
    });
  }

  void _selectClip(int clipIndex, double cursorInClip) {}

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
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text(
                    'SoViCut',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.orange),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Row(
                children: [
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
                          clips: _clips,
                          cursorPosition: _previewPosition,
                          onPositionChanged: _onPreviewPositionChanged,
                        ),
                      ),
                    ),
                  ),
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
                      onDeleteClip: _deleteClip,
                      onRestoreClip: _restoreClip,
                      originalAudioBitrate: _originalAudioBitrate,
                      originalSampleRate: _originalSampleRate,
                      originalChannels: _originalChannels,
                      onExportSettingsChanged: (settings) {
                        setState(() {
                          _exportSettings = settings;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
            TimelineWidget(
              clips: _clips,
              onSplit: (index, splitTime) => _splitClip(index, splitTime),
              onDelete: _deleteClip,
              onRestore: _restoreClip,
              onSelectClip: _selectClip,
              onCursorMoved: _onTimelineCursorMoved,
              externalCursorPosition: _previewPosition,
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[900],
                border: Border(top: BorderSide(color: Colors.grey[800]!, width: 1)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    SizedBox(
                      width: 120,
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
            ),
          ],
        ),
      ),
    );
  }
}

class AudioInfo {
  final int bitrate;
  final int sampleRate;
  final int channels;
  AudioInfo({required this.bitrate, required this.sampleRate, required this.channels});
}