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

  /// Получает список времен всех I-кадров в видео
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
          if (time != null) {
            iFrames.add(time);
          }
        }
      }
    }
    return iFrames;
  }

  /// Округляет время до ближайшего I-кадра в сторону уменьшения
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
    final List<String> args = [];
    
    final bool needAudioReencode = audioTracks.any((t) => t.volumePercent != 100) || mixAudio;
    
    // Получаем оригинальные аудио потоки через MediaInfoService
    final originalAudioStreams = await MediaInfoService.getAudioStreams(inputPath);
    print('=== ОРИГИНАЛЬНЫЕ АУДИОДОРОЖКИ (ConcatStrategy) ===');
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
    
    final iFrames = await _getIFrames(inputPath);
    print('Найдено I-кадров: ${iFrames.length}');
    
    final roundedClips = clips.map((clip) {
      final newStart = _roundToIFrame(clip.startTime, iFrames);
      final newEnd = _roundToIFrame(clip.endTime, iFrames);
      print('Фрагмент: исходный [${clip.startTime.toStringAsFixed(3)} - ${clip.endTime.toStringAsFixed(3)}]');
      print('         округлён [${newStart.toStringAsFixed(3)} - ${newEnd.toStringAsFixed(3)}]');
      return Clip(
        id: clip.id,
        sourcePath: clip.sourcePath,
        startTime: newStart,
        endTime: newEnd,
        isVisible: clip.isVisible,
      );
    }).toList();
    
    final activeClips = roundedClips.where((c) => c.isVisible).toList();
    final concatDir = await Directory.systemTemp.createTemp('sovicut_concat');
    final concatPath = '${concatDir.path}\\concat.txt';
    final concatFile = File(concatPath);
    final content = StringBuffer();
    
    for (final clip in activeClips) {
      content.writeln("file '$inputPath'");
      content.writeln("inpoint ${clip.startTime.toStringAsFixed(6)}");
      content.writeln("outpoint ${clip.endTime.toStringAsFixed(6)}");
    }
    await concatFile.writeAsString(content.toString());
    
    args.addAll(['-f', 'concat', '-safe', '0', '-i', concatPath]);
    args.addAll(['-copyts', '-start_at_zero']);
    args.addAll(['-avoid_negative_ts', 'make_zero']);
    args.addAll(['-fflags', '+genpts']);
    
    if (trimSeconds != null && trimSeconds > 0 && trimMode == 0) {
      args.addAll(['-t', trimSeconds.toStringAsFixed(2)]);
    }
    
    args.addAll(['-map', '0:v:0', '-c:v', copyVideo ? 'copy' : videoCodec]);
    if (!copyVideo) {
      args.addAll(['-crf', crf.toString()]);
    }
    
    final enabledIndices = <int>[];
    for (int i = 0; i < audioTracks.length; i++) {
      if (audioTracks[i].isEnabled) {
        enabledIndices.add(i);
      }
    }
    
    final audioStreamsCount = originalAudioStreams.length;
    
    if (needAudioReencode && enabledIndices.isNotEmpty) {
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
        int outputIndex = 0;
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
          
          // Сохраняем оригинальное название
          if (originalStream.title.isNotEmpty) {
            args.addAll(['-metadata:s:a:$outputIndex', 'title=${originalStream.title}']);
          }
          if (originalStream.language.isNotEmpty) {
            args.addAll(['-metadata:s:a:$outputIndex', 'language=${originalStream.language}']);
          }
          outputIndex++;
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
    } else {
      // Копируем ВСЕ оригинальные аудиопотоки с сохранением названий
      print('Копирование всех $audioStreamsCount аудиопотоков с сохранением названий');
      for (int i = 0; i < audioStreamsCount; i++) {
        args.addAll(['-map', '0:a:$i']);
        
        final originalStream = originalAudioStreams.firstWhere(
          (s) => s.index == i,
          orElse: () => AudioStreamInfo(
            index: i,
            title: 'Дорожка ${i + 1}',
            codec: 'unknown',
            bitrate: 0,
            sampleRate: 0,
            channels: 2,
            language: '',
            isDefault: false,
            isForced: false,
          ),
        );
        
        if (originalStream.title.isNotEmpty) {
          args.addAll(['-metadata:s:a:$i', 'title=${originalStream.title}']);
        }
        if (originalStream.language.isNotEmpty) {
          args.addAll(['-metadata:s:a:$i', 'language=${originalStream.language}']);
        }
      }
      args.addAll(['-c:a', 'copy']);
    }
    
    args.addAll(['-y', outputPath]);
    
    print('=== СТРАТЕГИЯ: ${name} ===');
    print('ffmpeg ${args.join(' ')}');
    
    final result = await Process.run('ffmpeg', args, runInShell: true);
    
    try { await concatDir.delete(recursive: true); } catch (e) {}
    
    print('=== EXIT CODE: ${result.exitCode} ===');
    if (result.exitCode != 0) {
      print('=== STDERR ===');
      print(result.stderr);
    } else {
      print('=== ЭКСПОРТ УСПЕШНО ЗАВЕРШЁН ===');
      print('=== СОХРАНЕНО АУДИО ПОТОКОВ: $audioStreamsCount ===');
      for (final stream in originalAudioStreams) {
        print('  - "${stream.title}"');
      }
    }
    
    return result.exitCode == 0;
  }

  static Future<int> _getAudioStreamCount(String videoPath) async {
    final streams = await MediaInfoService.getAudioStreams(videoPath);
    return streams.length;
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