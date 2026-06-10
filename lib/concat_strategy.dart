import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'audio_track.dart';
import 'clip.dart';
import 'export_settings_tab.dart';
import 'export_strategy.dart';
import 'media_info_service.dart';

class ConcatStrategy implements ExportStrategy {
  @override
  String get name => 'Округление до ключевых кадров (быстро)';

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
  }) async {
    // 1. Получаем оригинальные названия аудиодорожек (исправление индексов)
    final allStreams = await MediaInfoService.getAudioStreams(inputPath);
    final Map<int, String> originalTitle = {}; // ffmpeg-индекс → название
    for (final stream in allStreams) {
      originalTitle[stream.index - 1] = stream.title;
    }
    print('Оригинальные названия (ffmpeg-индексы): $originalTitle');

    // 2. Нужно ли перекодирование аудио (изменение громкости или смешивание)
    final needAudioReencode = audioTracks.any((t) => t.volumePercent != 100) || mixAudio;

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

    final activeClips = roundedClips.where((c) => c.isVisible).toList();
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

    // 8. Аудио: определяем, какие дорожки обрабатывать (ffmpeg-индексы)
    final enabledIndices = audioTracks
        .where((t) => t.isEnabled)
        .map((t) => t.index - 1)
        .toList();
    final List<int> indicesToProcess = enabledIndices.isEmpty
        ? List.generate(originalTitle.length, (i) => i)
        : enabledIndices;

    if (needAudioReencode && mixAudio && indicesToProcess.length > 1) {
      // --- Смешивание дорожек в одну ---
      final List<String> filterParts = [];
      final List<String> mixInputs = [];
      final List<String> trackNames = [];
      for (int j = 0; j < indicesToProcess.length; j++) {
        final idx = indicesToProcess[j];
        final origIdx = idx + 1; // обратно к ffprobe-индексу
        final track = audioTracks.firstWhere((t) => t.index == origIdx);
        final factor = track.volumePercent / 100;
        final title = originalTitle[idx] ?? 'Track ${idx + 1}';
        trackNames.add(title);
        if (factor != 1.0) {
          filterParts.add('[0:a:$idx]volume=${factor.toStringAsFixed(2)}[a$j]');
          mixInputs.add('[a$j]');
        } else {
          mixInputs.add('[0:a:$idx]');
        }
      }
      if (filterParts.isNotEmpty) {
        args.addAll(['-filter_complex', filterParts.join('; ')]);
      }
      args.addAll([
        '-filter_complex', '${mixInputs.join('')}amix=inputs=${mixInputs.length}:duration=longest[aout]',
        '-map', '[aout]',
        '-metadata:s:a:0', 'title=Mixed: ${trackNames.join(" + ")}',
        '-c:a', targetAudioCodec, '-b:a', '${targetAudioBitrate}k',
        '-ar', targetSampleRate.toString(), '-ac', targetChannels.toString(),
      ]);
    } else if (needAudioReencode) {
      // --- Перекодирование выбранных дорожек (раздельно) ---
      for (int j = 0; j < indicesToProcess.length; j++) {
        final idx = indicesToProcess[j];
        args.addAll(['-map', '0:a:$idx']);
        final title = originalTitle[idx] ?? 'Track ${idx + 1}';
        args.addAll(['-metadata:s:a:$j', 'title=$title']);
      }
      args.addAll([
        '-c:a', targetAudioCodec, '-b:a', '${targetAudioBitrate}k',
        '-ar', targetSampleRate.toString(), '-ac', targetChannels.toString(),
      ]);
    } else {
      // --- Копирование всех дорожек с сохранением оригинальных названий ---
      final int totalAudioCount = originalTitle.length;
      for (int i = 0; i < totalAudioCount; i++) {
        args.addAll(['-map', '0:a:$i']);
        final title = originalTitle[i] ?? '';
        if (title.isNotEmpty) {
          args.addAll(['-metadata:s:a:$i', 'title=$title']);
        }
      }
      args.addAll(['-c:a', 'copy']);
    }

    // 9. Флаги совместимости и быстрого открытия
    args.addAll(['-movflags', '+faststart', '-y', outputPath]);

    print('=== СТРАТЕГИЯ: ${name} ===');
    print('ffmpeg ${args.join(' ')}');
    final result = await Process.run('ffmpeg', args, runInShell: true);

    // 10. Очистка
    try { await concatDir.delete(recursive: true); } catch (_) {}

    if (result.exitCode != 0) {
      print('Ошибка: ${result.stderr}');
      return false;
    }

    print('✅ Экспорт успешен: $outputPath');
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