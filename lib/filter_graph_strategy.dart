import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'audio_track.dart';
import 'clip.dart';
import 'export_settings_tab.dart';
import 'export_strategy.dart';
import 'ffmpeg_utils.dart';
import 'media_info_service.dart';
import 'core/localization/app_localizations.dart';

class FilterGraphStrategy implements ExportStrategy {
  final bool useFastPreset;

  FilterGraphStrategy({this.useFastPreset = false});

  @override
  String get name => useFastPreset ? 'Fast (filter graph)' : 'Quality (filter graph)';

  @override
  Future<bool> export({
    required String inputPath,
    required String outputPath,
    required List<AudioTrack> audioTracks,
    required bool mixAudio,
    double? trimSeconds,
    int? trimMode,
    required List<Clip> clips,
    ExportSettings? exportSettings,
    void Function(double progress, String stage)? onProgress,
    bool Function()? isCancelled,
  }) async {
    if (isCancelled != null && isCancelled()) return false;
    onProgress?.call(0, AppLocalizations.t('export.preparing'));

    final allStreams = await MediaInfoService.getAudioStreams(inputPath);
    final Map<int, int> absoluteToPerType = {};
    for (int i = 0; i < allStreams.length; i++) {
      absoluteToPerType[allStreams[i].index] = i;
    }

    final visibleClips = clips.where((c) => c.duration > 0 && c.isVisible).toList();
    if (visibleClips.isEmpty) return false;

    final int defaultBitrate = await _getAudioBitrate(inputPath);
    final int audioBitrate = exportSettings?.audioBitrate ?? (defaultBitrate ~/ 1000);
    final String audioCodec = exportSettings?.audioCodecName ?? 'aac';
    final int sampleRate = exportSettings?.sampleRate ?? 48000;
    final int channels = exportSettings?.channels ?? 2;
    final String videoCodec = exportSettings?.videoCodecName ?? 'libx264';
    final int crf = exportSettings?.crf ?? 23;

    final enabledAbsolute = audioTracks
        .where((t) => t.isEnabled)
        .map((t) => t.index)
        .toList();
    final enabledPerType = enabledAbsolute.isEmpty
        ? <int>[]
        : enabledAbsolute.map((abs) => absoluteToPerType[abs]!).toList();
    final hasAudio = enabledPerType.isNotEmpty;

    final totalOutputDuration =
        visibleClips.fold<double>(0.0, (s, c) => s + c.duration);

    onProgress?.call(0.05, AppLocalizations.t('export.encoding'));

    // Build -filter_complex argument
    final filterParts = <String>[];
    final n = visibleClips.length;

    // Video: trim each segment
    for (int i = 0; i < n; i++) {
      final c = visibleClips[i];
      filterParts.add(
        '[0:v]trim=start=${c.startTime}:end=${c.endTime},setpts=PTS-STARTPRES[v$i]',
      );
    }
    // Concat only if >1 segment (concat filter requires n>=2)
    final String videoOutputLabel;
    if (n > 1) {
      final vLabels = List.generate(n, (i) => '[v$i]').join();
      filterParts.add('${vLabels}concat=n=$n:v=1:a=0[vout]');
      videoOutputLabel = '[vout]';
    } else {
      videoOutputLabel = '[v0]';
    }

    // Audio: per-track atrim, then concat (only when >1 segment per track)
    final audioOutputLabels = <String>[];
    if (hasAudio) {
      for (int j = 0; j < enabledPerType.length; j++) {
        final perTypeIdx = enabledPerType[j];
        final track = audioTracks.firstWhere(
          (t) => t.index == allStreams[perTypeIdx].index,
        );
        final volumeFactor = track.volumePercent / 100;

        for (int i = 0; i < n; i++) {
          final c = visibleClips[i];
          filterParts.add(
            '[0:a:$perTypeIdx]atrim=start=${c.startTime}:end=${c.endTime},asetpts=PTS-STARTPRES[a${j}_$i]',
          );
        }

        final String trackLabel;
        if (n > 1) {
          final aSegLabels = List.generate(n, (i) => '[a${j}_$i]').join();
          filterParts.add('${aSegLabels}concat=n=$n:v=0:a=1[full_$j]');
          trackLabel = '[full_$j]';
        } else {
          trackLabel = '[a${j}_0]';
        }

        if (volumeFactor != 1.0) {
          filterParts.add('${trackLabel}volume=${volumeFactor.toStringAsFixed(4)}[atrack_$j]');
          audioOutputLabels.add('[atrack_$j]');
        } else {
          audioOutputLabels.add(trackLabel);
        }
      }

      // Mix if requested
      if (mixAudio && enabledPerType.length > 1) {
        final mixInputs = audioOutputLabels.join('');
        filterParts.add('${mixInputs}amix=inputs=${enabledPerType.length}:duration=longest[aout]');
      }
    }

    // Build ffmpeg args
    final List<String> args = [
      '-i', inputPath,
      '-filter_complex', filterParts.join(';'),
      '-map', videoOutputLabel,
    ];

    if (hasAudio) {
      if (mixAudio && enabledPerType.length > 1) {
        args.addAll(['-map', '[aout]']);
        final trackNames = enabledPerType.map((j) {
          final t = audioTracks.firstWhere(
            (tr) => tr.index == allStreams[j].index,
          );
          return t.name.isNotEmpty ? t.name : 'Track ${j + 1}';
        }).join(' + ');
        args.addAll(['-metadata:s:a:0', 'title=Mixed: $trackNames']);
      } else {
        for (int j = 0; j < enabledPerType.length; j++) {
          args.addAll(['-map', audioOutputLabels[j]]);
          final track = audioTracks.firstWhere(
            (t) => t.index == allStreams[enabledPerType[j]].index,
          );
          final title = track.name.isNotEmpty ? track.name : 'Track ${enabledPerType[j] + 1}';
          args.addAll(['-metadata:s:a:$j', 'title=$title']);
        }
      }
    } else {
      args.add('-an');
    }

    // Video encoder
    args.addAll([
      '-c:v', videoCodec,
      '-preset', useFastPreset ? 'ultrafast' : 'medium',
      '-crf', crf.toString(),
      '-vsync', 'cfr',
      '-pix_fmt', 'yuv420p',
    ]);

    // Audio encoder
    if (hasAudio) {
      args.addAll([
        '-c:a', audioCodec,
        '-b:a', '${audioBitrate}k',
        '-ar', sampleRate.toString(),
        '-ac', channels.toString(),
      ]);
    }

    // Output trimming
    double trimDuration = 0;
    final bool enableTrim = trimSeconds != null && trimSeconds > 0;
    if (enableTrim) {
      if (trimMode == 0) {
        trimDuration = trimSeconds;
      } else {
        trimDuration = (totalOutputDuration - trimSeconds).clamp(0.0, totalOutputDuration);
      }
      if (trimDuration > 0) {
        args.addAll(['-t', trimDuration.toStringAsFixed(2)]);
      }
    }

    args.addAll(['-movflags', '+faststart', '-y', outputPath]);

    // Run single ffmpeg process
    final progressTotal = enableTrim && trimDuration > 0 ? trimDuration : totalOutputDuration;
    final cancelNotifier = isCancelled != null ? ValueNotifier<bool>(false) : null;
    Timer? cancelTimer;
    if (cancelNotifier != null) {
      cancelTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
        if (isCancelled!()) cancelNotifier.value = true;
      });
    }
    final exitCode = await FFmpegUtils.runWithProgress(
      args: args,
      totalDuration: progressTotal,
      onProgress: (p) {
        onProgress?.call(0.05 + p * 0.94, AppLocalizations.t('export.encoding'));
      },
      cancel: cancelNotifier,
    );
    cancelTimer?.cancel();
    if (exitCode != 0) {
      return false;
    }

    onProgress?.call(1, AppLocalizations.t('export.success'));
    return true;
  }

  static Future<int> _getAudioBitrate(String path) async {
    try {
      final result = await Process.run('ffprobe', [
        '-v', 'error',
        '-show_entries', 'stream=codec_type,bit_rate',
        '-of', 'default=noprint_wrappers=1:nokey=1',
        path,
      ], runInShell: true);
      final lines = result.stdout.toString().split('\n');
      for (int i = 0; i < lines.length; i++) {
        if (lines[i] == 'audio' && i + 1 < lines.length) {
          final br = int.tryParse(lines[i + 1]);
          if (br != null && br > 0) return br;
        }
      }
    } catch (_) {}
    return 192000;
  }
}
