import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'audio_track.dart';
import 'clip.dart';
import 'ffmpeg_service.dart';
import 'tool_panel.dart';
import 'export_settings_tab.dart';
import 'export_strategy.dart';
import 'concat_strategy.dart';
import 'short_clips_dialog.dart';
import 'services/ffmpeg/ffmpeg_detection_service.dart';
import 'services/ffmpeg/thumbnail_service.dart';
import 'ui/home/toolbar.dart';
import 'ui/home/main_layout.dart';
import 'ui/preview/custom_player.dart';
import 'ui/timeline/timeline_bar.dart';
import 'core/localization/app_localizations.dart';
import 'providers/audio_provider.dart';
import 'providers/video_provider.dart';
import 'providers/clips_provider.dart';
import 'providers/export_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String? _videoPath;
  List<AudioTrack> _audioTracks = [];
  List<Clip> _clips = [];
  bool _isLoading = false;
  
  bool _trimEnabled = false;
  double _trimSeconds = 10;
  int _trimMode = 0;
  
  bool _audioEnabled = false;
  bool _mixTracks = false;
  
  int _originalAudioBitrate = 192000;
  int _originalSampleRate = 48000;
  int _originalChannels = 2;
  ExportSettings _exportSettings = ExportSettings.defaults(
    originalBitrate: 192000,
    originalSampleRate: 48000,
    originalChannels: 2,
  );
  
  double _previewPosition = 0;
  VideoPlayerController? _videoController;
  bool _isPlaying = false;
  int? _selectedClipIndex;
  AppMode _appMode = AppMode.single;
  List<ThumbnailEntry> _thumbnailEntries = [];

  @override
  void initState() {
    super.initState();
    _checkFfmpeg();
    _syncFromProviders();
  }

  void _syncFromProviders() {
    final audio = ref.read(audioProvider);
    final video = ref.read(videoProvider);
    final clips = ref.read(clipsProvider);
    final export = ref.read(exportProvider);

    _audioTracks = audio.tracks;
    _audioEnabled = audio.enabled;
    _mixTracks = audio.mixEnabled;
    if (video.path != null) _videoPath = video.path;
    _previewPosition = video.previewPosition;
    if (clips.clips.isNotEmpty) {
      _clips = clips.clips;
    }
    _exportSettings = export.settings;
  }

  void _syncToProviders() {
    ref.read(audioProvider.notifier).setTracks(_audioTracks);
    ref.read(audioProvider.notifier).setEnabled(_audioEnabled);
    ref.read(audioProvider.notifier).setMixEnabled(_mixTracks);
    ref.read(videoProvider.notifier).loadVideo(_videoPath ?? '');
    ref.read(videoProvider.notifier).setPreviewPosition(_previewPosition);
    ref.read(clipsProvider.notifier).setClips(_clips);
    ref.read(exportProvider.notifier).updateSettings(_exportSettings);
  }

  Future<void> _checkFfmpeg() async {
    final result = await FfmpegDetectionService.check();
    if (!result.allFound && mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(AppLocalizations.t('errors.ffmpegNotFound')),
          content: Text(
            AppLocalizations.t('errors.ffmpegNotFoundDesc'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(AppLocalizations.t('common.continue')),
            ),
          ],
        ),
      );
    }
  }

  double _getTotalDuration() {
    double total = 0;
    for (final clip in _clips) {
      if (clip.isVisible) {
        total += clip.duration;
      }
    }
    return total;
  }

  void _onTimelineCursorMoved(double timeInSeconds) {
    final totalDur = _getTotalDuration();
    if (totalDur <= 0) return;

    setState(() {
      _previewPosition = timeInSeconds / totalDur;
    });

    if (_videoController != null) {
      _videoController!.seekTo(_visibleTimeToFullTime(timeInSeconds));
    }
  }

  /// Преобразует время в видимой временной шкале в абсолютное время видео
  Duration _visibleTimeToFullTime(double visibleSeconds) {
    double accumulatedVisible = 0;
    for (final clip in _clips) {
      if (!clip.isVisible) continue;
      final clipDur = clip.duration;
      if (visibleSeconds <= accumulatedVisible + clipDur) {
        final offsetInClip = visibleSeconds - accumulatedVisible;
        return Duration(
          milliseconds: ((clip.startTime + offsetInClip) * 1000).toInt(),
        );
      }
      accumulatedVisible += clipDur;
    }
    // За пределами — последняя видимая точка
    final lastVisible = _clips.lastWhere(
      (c) => c.isVisible,
      orElse: () => _clips.last,
    );
    return Duration(milliseconds: (lastVisible.endTime * 1000).toInt());
  }

  /// Преобразует долю полного видео в долю видимой временной шкалы
  double _fullFractionToVisible(double fullFraction) {
    final fullMs = _videoController!.value.duration.inMilliseconds;
    final fullSec = (fullFraction * fullMs) / 1000.0;
    double visibleSec = 0;
    for (final clip in _clips) {
      if (!clip.isVisible) continue;
      if (fullSec >= clip.startTime && fullSec <= clip.endTime) {
        visibleSec += (fullSec - clip.startTime);
        final visTotal = _getTotalDuration();
        return visTotal > 0 ? visibleSec / visTotal : 0;
      }
      visibleSec += clip.duration;
    }
    return _previewPosition;
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
    
    if (!mounted) return;
    setState(() => _isLoading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(success ? '${AppLocalizations.t('export.success')}\n$outPath' : AppLocalizations.t('export.error'))),
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
    // Clean up old thumbnails
    if (_thumbnailEntries.isNotEmpty) {
      final oldDir = Directory(_thumbnailEntries.first.path).parent;
      ThumbnailService.cleanThumbnailDir(oldDir.path);
    }
    setState(() {
      _videoPath = path;
      _isLoading = true;
    });

    try {
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

      await _initVideoPlayer(path);

      // Generate thumbnails in background
      unawaited(_generateThumbnails(path, duration));

      setState(() {
        _audioTracks = tracks;
        _clips = clips;
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
        _thumbnailEntries = [];
      });
    } catch (e, stackTrace) {
      print('${AppLocalizations.t('player.error')}: $e');
      print(stackTrace);
      setState(() {
        _isLoading = false;
        _videoPath = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.t('player.error')}: $e'), backgroundColor: Colors.red),
        );
      }
    }
    _syncToProviders();
  }

  Future<void> _generateThumbnails(String path, double duration) async {
    final tempDir = '${Directory.systemTemp.path}\\sovicut_thumbs_${DateTime.now().millisecondsSinceEpoch}';
    final entries = await ThumbnailService.generateThumbnails(
      videoPath: path,
      outputDir: tempDir,
      duration: duration,
    );
    if (!mounted) return;
    setState(() => _thumbnailEntries = entries);
  }

  Future<void> _initVideoPlayer(String path) async {
    await _videoController?.dispose();
    final controller = VideoPlayerController.file(File(path));
    await controller.initialize();
    controller.addListener(() {
      if (!mounted) return;
      setState(() {
        _isPlaying = controller.value.isPlaying;
        if (controller.value.duration.inMilliseconds > 0) {
          final fullFraction = controller.value.position.inMilliseconds /
              controller.value.duration.inMilliseconds;
          _previewPosition = _fullFractionToVisible(fullFraction);
        }
      });
    });
    setState(() => _videoController = controller);
  }

  void _togglePlayPause() {
    if (_videoController == null) return;
    if (_isPlaying) {
      _videoController!.pause();
    } else {
      _videoController!.play();
    }
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

  void _onCloseVideo() {
    _videoController?.dispose();
    if (_thumbnailEntries.isNotEmpty) {
      final oldDir = Directory(_thumbnailEntries.first.path).parent;
      ThumbnailService.cleanThumbnailDir(oldDir.path);
    }
    setState(() {
      _videoController = null;
      _videoPath = null;
      _audioTracks = [];
      _clips = [];
      _previewPosition = 0;
      _isPlaying = false;
      _selectedClipIndex = null;
      _thumbnailEntries = [];
      _trimEnabled = false;
      _audioEnabled = false;
      _mixTracks = false;
    });
    _syncToProviders();
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

  @override
  Widget build(BuildContext context) {
    final fileName = _videoPath?.split('\\').last.split('/').last;

    return MainLayout(
      toolbar: Toolbar(
        currentMode: _appMode,
        onModeChanged: (mode) => setState(() => _appMode = mode),
        currentFileName: fileName,
        onExport: _export,
        isExporting: _isLoading,
        onCloseVideo: _videoPath != null ? _onCloseVideo : null,
      ),
      preview: DropTarget(
        onDragDone: (detail) {
          if (detail.files.isNotEmpty) {
            _loadVideo(detail.files.first.path);
          }
        },
        child: CustomPlayer(
          controller: _videoController,
          hasAudioChanges: _audioEnabled,
          onTapEmpty: _pickVideo,
        ),
      ),
      rightPanel: ToolPanel(
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
      timeline: TimelineBar(
        clips: _clips,
        totalDuration: _getTotalDuration(),
        cursorPosition: _previewPosition,
        selectedClipIndex: _selectedClipIndex,
        currentTime: _previewPosition * _getTotalDuration(),
        isPlaying: _isPlaying,
        onPlayPause: _togglePlayPause,
        onSeek: _onTimelineCursorMoved,
        thumbnails: _thumbnailEntries,
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