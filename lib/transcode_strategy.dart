import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'audio_track.dart';
import 'clip.dart';
import 'export_settings_tab.dart';
import 'export_strategy.dart';
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
  }) async {
    // 1. Получаем оригинальные названия с корректными индексами
    final allStreams = await MediaInfoService.getAudioStreams(inputPath);
    final Map<int, int> absoluteToPerType = {};
    for (int i = 0; i < allStreams.length; i++) {
      absoluteToPerType[allStreams[i].index] = i;
    }
    print('Оригинальные названия аудиодорожек: ${allStreams.map((s) => '${s.index}: "${s.title}"').join(', ')}');

    // 2. Параметры экспорта
    final int defaultBitrate = await _getAudioBitrate(inputPath);
    final int audioBitrate = exportSettings?.audioBitrate ?? (defaultBitrate ~/ 1000);
    final String audioCodec = exportSettings?.audioCodecName ?? 'aac';
    final int sampleRate = exportSettings?.sampleRate ?? 48000;
    final int channels = exportSettings?.channels ?? 2;
    final String videoCodec = exportSettings?.videoCodecName ?? 'libx264';
    final int crf = exportSettings?.crf ?? 23;

    // 3. Активные фрагменты
    final activeClips = clips.where((c) => c.isVisible).toList();
    if (activeClips.isEmpty) return false;

    final List<String> tempFiles = [];

    // 4. Обработка каждого фрагмента – полное перекодирование
    for (int i = 0; i < activeClips.length; i++) {
      final clip = activeClips[i];
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

      // Аудио: какие дорожки обрабатывать (0-based per-type индексы)
      final enabledAbsolute = audioTracks
          .where((t) => t.isEnabled)
          .map((t) => t.index)
          .toList();
      final List<int> indicesToProcess = enabledAbsolute.isEmpty
          ? List.generate(allStreams.length, (i) => i)
          : enabledAbsolute.map((abs) => absoluteToPerType[abs]!).toList();

      if (mixAudio && indicesToProcess.length > 1) {
        // Смешивание
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
        // Раздельные дорожки
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

      args.addAll(['-movflags', '+faststart', '-y', tempPath]);

      print('Фрагмент ${i+1}: ffmpeg ${args.join(' ')}');
      final result = await Process.run('ffmpeg', args, runInShell: true);
      if (result.exitCode != 0) {
        print('Ошибка фрагмента ${i+1}: ${result.stderr}');
        return false;
      }

      // Проверка создания файла
      final tempFile = File(tempPath);
      if (!await tempFile.exists() || await tempFile.length() < 1024) {
        print('Фрагмент ${i+1} не создан или слишком мал (<1KB)');
        return false;
      }
    }

    // 5. Склейка фрагментов
    final concatDir = await Directory.systemTemp.createTemp('sovicut_concat_final');
    final concatPath = '${concatDir.path}\\concat.txt';
    final concatFile = File(concatPath);
    final content = StringBuffer();
    for (final file in tempFiles) {
      content.writeln("file '$file'");
    }
    await concatFile.writeAsString(content.toString());

    // Получаем количество аудиопотоков из первого фрагмента
    final firstInfo = await MediaInfoService.getMediaInfo(tempFiles.first);
    final int audioCount = firstInfo.audioStreams.length;
    print('Аудиопотоков в фрагментах: $audioCount');

    final List<String> concatArgs = [
      '-f', 'concat', '-safe', '0', '-i', concatPath,
      '-map', '0:v:0',
    ];
    for (int i = 0; i < audioCount; i++) {
      concatArgs.addAll(['-map', '0:a:$i']);
    }
    concatArgs.addAll(['-c:v', 'copy', '-c:a', 'copy', '-movflags', '+faststart']);

    // Восстанавливаем оригинальные названия (обходим потерю метаданных при склейке)
    for (int i = 0; i < audioCount && i < allStreams.length; i++) {
      if (allStreams[i].title.isNotEmpty) {
        concatArgs.addAll(['-metadata:s:a:$i', 'title=${allStreams[i].title}']);
      }
    }

    if (trimSeconds != null && trimSeconds > 0 && trimMode == 0) {
      concatArgs.insertAll(3, ['-t', trimSeconds.toStringAsFixed(2)]);
    }

    concatArgs.addAll(['-y', outputPath]);

    print('Склейка: ffmpeg ${concatArgs.join(' ')}');
    final finalResult = await Process.run('ffmpeg', concatArgs, runInShell: true);

    // Очистка
    for (final f in tempFiles) {
      try { await File(f).delete(); } catch (_) {}
    }
    try { await concatDir.delete(recursive: true); } catch (_) {}

    if (finalResult.exitCode != 0) {
      print('Ошибка склейки: ${finalResult.stderr}');
      return false;
    }

    print('✅ Экспорт успешно завершён: $outputPath');
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