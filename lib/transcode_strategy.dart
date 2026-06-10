import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'audio_track.dart';
import 'clip.dart';
import 'export_settings_tab.dart';
import 'export_strategy.dart';
import 'media_info_service.dart';

class TranscodeStrategy implements ExportStrategy {
  @override
  String get name => 'Полное перекодирование (медленно, но качественно)';

  static const double SHORT_CLIP_THRESHOLD = 0.5;

  Future<String> _transcodeClip({
    required String inputPath,
    required Clip clip,
    required List<AudioTrack> audioTracks,
    required bool mixAudio,
    required bool needAudioReencode,
    required int targetAudioBitrate,
    required String targetAudioCodec,
    required int targetSampleRate,
    required int targetChannels,
    required String videoCodec,
    required int crf,
    required bool copyVideo,
    required ExportSettings? exportSettings,
    required List<AudioStreamInfo> originalAudioStreams,
  }) async {
    final tempPath = '${(await getTemporaryDirectory()).path}\\sovicut_transcoded_${DateTime.now().millisecondsSinceEpoch}.mp4';
    
    final List<String> args = [];
    
    args.addAll(['-i', inputPath]);
    args.addAll(['-ss', clip.startTime.toStringAsFixed(6)]);
    args.addAll(['-t', clip.duration.toStringAsFixed(6)]);
    
    args.addAll(['-map', '0:v:0']);
    args.addAll(['-c:v', videoCodec]);
    args.addAll(['-crf', crf.toString()]);
    args.addAll(['-g', '6']);
    args.addAll(['-keyint_min', '6']);
    
    final enabledIndices = <int>[];
    for (int i = 0; i < audioTracks.length; i++) {
      if (audioTracks[i].isEnabled) {
        enabledIndices.add(i);
      }
    }
    
    print('Перекодирование фрагмента ${clip.duration.toStringAsFixed(3)} сек');
    print('Активных аудиодорожек (по настройкам): ${enabledIndices.length}');
    print('needAudioReencode: $needAudioReencode, mixAudio: $mixAudio');
    
    if (!needAudioReencode || enabledIndices.isEmpty) {
      final int audioCount = originalAudioStreams.length;
      print('Копирование ВСЕХ оригинальных аудиодорожек: $audioCount');
      for (int i = 0; i < audioCount; i++) {
        args.addAll(['-map', '0:a:$i']);
        // Сохраняем оригинальные метаданные
        final stream = originalAudioStreams[i];
        if (stream.title.isNotEmpty) {
          args.addAll(['-metadata:s:a:$i', 'title=${stream.title}']);
        }
        if (stream.language.isNotEmpty) {
          args.addAll(['-metadata:s:a:$i', 'language=${stream.language}']);
        }
      }
      args.addAll(['-c:a', 'copy']);
    } else {
      print('Обработка выбранных аудиодорожек: ${enabledIndices.length}');
      final List<String> audioFilters = [];
      final List<String> audioMaps = [];
      
      if (mixAudio && enabledIndices.length > 1) {
        final List<String> filterParts = [];
        final List<String> mixInputs = [];
        final List<String> trackNames = [];
        
        for (int i = 0; i < enabledIndices.length; i++) {
          final track = audioTracks[enabledIndices[i]];
          final factor = track.volumePercent / 100;
          final originalStream = originalAudioStreams.firstWhere(
            (s) => s.index == track.index,
            orElse: () => AudioStreamInfo(
              index: track.index,
              title: track.name,
              codec: 'unknown',
              bitrate: 0,
              sampleRate: 0,
              channels: 2,
              language: '',
              isDefault: false,
              isForced: false,
            ),
          );
          trackNames.add(originalStream.title);
          
          if (factor != 1.0) {
            filterParts.add('[0:a:${track.index}]volume=${factor.toStringAsFixed(2)}[a$i]');
            mixInputs.add('[a$i]');
          } else {
            mixInputs.add('[0:a:${track.index}]');
          }
        }
        
        if (filterParts.isNotEmpty) {
          audioFilters.add(filterParts.join('; '));
        }
        audioFilters.add('${mixInputs.join('')}amix=inputs=${mixInputs.length}:duration=longest[aout]');
        audioMaps.addAll(['-map', '[aout]']);
        
        final mixedTitle = 'Mixed: ${trackNames.join(" + ")}';
        args.addAll(['-metadata:s:a:0', 'title=$mixedTitle']);
        args.addAll(['-metadata:s:a:0', 'comment=Mixed from: ${trackNames.join(", ")}']);
        print('Режим: объединение дорожек -> $mixedTitle');
      } else {
        int outputStreamIndex = 0;
        for (int i = 0; i < enabledIndices.length; i++) {
          final track = audioTracks[enabledIndices[i]];
          final factor = track.volumePercent / 100;
          final originalStream = originalAudioStreams.firstWhere(
            (s) => s.index == track.index,
            orElse: () => AudioStreamInfo(
              index: track.index,
              title: track.name,
              codec: 'unknown',
              bitrate: 0,
              sampleRate: 0,
              channels: 2,
              language: '',
              isDefault: false,
              isForced: false,
            ),
          );
          
          if (factor != 1.0) {
            audioFilters.add('[0:a:${track.index}]volume=${factor.toStringAsFixed(2)}[a$i]');
            audioMaps.addAll(['-map', '[a$i]']);
          } else {
            audioMaps.addAll(['-map', '0:a:${track.index}']);
          }
          
          // Сохраняем оригинальные метаданные
          if (originalStream.title.isNotEmpty) {
            args.addAll(['-metadata:s:a:$outputStreamIndex', 'title=${originalStream.title}']);
          }
          if (originalStream.language.isNotEmpty) {
            args.addAll(['-metadata:s:a:$outputStreamIndex', 'language=${originalStream.language}']);
          }
          outputStreamIndex++;
        }
        print('Режим: раздельные дорожки');
      }
      
      if (audioFilters.isNotEmpty) {
        args.addAll(['-filter_complex', audioFilters.join('; ')]);
      }
      args.addAll(audioMaps);
      args.addAll(['-c:a', targetAudioCodec, '-b:a', '${targetAudioBitrate}k']);
      if (exportSettings != null && exportSettings.bitrateMode == BitrateMode.vbr) {
        args.addAll(['-q:a', '2']);
      }
      args.addAll(['-ar', targetSampleRate.toString()]);
      args.addAll(['-ac', targetChannels.toString()]);
    }
    
    args.addAll(['-y', tempPath]);
    
    print('Команда перекодирования: ffmpeg ${args.join(' ')}');
    
    final result = await Process.run('ffmpeg', args, runInShell: true);
    if (result.exitCode != 0) {
      print('STDERR: ${result.stderr}');
      throw Exception('Ошибка перекодирования фрагмента: ${result.stderr}');
    }
    
    return tempPath;
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
    final List<String> args = [];
    final List<String> tempFiles = [];
    
    final bool needAudioReencode = audioTracks.any((t) => t.volumePercent != 100) || mixAudio;
    
    // Получаем оригинальные аудио потоки через MediaInfoService
    final originalAudioStreams = await MediaInfoService.getAudioStreams(inputPath);
    print('Оригинальные аудио потоки:');
    for (final stream in originalAudioStreams) {
      print('  ${stream.index}: "${stream.title}" (${stream.codec})');
    }
    
    final int originalBitrateValue = await _getAudioBitrate(inputPath);
    final bool useCustomSettings = exportSettings != null && 
        (exportSettings.audioBitrate != (originalBitrateValue ~/ 1000) ||
         exportSettings.audioCodec != AudioCodec.aac ||
         exportSettings.bitrateMode != BitrateMode.cbr ||
         exportSettings.sampleRate != 48000 ||
         exportSettings.channels != 2 ||
         exportSettings.videoQuality != VideoQuality.source);
    
    int targetAudioBitrate;
    String targetAudioCodec;
    int targetSampleRate;
    int targetChannels;
    String videoCodec;
    int crf;
    bool copyVideo = true;
    
    if (useCustomSettings && exportSettings != null) {
      targetAudioBitrate = exportSettings.audioBitrate;
      targetAudioCodec = exportSettings.audioCodecName;
      targetSampleRate = exportSettings.sampleRate;
      targetChannels = exportSettings.channels;
      videoCodec = exportSettings.videoCodecName;
      crf = exportSettings.crf;
      copyVideo = exportSettings.videoQuality == VideoQuality.source;
    } else {
      targetAudioBitrate = originalBitrateValue ~/ 1000;
      targetAudioCodec = 'aac';
      targetSampleRate = 48000;
      targetChannels = 2;
      videoCodec = 'libx264';
      crf = 23;
      copyVideo = true;
    }
    
    final activeClips = clips.where((c) => c.isVisible).toList();
    final List<String> processedFiles = [];
    
    print('=== ПЕРЕКОДИРОВАНИЕ ВСЕХ ФРАГМЕНТОВ ===');
    print('Всего активных фрагментов: ${activeClips.length}');
    
    for (int i = 0; i < activeClips.length; i++) {
      final clip = activeClips[i];
      print('\n--- Обработка фрагмента ${i + 1} ---');
      
      final transcoded = await _transcodeClip(
        inputPath: inputPath,
        clip: clip,
        audioTracks: audioTracks,
        mixAudio: mixAudio,
        needAudioReencode: needAudioReencode,
        targetAudioBitrate: targetAudioBitrate,
        targetAudioCodec: targetAudioCodec,
        targetSampleRate: targetSampleRate,
        targetChannels: targetChannels,
        videoCodec: videoCodec,
        crf: crf,
        copyVideo: copyVideo,
        exportSettings: exportSettings,
        originalAudioStreams: originalAudioStreams,
      );
      processedFiles.add(transcoded);
      tempFiles.add(transcoded);
    }
    
    if (processedFiles.isEmpty) {
      print('Нет активных фрагментов');
      return false;
    }
    
    print('\n=== СКЛЕЙКА ФРАГМЕНТОВ ===');
    
    // Получаем информацию о первом фрагменте
    final firstFileInfo = await MediaInfoService.getMediaInfo(processedFiles.first);
    final audioStreams = firstFileInfo.audioStreams;
    print('Количество аудиопотоков в фрагментах: ${audioStreams.length}');
    for (final stream in audioStreams) {
      print('  Поток ${stream.index}: "${stream.title}"');
    }
    
    // Создаём файл конкатенации
    final concatDir = await Directory.systemTemp.createTemp('sovicut_concat_final');
    final concatPath = '${concatDir.path}\\concat.txt';
    final concatFile = File(concatPath);
    final content = StringBuffer();
    for (final file in processedFiles) {
      content.writeln("file '$file'");
    }
    await concatFile.writeAsString(content.toString());
    
    // Очищаем аргументы и строим новую команду
    args.clear();
    
    // Используем concat demuxer
    args.addAll(['-f', 'concat', '-safe', '0', '-i', concatPath]);
    
    // Явно маппим видео поток
    args.addAll(['-map', '0:v:0']);
    
    // Явно маппим ВСЕ аудио потоки и сохраняем их метаданные
    for (int i = 0; i < audioStreams.length; i++) {
      args.addAll(['-map', '0:a:$i']);
      
      // Сохраняем оригинальные названия из первого фрагмента
      final stream = audioStreams[i];
      if (stream.title.isNotEmpty) {
        args.addAll(['-metadata:s:a:$i', 'title=${stream.title}']);
      }
      if (stream.language.isNotEmpty) {
        args.addAll(['-metadata:s:a:$i', 'language=${stream.language}']);
      }
    }
    
    // Копируем кодеки без перекодирования
    args.addAll(['-c:v', 'copy']);
    args.addAll(['-c:a', 'copy']);
    
    // Применяем обрезку если нужно
    if (trimSeconds != null && trimSeconds > 0 && trimMode == 0) {
      args.addAll(['-t', trimSeconds.toStringAsFixed(2)]);
    }
    
    args.addAll(['-y', outputPath]);
    
    print('Финальная команда: ffmpeg ${args.join(' ')}');
    
    final result = await Process.run('ffmpeg', args, runInShell: true);
    
    // Очистка временных файлов
    for (final f in tempFiles) {
      try { await File(f).delete(); } catch (_) {}
    }
    try { await concatDir.delete(recursive: true); } catch (_) {}
    
    print('=== EXIT CODE: ${result.exitCode} ===');
    if (result.exitCode != 0) {
      print('=== STDERR ===');
      print(result.stderr);
      return false;
    }
    
    print('=== ЭКСПОРТ УСПЕШНО ЗАВЕРШЁН ===');
    print('=== СОХРАНЕНО АУДИО ПОТОКОВ: ${audioStreams.length} ===');
    for (final stream in audioStreams) {
      print('  - "${stream.title}" (${stream.codec})');
    }
    return true;
  }

  static Future<int> _getAudioBitrate(String videoPath) async {
    try {
      final result = await Process.run(
        'ffprobe',
        [
          '-v', 'error',
          '-show_entries', 'stream=codec_type,bit_rate',
          '-of', 'default=noprint_wrappers=1:nokey=1',
          videoPath
        ],
        runInShell: true,
      );
      final lines = result.stdout.toString().trim().split('\n');
      for (int i = 0; i < lines.length; i++) {
        if (lines[i] == 'audio' && i + 1 < lines.length) {
          final bitrate = int.tryParse(lines[i + 1]);
          if (bitrate != null && bitrate > 0) {
            return bitrate;
          }
        }
      }
    } catch (e) {}
    return 192000;
  }
}