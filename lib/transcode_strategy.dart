import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'audio_track.dart';
import 'clip.dart';
import 'export_settings_tab.dart';
import 'export_strategy.dart';
import 'ffmpeg_utils.dart';
import 'media_info_service.dart';
import 'core/localization/app_localizations.dart';

class TranscodeStrategy implements ExportStrategy {
  @override
  String get name => AppLocalizations.t('strategy.fullTranscode');

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
    print('Original track names: ${allStreams.map((s) => '${s.index}: "${s.title}"').join(', ')}');

    final int defaultBitrate = await _getAudioBitrate(inputPath);
    final int audioBitrate = exportSettings?.audioBitrate ?? (defaultBitrate ~/ 1000);
    final String audioCodec = exportSettings?.audioCodecName ?? 'aac';
    final int sampleRate = exportSettings?.sampleRate ?? 48000;
    final int channels = exportSettings?.channels ?? 2;
    final String videoCodec = exportSettings?.videoCodecName ?? 'libx264';
    final int crf = exportSettings?.crf ?? 23;

    final activeClips = clips;
    if (activeClips.where((c) => c.duration > 0).isEmpty) return false;

    final totalDuration = activeClips.fold<double>(0, (s, c) => s + c.duration);
    if (totalDuration <= 0) return false;

    final enabledAbsolute = audioTracks
        .where((t) => t.isEnabled)
        .map((t) => t.index)
        .toList();
    final List<int> indicesToProcess = enabledAbsolute.isEmpty
        ? List.generate(allStreams.length, (i) => i)
        : enabledAbsolute.map((abs) => absoluteToPerType[abs]!).toList();
    final enabledTitles = indicesToProcess.map((i) => allStreams[i].title).toList();

    final List<String> tempFiles = [];
    double cumulativeProgress = 0;
    bool success = true;

    for (int i = 0; i < activeClips.length; i++) {
      if (isCancelled != null && isCancelled()) { success = false; break; }
      final clip = activeClips[i];
      final clipFraction = clip.duration / totalDuration;
      final tempPath = '${(await getTemporaryDirectory()).path}\\temp_${DateTime.now().millisecondsSinceEpoch}_$i.mp4';
      tempFiles.add(tempPath);

      final List<String> args = [
        '-i', inputPath,
        '-ss', clip.startTime.toStringAsFixed(6),
        '-t', clip.duration.toStringAsFixed(6),
        '-map', '0:v:0',
        '-c:v', videoCodec, '-crf', crf.toString(),
        '-vsync', 'cfr', '-pix_fmt', 'yuv420p',
        '-g', '12', '-keyint_min', '12',
      ];

      if (indicesToProcess.isNotEmpty) {
        if (mixAudio && indicesToProcess.length > 1) {
          final List<String> filterParts = [];
          final List<String> mixInputs = [];
          final List<String> trackNames = [];
          for (int j = 0; j < indicesToProcess.length; j++) {
            final perTypeIdx = indicesToProcess[j];
            final track = audioTracks.firstWhere((t) => t.index == allStreams[perTypeIdx].index);
            final factor = track.volumePercent / 100;
            final title = allStreams[perTypeIdx].title.isNotEmpty
                ? allStreams[perTypeIdx].title
                : 'Track ${perTypeIdx + 1}';
            trackNames.add(title);
            if (factor != 1.0) {
              filterParts.add('[0:a:$perTypeIdx]volume=${factor.toStringAsFixed(2)}[a$j]');
              mixInputs.add('[a$j]');
            } else {
              mixInputs.add('[0:a:$perTypeIdx]');
            }
          }
          final combinedFilters = <String>[
            ...filterParts,
            '${mixInputs.join('')}amix=inputs=${mixInputs.length}:duration=longest[aout]',
          ];
          args.addAll([
            '-filter_complex', combinedFilters.join('; '),
            '-map', '[aout]',
            '-metadata:s:a:0', 'title=Mixed: ${trackNames.join(" + ")}',
            '-c:a', audioCodec, '-b:a', '${audioBitrate}k',
            '-ar', sampleRate.toString(), '-ac', channels.toString(),
          ]);
        } else {
          for (int j = 0; j < indicesToProcess.length; j++) {
            final perTypeIdx = indicesToProcess[j];
            args.addAll(['-map', '0:a:$perTypeIdx']);
            final title = allStreams[perTypeIdx].title.isNotEmpty
                ? allStreams[perTypeIdx].title
                : 'Track ${perTypeIdx + 1}';
            args.addAll(['-metadata:s:a:$j', 'title=$title']);
          }
          args.addAll([
            '-c:a', audioCodec, '-b:a', '${audioBitrate}k',
            '-ar', sampleRate.toString(), '-ac', channels.toString(),
          ]);
        }
      } else {
        // No audio tracks enabled - just copy none
        args.addAll(['-an']);
      }

      args.addAll(['-movflags', '+faststart', '-y', tempPath]);

      print('Clip ${i+1}: ffmpeg ${args.join(' ')}');
      final clipResult = await FFmpegUtils.runWithProgress(
        args: args,
        totalDuration: clip.duration,
        onProgress: (p) {
          onProgress?.call(
            cumulativeProgress + p * clipFraction * 0.95,
            AppLocalizations.t('export.encoding'),
          );
        },
      );
      if (clipResult != 0) {
        print('Error encoding clip ${i+1}');
        success = false;
        break;
      }

      final tempFile = File(tempPath);
      if (!await tempFile.exists() || await tempFile.length() < 1024) {
        print('Clip ${i+1} too small or missing');
        success = false;
        break;
      }

      cumulativeProgress += clipFraction * 0.95;
      onProgress?.call(cumulativeProgress, AppLocalizations.t('export.encoding'));
    }

