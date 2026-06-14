import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'transcode_strategy.dart';
import 'services/ffmpeg/ffmpeg_detection_service.dart';
import 'services/ffmpeg/thumbnail_service.dart';
import 'ui/home/toolbar.dart';
import 'ui/home/main_layout.dart';
import 'ui/preview/custom_player.dart';
import 'ui/timeline/timeline_bar.dart';
import 'core/localization/app_localizations.dart';
import 'core/theme/app_colors.dart';
import 'ui/batch/batch_screen.dart';
import 'services/project_service.dart';
import 'providers/audio_provider.dart';
import 'providers/video_provider.dart';
import 'providers/clips_provider.dart';
import 'providers/export_provider.dart';
import 'ui/settings/settings_panel.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
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
  late TabController _tabController;

  // Export progress (non-blocking)
  bool _isExporting = false;
  double _exportProgress = 0;
  String _exportStage = '';
  bool _exportCancelled = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _checkFfmpeg();
    _syncFromProviders();
    HardwareKeyboard.instance.addHandler(_onKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKeyEvent);
    _tabController.dispose();
    super.dispose();
  }

  bool _onKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (_appMode == AppMode.batch) return false;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.keyS) {
      _splitCurrentClip();
      return true;
    }
    if (key == LogicalKeyboardKey.keyD) {
      if (_selectedClipIndex != null && _selectedClipIndex! < _clips.length) {
        _deleteClip(_selectedClipIndex!);
      }
      return true;
    }
    if (key == LogicalKeyboardKey.keyA) {
      if (_selectedClipIndex != null && _selectedClipIndex! < _clips.length) {
        _restoreClip(_selectedClipIndex!);
      }
      return true;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      _onSeekStep(true);
      return true;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      _onSeekStep(false);
      return true;
    }
    return false;
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
    _clips = clips.clips.isNotEmpty ? clips.clips : [];
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
          content: Text(AppLocalizations.t('errors.ffmpegNotFoundDesc')),
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
      total += clip.duration;
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
      _videoController!.seekTo(_fullTimeToVideoTime(timeInSeconds));
    }
  }

  /// Преобразует абсолютное время полной шкалы в абсолютное время видео.
  /// Если позиция попадает в скрытый фрагмент, перескакивает на начало следующего видимого.
  Duration _fullTimeToVideoTime(double fullSeconds) {
    for (final clip in _clips) {
      if (fullSeconds >= clip.startTime && fullSeconds <= clip.endTime) {
        if (clip.isVisible) {
          return Duration(milliseconds: (fullSeconds * 1000).toInt());
        }
        // Hidden clip — skip to next visible
        for (final nextClip in _clips) {
          if (nextClip.startTime > clip.endTime && nextClip.isVisible) {
            return Duration(milliseconds: (nextClip.startTime * 1000).toInt());
          }
        }
        // No more visible clips — jump to end
        return Duration(milliseconds: (clip.endTime * 1000).toInt());
      }
    }
    return Duration.zero;
  }

  /// Преобразует долю полного видео в абсолютное время для плеера.

  Future<void> _exportWithStrategy(ExportStrategy strategy) async {
    if (_videoPath == null) return;

    setState(() {
      _isExporting = true;
      _exportCancelled = false;
      _exportProgress = 0;
      _exportStage = AppLocalizations.t('export.preparing');
    });

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
      isCancelled: () => _exportCancelled,
      onProgress: (p, s) {
        if (!mounted) return;
        setState(() {
          _exportProgress = p;
          _exportStage = s;
        });
      },
    );

    if (!mounted) return;
    setState(() {
      _isExporting = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? '${AppLocalizations.t('export.success')}\n$outPath'
              : AppLocalizations.t('export.error'),
        ),
      ),
    );
  }

  void _cancelExport() {
    _exportCancelled = true;
  }

  void _openSettings() {
    showDialog(
      context: context,
      builder: (ctx) => const SettingsPanel(),
    );
  }

  Future<void> _saveProject() async {
    if (_videoPath == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.t('project.openVideoFirst'))),
        );
      }
      return;
    }

    _syncToProviders();

    final originalFileName = _videoPath!.split('\\').last.split('/').last;
    final nameWithoutExt = originalFileName.lastIndexOf('.') != -1
        ? originalFileName.substring(0, originalFileName.lastIndexOf('.'))
        : originalFileName;

    final success = await ProjectService.saveProject(
      name: nameWithoutExt,
      data: ProjectData(
        videoPath: _videoPath!,
        clips: _clips,
        audioTracks: _audioTracks,
        audioEnabled: _audioEnabled,
        mixEnabled: _mixTracks,
        trimEnabled: _trimEnabled,
        trimSeconds: _trimSeconds,
        trimMode: _trimMode,
        exportSettings: _exportSettings,
        previewPosition: _previewPosition,
      ),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? AppLocalizations.t('project.saveSuccess')
                : AppLocalizations.t('project.error'),
          ),
        ),
      );
    }
  }

  Future<void> _openProject() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['sovicat'],
    );
    if (result == null || result.files.isEmpty) return;

    final data = await ProjectService.loadProject(result.files.first.path!);
    if (data == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.t('project.error'))),
        );
      }
      return;
    }

    // Check if video file exists
    if (!File(data.videoPath).existsSync()) {
      if (mounted) {
        final locate = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(
              AppLocalizations.t('project.fileNotFound', {
                'path': data.videoPath,
              }),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(AppLocalizations.t('common.cancel')),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(AppLocalizations.t('project.locateFile')),
              ),
            ],
          ),
        );
        if (locate == true) {
          final pickResult = await FilePicker.platform.pickFiles(
            type: FileType.video,
          );
          if (pickResult == null || pickResult.files.isEmpty) return;
          final newPath = pickResult.files.first.path!;
          await _loadVideo(newPath);
        } else {
          return;
        }
      } else {
        return;
      }
    } else {
      await _loadVideo(data.videoPath);
    }

    // Apply project state
    setState(() {
      _audioTracks = data.audioTracks;
      _audioEnabled = data.audioEnabled;
      _mixTracks = data.mixEnabled;
      _trimEnabled = data.trimEnabled;
      _trimSeconds = data.trimSeconds;
      _trimMode = data.trimMode;
      _exportSettings = data.exportSettings;
      _previewPosition = data.previewPosition;
      _clips = data.clips;
    });

    if (_videoController != null) {
      _videoController!.seekTo(
        Duration(
          milliseconds: (_previewPosition * _getTotalDuration() * 1000).toInt(),
        ),
      );
    }

    _syncToProviders();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.t('project.openSuccess'))),
      );
    }
  }

  Future<void> _exportFast() async {
    if (_videoPath == null) return;
    await _exportWithStrategy(ConcatStrategy());
  }

  Future<void> _exportQuality() async {
    if (_videoPath == null) return;
    await _exportWithStrategy(TranscodeStrategy());
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
          SnackBar(
            content: Text('${AppLocalizations.t('player.error')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    _syncToProviders();
  }

  Future<void> _generateThumbnails(String path, double duration) async {
    final tempDir =
        '${Directory.systemTemp.path}\\sovicut_thumbs_${DateTime.now().millisecondsSinceEpoch}';
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
          final fullFraction =
              controller.value.position.inMilliseconds /
              controller.value.duration.inMilliseconds;
          _previewPosition = fullFraction;
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
    final result = await Process.run('ffprobe', [
      '-v',
      'error',
      '-show_entries',
      'format=duration',
      '-of',
      'default=noprint_wrappers=1:nokey=1',
      path,
    ], runInShell: true);
    return double.parse(result.stdout.toString().trim());
  }

  Future<AudioInfo> _getAudioInfo(String path) async {
    final result = await Process.run('ffprobe', [
      '-v',
      'error',
      '-show_entries',
      'stream=codec_type,bit_rate,sample_rate,channels',
      '-of',
      'default=noprint_wrappers=1',
      path,
    ], runInShell: true);

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

    return AudioInfo(
      bitrate: bitrate,
      sampleRate: sampleRate,
      channels: channels,
    );
  }

  void _splitCurrentClip() {
    // Find the visible clip at the current position
    double accum = 0;
    for (int i = 0; i < _clips.length; i++) {
      final clip = _clips[i];
      if (!clip.isVisible) continue;
      final clipEnd = accum + clip.duration;
      final currentTime = _previewPosition * _getTotalDuration();
      if (currentTime >= accum && currentTime <= clipEnd) {
        final splitTimeInClip = currentTime - accum;
        if (splitTimeInClip < 0.1 || clip.duration - splitTimeInClip < 0.1) {
          return; // too close to edge
        }
        setState(() {
          final newClip = Clip(
            id: _nextClipId,
            sourcePath: clip.sourcePath,
            startTime: clip.startTime + splitTimeInClip,
            endTime: clip.endTime,
            isVisible: true,
          );
          clip.endTime = clip.startTime + splitTimeInClip;
          _clips.insert(i + 1, newClip);
          _nextClipId++;
        });
        _syncToProviders();
        return;
      }
      accum += clip.duration;
    }
  }

  int _nextClipId = 1;

  void _deleteClip(int clipIndex) {
    if (clipIndex < 0 || clipIndex >= _clips.length) return;
    setState(() {
      _clips[clipIndex].isVisible = false;
    });
    _syncToProviders();
    _tabController.animateTo(2);
  }

  void _restoreClip(int clipIndex) {
    if (clipIndex < 0 || clipIndex >= _clips.length) return;
    setState(() {
      _clips[clipIndex].isVisible = true;
    });
    _syncToProviders();
    _tabController.animateTo(2);
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

  static const List<double> _stepSizes = [1 / 30, 0.1, 0.5, 1, 5, 10];
  double _seekStepSize = 1.0;

  void _onSeekStep(bool forward) {
    final step = forward ? _seekStepSize : -_seekStepSize;
    final total = _getTotalDuration();
    final newTime = ((_previewPosition * total) + step).clamp(0.0, total);
    _onTimelineCursorMoved(newTime);
  }

  @override
  Widget build(BuildContext context) {
    final fileName = _videoPath?.split('\\').last.split('/').last;
    final total = _getTotalDuration();

    return _appMode == AppMode.batch
        ? Scaffold(body: BatchScreen())
        : Column(
            children: [
              Expanded(
                child: MainLayout(
                    toolbar: Toolbar(
                      currentMode: _appMode,
                      onModeChanged: (mode) => setState(() => _appMode = mode),
                      currentFileName: fileName,
                      onFastExport: _exportFast,
                      onQualityExport: _exportQuality,
                      isExporting: _isLoading,
                      onCloseVideo: _videoPath != null ? _onCloseVideo : null,
                      onSaveProject: _videoPath != null ? _saveProject : null,
                      onOpenProject: _openProject,
                      onOpenSettings: _openSettings,
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
                    tabController: _tabController,
                    trimEnabled: _trimEnabled,
                    onTrimEnabledChanged: (val) =>
                        setState(() => _trimEnabled = val),
                    onTrimChanged: (seconds, mode) {
                      setState(() {
                        _trimSeconds = seconds;
                        _trimMode = mode;
                      });
                    },
                    trimSeconds: _trimSeconds,
                    trimMode: _trimMode,
                    audioEnabled: _audioEnabled,
                    onAudioEnabledChanged: (val) =>
                        setState(() => _audioEnabled = val),
                    audioTracks: _audioTracks,
                    onAudioTracksChanged: (tracks) =>
                        setState(() => _audioTracks = tracks),
                    mixEnabled: _mixTracks,
                    onMixEnabledChanged: (val) =>
                        setState(() => _mixTracks = val),
                    clips: _clips,
                    videoPath: _videoPath,
                    onDeleteClip: _deleteClip,
                    onRestoreClip: _restoreClip,
                    onSelectClip: (index) =>
                        setState(() => _selectedClipIndex = index),
                    selectedClipIndex: _selectedClipIndex,
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
                    totalDuration: total,
                    cursorPosition: _previewPosition,
                    selectedClipIndex: _selectedClipIndex,
                    currentTime: _previewPosition * total,
                    isPlaying: _isPlaying,
                    onPlayPause: _togglePlayPause,
                    onSeek: _onTimelineCursorMoved,
                    onSelectClip: (index) =>
                        setState(() => _selectedClipIndex = index),
                    thumbnails: _thumbnailEntries,
                  ), // TimelineBar
                ), // MainLayout
              ), // Expanded
              if (_clips.isNotEmpty) _buildTimelineActions(),
              if (_isExporting) _buildExportProgressBar(),
              _buildStepSlider(),
            ],
          );
  }

  Widget _buildTimelineActions() {
    final selIdx = _selectedClipIndex;
    final clip = selIdx != null && selIdx < _clips.length
        ? _clips[selIdx]
        : null;
    return Container(
      height: 32,
      color: AppColors.timelineBg,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          _actionsButton(
            icon: Icons.content_cut,
            label: 'Split',
            tooltip: 'Split (S)',
            onTap: _splitCurrentClip,
            color: AppColors.accent,
          ),
          const SizedBox(width: 4),
          _actionsButton(
            icon: Icons.visibility_off,
            label: 'Delete',
            tooltip: 'Delete (D)',
            onTap: clip != null && clip.isVisible
                ? () => _deleteClip(selIdx!)
                : null,
            color: AppColors.error,
          ),
          const SizedBox(width: 4),
          _actionsButton(
            icon: Icons.visibility,
            label: 'Restore',
            tooltip: 'Restore (A)',
            onTap: clip != null && !clip.isVisible
                ? () => _restoreClip(selIdx!)
                : null,
            color: const Color(0xFF4CAF50),
          ),
        ],
      ),
    );
  }

  Widget _actionsButton({
    required IconData icon,
    required String label,
    required String tooltip,
    required VoidCallback? onTap,
    required Color color,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          height: 26,
          decoration: BoxDecoration(
            color: color.withValues(alpha: onTap != null ? 0.15 : 0.05),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 12,
                color: onTap != null ? color : color.withValues(alpha: 0.3),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: onTap != null ? color : color.withValues(alpha: 0.3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExportProgressBar() {
    return Container(
      height: 32,
      color: AppColors.timelineBg,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              _exportStage,
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: _exportProgress,
                minHeight: 6,
                backgroundColor: AppColors.border,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 36,
            child: Text(
              '${(_exportProgress * 100).toInt()}%',
              style: TextStyle(fontSize: 10, color: AppColors.textDim),
            ),
          ),
          const SizedBox(width: 4),
          _stepButton(Icons.close, _cancelExport),
        ],
      ),
    );
  }

  Widget _buildStepSlider() {
    return Container(
      height: 28,
      color: AppColors.timelineBg,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Text(
            'Step:',
            style: TextStyle(fontSize: 10, color: AppColors.textDim),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Row(
              children: List.generate(_stepSizes.length, (i) {
                final isSelected = _seekStepSize == _stepSizes[i];
                String label;
                if (_stepSizes[i] >= 1) {
                  label = '${_stepSizes[i].toInt()}s';
                } else if (_stepSizes[i] == 0.1) {
                  label = '0.1s';
                } else {
                  label = '1f';
                }
                return GestureDetector(
                  onTap: () => setState(() => _seekStepSize = _stepSizes[i]),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.textDim.withValues(alpha: 0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 10,
                        color: isSelected
                            ? AppColors.textSecondary
                            : AppColors.textDim,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(width: 8),
          _stepButton(Icons.skip_previous, () => _onSeekStep(false)),
          _stepButton(Icons.skip_next, () => _onSeekStep(true)),
        ],
      ),
    );
  }

  Widget _stepButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onTap,
        child: Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          child: Icon(icon, size: 14, color: AppColors.textDim),
        ),
      ),
    );
  }
}

class AudioInfo {
  final int bitrate;
  final int sampleRate;
  final int channels;
  AudioInfo({
    required this.bitrate,
    required this.sampleRate,
    required this.channels,
  });
}
