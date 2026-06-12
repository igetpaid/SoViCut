import 'dart:io';
import 'package:flutter/foundation.dart';
import 'audio_track.dart';
import 'clip.dart';
import 'export_settings_tab.dart';
import 'export_strategy.dart';
import 'ffmpeg_utils.dart';
import 'media_info_service.dart';
import 'core/localization/app_localizations.dart';

class ConcatStrategy implements ExportStrategy {
  @override
  String get name => AppLocalizations.t('dialog.roundToKeyframes');

  Future<List<double>> _getIFrames(String inputPath) async {
    final result = await Process.run(
      'ffprobe',
      [
        '-v', 'error',
        '-show_entries', 'frame=key_frame,pkt_pts_time',
        '-select_streams', 'v',
        '-of', 'csv=p=0',
        inputPath
      ],
      runInShell: true,
    );
    final List<double> iFrames = [];
    final lines = result.stdout.toString().trim().split('\n');
    for (final line in lines) {
      if (line.contains('key_frame=1')) {
        final parts = line.split(',');
        if (parts.length >= 2) {
          final time = double.tryParse(parts[1]);
          if (time != null) iFrames.add(time);
        }
      }
    }
    return iFrames;
  }

  double _roundToIFrame(double time, List<double> iFrames) {
    double result = time;
    for (final iFrame in iFrames.reversed) {
      if (iFrame <= time) {
        result = iFrame;
        break;
      }
    }
    return result;
  }

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
    // 1. Получаем оригинальные названия аудиодорожек
    final allStreams = await MediaInfoService.getAudioStreams(inputPath);
    final Map<int, int> absoluteToPerType = {};
    for (int i = 0; i < allStreams.length; i++) {
      absoluteToPerType[allStreams[i].index] = i;
    }

    // 2. Нужно ли перекодирование аудио (изменение громкости или смешивание)
    final needAudioReencode = audioTracks.any((t) => t.isEnabled && t.volumePercent != 100) || (mixAudio && audioTracks.any((t) => t.isEnabled));

    // 3. Параметры перекодирования аудио (если потребуется)
    final int originalBitrate = await _getAudioBitrate(inputPath);
    final int targetAudioBitrate = exportSettings?.audioBitrate ?? (originalBitrate ~/ 1000);
    final String targetAudioCodec = exportSettings?.audioCodecName ?? 'aac';
    final int targetSampleRate = exportSettings?.sampleRate ?? 48000;
    final int targetChannels = exportSettings?.channels ?? 2;

    // 4. Округление фрагментов до I-кадров
    final iFrames = await _getIFrames(inputPath);
    final roundedClips = clips.map((clip) {
      final newStart = _roundToIFrame(clip.startTime, iFrames);
      final newEnd = _roundToIFrame(clip.endTime, iFrames);
      return Clip(
        id: clip.id,
        sourcePath: clip.sourcePath,
        startTime: newStart,
        endTime: newEnd,
        isVisible: clip.isVisible,
      );
    }).toList();

    final activeClips = roundedClips;
    if (activeClips.isEmpty) return false;

    // 5. Создание concat-файла
    final concatDir = await Directory.systemTemp.createTemp('sovicut_concat');
    final concatFile = File('${concatDir.path}\\concat.txt');
    final content = StringBuffer();
    for (final clip in activeClips) {
      content.writeln("file '$inputPath'");
      content.writeln("inpoint ${clip.startTime.toStringAsFixed(6)}");
      content.writeln("outpoint ${clip.endTime.toStringAsFixed(6)}");
    }
    await concatFile.writeAsString(content.toString());

    final List<String> args = [
      '-f', 'concat', '-safe', '0', '-i', concatFile.path,
      '-copyts', '-start_at_zero',
      '-avoid_negative_ts', 'make_zero',
      '-fflags', '+genpts',
    ];

    // 6. Обрезка по времени (если задана)
    if (trimSeconds != null && trimSeconds > 0 && trimMode == 0) {
      args.addAll(['-t', trimSeconds.toStringAsFixed(2)]);
    }

    // 7. Видео: копируем без изменений (быстро, исходное качество, нормальный размер)
    args.addAll(['-map', '0:v:0', '-c:v', 'copy']);

    // 8. Аудио: определяем, какие дорожки обрабатывать (0-based per-type индексы)
    final List<int> indicesToProcess;
    if (audioTracks.isEmpty) {
      indicesToProcess = [];
    } else {
      final enabledAbsolute = audioTracks
          .where((t) => t.isEnabled)
          .map((t) => t.index)
          .toList();
      indicesToProcess = enabledAbsolute.isEmpty
          ? List.generate(allStreams.length, (i) => i)
          : enabledAbsolute.map((abs) => absoluteToPerType[abs]!).toList();
    }

    if (indicesToProcess.isEmpty) {
      // --- Аудио отключено — не добавляем ни одной дорожки ---
    } else if (needAudioReencode && mixAudio && indicesToProcess.length > 1) {
      // --- Смешивание дорожек в одну ---
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
        '-c:a', targetAudioCodec, '-b:a', '${targetAudioBitrate}k',
        '-ar', targetSampleRate.toString(), '-ac', targetChannels.toString(),
      ]);
    } else if (needAudioReencode) {
      // --- Перекодирование выбранных дорожек (раздельно) ---
      for (int j = 0; j < indicesToProcess.length; j++) {
        final perTypeIdx = indicesToProcess[j];
        args.addAll(['-map', '0:a:$perTypeIdx']);
        final title = allStreams[perTypeIdx].title.isNotEmpty
            ? allStreams[perTypeIdx].title
            : 'Track ${perTypeIdx + 1}';
        args.addAll(['-metadata:s:a:$j', 'title=$title']);
      }
      args.addAll([
        '-c:a', targetAudioCodec, '-b:a', '${targetAudioBitrate}k',
        '-ar', targetSampleRate.toString(), '-ac', targetChannels.toString(),
      ]);
    } else {
      // --- Копирование только выбранных дорожек с сохранением названий ---
      for (int j = 0; j < indicesToProcess.length; j++) {
        final perTypeIdx = indicesToProcess[j];
        args.addAll(['-map', '0:a:$perTypeIdx']);
        if (allStreams[perTypeIdx].title.isNotEmpty) {
          args.addAll(['-metadata:s:a:$j', 'title=${allStreams[perTypeIdx].title}']);
        }
      }
      args.addAll(['-c:a', 'copy']);
    }

    // 9. Флаги совместимости и быстрого открытия
    args.addAll(['-movflags', '+faststart', '-y', outputPath]);

    // 10. Запуск с прогрессом
    final double totalDuration = activeClips.fold(0.0, (sum, c) => sum + c.duration);
    if (isCancelled != null && isCancelled()) {
      try { await concatDir.delete(recursive: true); } catch (_) {}
      return false;
    }
    onProgress?.call(0, AppLocalizations.t('export.encoding'));
    final cancelNotifier = ValueNotifier(false);
    final exitCode = await FFmpegUtils.runWithProgress(
      args: args,
      totalDuration: totalDuration,
      onProgress: (p) => onProgress?.call(p, AppLocalizations.t('export.encoding')),
      cancel: cancelNotifier,
    );

    // 11. Очистка
    try { await concatDir.delete(recursive: true); } catch (_) {}

    if (exitCode != 0) {
      print('Ошибка ffmpeg, код: $exitCode');
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