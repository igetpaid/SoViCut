import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/clip.dart';
import '../models/audio_track.dart';
import '../export_settings_tab.dart';

class ProjectData {
  final String videoPath;
  final List<Clip> clips;
  final List<AudioTrack> audioTracks;
  final bool audioEnabled;
  final bool mixEnabled;
  final bool trimEnabled;
  final double trimSeconds;
  final int trimMode;
  final ExportSettings exportSettings;
  final double previewPosition;

  const ProjectData({
    required this.videoPath,
    required this.clips,
    required this.audioTracks,
    required this.audioEnabled,
    required this.mixEnabled,
    required this.trimEnabled,
    required this.trimSeconds,
    required this.trimMode,
    required this.exportSettings,
    required this.previewPosition,
  });
}

class ProjectService {
  static const _extension = 'sovicat';

  static String get _projectDir => 'SoViCut';

  static Future<String> get _projectsPath async {
    final dir = await getApplicationDocumentsDirectory();
    final projectDir = Directory('${dir.path}\\$_projectDir');
    if (!await projectDir.exists()) {
      await projectDir.create(recursive: true);
    }
    return projectDir.path;
  }

  static Future<String> get projectsDirectory => _projectsPath;

  static Future<bool> saveProject({
    required String name,
    required ProjectData data,
  }) async {
    try {
      final dir = await _projectsPath;
      final path = '$dir\\$name.$_extension';

      final json = {
        'version': 2,
        'videoPath': data.videoPath,
        'previewPosition': data.previewPosition,
        'audio': {
          'enabled': data.audioEnabled,
          'mixEnabled': data.mixEnabled,
          'tracks': data.audioTracks.map((t) => t.toJson()).toList(),
        },
        'trim': {
          'enabled': data.trimEnabled,
          'seconds': data.trimSeconds,
          'mode': data.trimMode,
        },
        'clips': data.clips.map((c) => c.toJson()).toList(),
        'exportSettings': {
          'audioCodec': data.exportSettings.audioCodec.index,
          'bitrateMode': data.exportSettings.bitrateMode.index,
          'audioBitrate': data.exportSettings.audioBitrate,
          'sampleRate': data.exportSettings.sampleRate,
          'channels': data.exportSettings.channels,
          'videoCodec': data.exportSettings.videoCodec.index,
          'videoQuality': data.exportSettings.videoQuality.index,
          'crf': data.exportSettings.crf,
        },
      };

      final encoder = JsonEncoder.withIndent('  ');
      await File(path).writeAsString(encoder.convert(json));
      return true;
    } catch (e) {
      print('Error saving project: $e');
      return false;
    }
  }

  static Future<ProjectData?> loadProject(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return null;

      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;

      final videoPath = json['videoPath'] as String? ?? '';

      final audioData = json['audio'] as Map<String, dynamic>? ?? {};
      final audioTracks = (audioData['tracks'] as List? ?? [])
          .map((t) => AudioTrack.fromJson(t as Map<String, dynamic>))
          .toList();

      final trimData = json['trim'] as Map<String, dynamic>? ?? {};
      final clipsData = json['clips'] as List? ?? [];
      final clips = clipsData
          .map((c) => Clip.fromJson(c as Map<String, dynamic>))
          .toList();

      final exportData = json['exportSettings'] as Map<String, dynamic>? ?? {};

      return ProjectData(
        videoPath: videoPath,
        clips: clips,
        audioTracks: audioTracks,
        audioEnabled: audioData['enabled'] as bool? ?? false,
        mixEnabled: audioData['mixEnabled'] as bool? ?? false,
        trimEnabled: trimData['enabled'] as bool? ?? false,
        trimSeconds: (trimData['seconds'] as num?)?.toDouble() ?? 0,
        trimMode: trimData['mode'] as int? ?? 0,
        exportSettings: _parseExportSettings(exportData),
        previewPosition: (json['previewPosition'] as num?)?.toDouble() ?? 0,
      );
    } catch (e) {
      print('Error loading project: $e');
      return null;
    }
  }

  static ExportSettings _parseExportSettings(Map<String, dynamic> json) {
    return ExportSettings(
      audioCodec: AudioCodec.values[json['audioCodec'] as int? ?? 0],
      bitrateMode: BitrateMode.values[json['bitrateMode'] as int? ?? 0],
      audioBitrate: json['audioBitrate'] as int? ?? 192,
      sampleRate: json['sampleRate'] as int? ?? 48000,
      channels: json['channels'] as int? ?? 2,
      videoCodec: VideoCodec.values[json['videoCodec'] as int? ?? 0],
      videoQuality: VideoQuality.values[json['videoQuality'] as int? ?? 0],
      crf: json['crf'] as int? ?? 23,
    );
  }

  static Future<List<String>> listProjects() async {
    try {
      final dir = await _projectsPath;
      final files = await Directory(dir).list().toList();
      return files
          .where((f) => f.path.endsWith('.$_extension'))
          .map((f) => f.path)
          .toList();
    } catch (_) {
      return [];
    }
  }
}