    if (!success) {
      for (final f in tempFiles) { try { await File(f).delete(); } catch (_) {} }
      return false;
    }

    if (isCancelled != null && isCancelled()) {
      for (final f in tempFiles) { try { await File(f).delete(); } catch (_) {} }
      return false;
    }

    // Concatenation
    final concatDir = await Directory.systemTemp.createTemp('sovicut_concat_final');
    final concatPath = '${concatDir.path}\\concat.txt';
    final concatFile = File(concatPath);
    final contentBuf = StringBuffer();
    for (final file in tempFiles) {
      contentBuf.writeln("file '$file'");
    }
    await concatFile.writeAsString(contentBuf.toString());

    final firstInfo = await MediaInfoService.getMediaInfo(tempFiles.first);
    final int audioCount = firstInfo.audioStreams.length;
    print('Audio streams in segments: $audioCount');

    final List<String> concatArgs = [
      '-f', 'concat', '-safe', '0', '-i', concatPath,
      '-map', '0:v:0',
    ];
    for (int i = 0; i < audioCount; i++) {
      concatArgs.addAll(['-map', '0:a:$i']);
    }
    concatArgs.addAll(['-c:v', 'copy', '-c:a', 'copy', '-movflags', '+faststart']);

    for (int i = 0; i < audioCount && i < enabledTitles.length; i++) {
      if (enabledTitles[i].isNotEmpty) {
        concatArgs.addAll(['-metadata:s:a:$i', 'title=${enabledTitles[i]}']);
      }
    }

    if (trimSeconds != null && trimSeconds > 0 && trimMode == 0) {
      concatArgs.insertAll(3, ['-t', trimSeconds.toStringAsFixed(2)]);
    }

    concatArgs.addAll(['-y', outputPath]);

    onProgress?.call(0.95, AppLocalizations.t('export.encoding'));
    print('Concat: ffmpeg ${concatArgs.join(' ')}');
    final concatResult = await Process.run('ffmpeg', concatArgs, runInShell: true);

    for (final f in tempFiles) { try { await File(f).delete(); } catch (_) {} }
    try { await concatDir.delete(recursive: true); } catch (_) {}

    if (concatResult.exitCode != 0) {
      print('Concat error: ${concatResult.stderr}');
      return false;
    }

    onProgress?.call(1, AppLocalizations.t('export.success'));
    print('Export complete: $outputPath');
    return true;
  }

  static Future<int> _getAudioBitrate(String path) async {
    try {
      final result = await Process.run('ffprobe', [
        '-v', 'error',
        '-show_entries', 'stream=codec_type,bit_rate',
        '-of', 'default=noprint_wrappers=1:nokey=1',
        path
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