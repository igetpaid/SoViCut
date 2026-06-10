import 'dart:io';
import 'audio_track.dart';
import 'clip.dart';
import 'export_settings_tab.dart';

class FFmpegService {
  static Future<List<AudioTrack>> analyzeAudio(String videoPath) async {
    final probeResult = await Process.run(
      'ffprobe',
      [
        '-v', 'error',
        '-show_entries', 'stream=index,codec_type',
        '-of', 'csv=p=0',
        videoPath
      ],
      runInShell: true,
    );

    final lines = probeResult.stdout.toString().trim().split('\n');
    final List<int> audioRealIndexes = [];
    
    for (final line in lines) {
      final parts = line.split(',');
      if (parts.length >= 2 && parts[1].trim() == 'audio') {
        final index = int.tryParse(parts[0].trim());
        if (index != null) audioRealIndexes.add(index);
      }
    }

    final List<AudioTrack> tracks = [];
    for (int i = 0; i < audioRealIndexes.length; i++) {
      double originalVolume = -100;
      try {
        final volumeResult = await Process.run(
          'ffmpeg',
          [
            '-i', videoPath,
            '-map', '0:a:$i',
            '-af', 'volumedetect',
            '-f', 'null',
            'NUL'
          ],
          runInShell: true,
        );
        final match = RegExp(r'mean_volume:\s*(-?\d+(?:\.\d+)?)')
            .firstMatch(volumeResult.stderr.toString());
        if (match != null) {
          originalVolume = double.parse(match.group(1)!);
        }
      } catch (e) {}
      
      tracks.add(AudioTrack(
        index: i,
        name: 'Дорожка ${i + 1}',
        isEnabled: true,
        volumePercent: 100,
        originalVolume: originalVolume,
      ));
    }
    return tracks;
  }

  static Future<int> _getAudioStreamCount(String videoPath) async {
    final result = await Process.run(
      'ffprobe',
      [
        '-v', 'error',
        '-show_entries', 'stream=codec_type',
        '-of', 'csv=p=0',
        videoPath
      ],
      runInShell: true,
    );
    final lines = result.stdout.toString().trim().split('\n');
    int count = 0;
    for (final line in lines) {
      if (line.contains('audio')) count++;
    }
    print('=== _getAudioStreamCount: $count ===');
    return count;
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

  static Future<String> _createConcatFile(List<Clip> clips, String videoPath) async {
    final dir = await Directory.systemTemp.createTemp('sovicut_concat');
    final concatPath = '${dir.path}\\concat.txt';
    final file = File(concatPath);
    final content = StringBuffer();
    
    for (final clip in clips) {
      if (clip.isVisible) {
        content.writeln("file '$videoPath'");
        content.writeln("inpoint ${clip.startTime.toStringAsFixed(6)}");
        content.writeln("outpoint ${clip.endTime.toStringAsFixed(6)}");
      }
    }
    
    await file.writeAsString(content.toString());
    return concatPath;
  }

  static Future<bool> exportVideo({
    required String inputPath,
    required String outputPath,
    required List<AudioTrack> audioTracks,
    required bool mixAudio,
    double? trimSeconds,
    int? trimMode,
    List<Clip>? clips,
    ExportSettings? exportSettings,
  }) async {
    final List<String> args = [];
    
    final bool hasClips = clips != null && clips.isNotEmpty;
    final bool needConcat = hasClips && clips!.any((c) => !c.isVisible) || (hasClips && clips.length > 1);
    final bool needAudioReencode = audioTracks.any((t) => t.volumePercent != 100) || mixAudio;
    
    print('=== exportVideo ===');
    print('needConcat: $needConcat');
    print('needAudioReencode: $needAudioReencode');
    print('audioTracks.length: ${audioTracks.length}');
    print('mixAudio: $mixAudio');
    
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
    
    final List<String> tempFiles = [];
    
    if (needConcat) {
      print('=== РЕЖИМ CONCAT ===');
      for (int i = 0; i < clips!.length; i++) {
        final clip = clips[i];
        if (!clip.isVisible) continue;
        
        print('Обработка фрагмента $i: start=${clip.startTime}, end=${clip.endTime}');
        
        final tempPath = '${Directory.systemTemp.path}\\sovicut_temp_${DateTime.now().millisecondsSinceEpoch}_$i.mp4';
        tempFiles.add(tempPath);
        
        final List<String> tempArgs = [];
        tempArgs.addAll(['-ss', clip.startTime.toStringAsFixed(6)]);
        tempArgs.addAll(['-t', clip.duration.toStringAsFixed(6)]);
        tempArgs.addAll(['-i', inputPath]);
        tempArgs.addAll(['-map', '0:v:0']);
        tempArgs.addAll(['-copyts']);
        tempArgs.addAll(['-avoid_negative_ts', 'make_zero']);
        
        if (copyVideo) {
          tempArgs.addAll(['-c:v', 'copy']);
        } else {
          tempArgs.addAll(['-c:v', videoCodec, '-crf', crf.toString()]);
        }
        
        final enabledIndices = <int>[];
        for (int j = 0; j < audioTracks.length; j++) {
          if (audioTracks[j].isEnabled) {
            enabledIndices.add(j);
          }
        }
        
        if (needAudioReencode && enabledIndices.isNotEmpty) {
          print('Перекодирование аудио для фрагмента $i');
          final List<String> audioFilters = [];
          final List<String> audioMaps = [];
          
          if (mixAudio && enabledIndices.length > 1) {
            final List<String> filterParts = [];
            final List<String> mixInputs = [];
            for (int j = 0; j < enabledIndices.length; j++) {
              final track = audioTracks[enabledIndices[j]];
              final factor = track.volumePercent / 100;
              if (factor != 1.0) {
                filterParts.add('[0:a:${track.index}]volume=${factor.toStringAsFixed(2)}[a$j]');
                mixInputs.add('[a$j]');
              } else {
                mixInputs.add('[0:a:${track.index}]');
              }
            }
            if (filterParts.isNotEmpty) {
              audioFilters.add(filterParts.join('; '));
            }
            audioFilters.add('${mixInputs.join('')}amix=inputs=${mixInputs.length}:duration=longest[aout]');
            audioMaps.addAll(['-map', '[aout]']);
          } else {
            for (int j = 0; j < enabledIndices.length; j++) {
              final track = audioTracks[enabledIndices[j]];
              final factor = track.volumePercent / 100;
              if (factor != 1.0) {
                audioFilters.add('[0:a:${track.index}]volume=${factor.toStringAsFixed(2)}[a$j]');
                audioMaps.addAll(['-map', '[a$j]']);
              } else {
                audioMaps.addAll(['-map', '0:a:${track.index}']);
              }
            }
          }
          
          if (audioFilters.isNotEmpty) {
            tempArgs.addAll(['-filter_complex', audioFilters.join('; ')]);
          }
          tempArgs.addAll(audioMaps);
          tempArgs.addAll(['-c:a', targetAudioCodec, '-b:a', '${targetAudioBitrate}k']);
          if (exportSettings != null && exportSettings.bitrateMode == BitrateMode.vbr) {
            tempArgs.addAll(['-q:a', '2']);
          }
          tempArgs.addAll(['-ar', targetSampleRate.toString()]);
          tempArgs.addAll(['-ac', targetChannels.toString()]);
        } else {
          final int audioCount = await _getAudioStreamCount(inputPath);
          print('Копирование аудио (без перекодирования) для фрагмента $i, дорожек: $audioCount');
          for (int j = 0; j < audioCount; j++) {
            tempArgs.addAll(['-map', '0:a:$j']);
            print('  маппим 0:a:$j');
          }
          tempArgs.addAll(['-c:a', 'copy']);
        }
        
        tempArgs.addAll(['-y', tempPath]);
        
        print('Временная команда для фрагмента $i: ffmpeg ${tempArgs.join(' ')}');
        
        final tempResult = await Process.run('ffmpeg', tempArgs, runInShell: true);
        if (tempResult.exitCode != 0) {
          print('ОШИБКА при создании фрагмента $i: ${tempResult.stderr}');
          for (final f in tempFiles) {
            try { await File(f).delete(); } catch (_) {}
          }
          return false;
        }
      }
      
      if (tempFiles.isEmpty) {
        print('Нет активных фрагментов');
        return false;
      }
      
      final concatDir = await Directory.systemTemp.createTemp('sovicut_concat_final');
      final concatPath = '${concatDir.path}\\concat.txt';
      final concatFile = File(concatPath);
      final content = StringBuffer();
      for (final temp in tempFiles) {
        content.writeln("file '$temp'");
      }
      await concatFile.writeAsString(content.toString());
      
      args.addAll(['-f', 'concat', '-safe', '0', '-i', concatPath]);
      
      args.addAll(['-map', '0:v:0']);
      final int audioCount = await _getAudioStreamCount(tempFiles.first);
      print('Финальный concat: копируем аудиодорожек: $audioCount');
      for (int j = 0; j < audioCount; j++) {
        args.addAll(['-map', '0:a:$j']);
        print('  маппим 0:a:$j');
      }
      args.addAll(['-c:v', 'copy']);
      args.addAll(['-c:a', 'copy']);
      
      if (trimSeconds != null && trimSeconds > 0 && trimMode == 0) {
        args.addAll(['-t', trimSeconds.toStringAsFixed(2)]);
      }
      
      args.addAll(['-y', outputPath]);
      
      print('=== ФИНАЛЬНАЯ КОМАНДА CONCAT ===');
      print('ffmpeg ${args.join(' ')}');
      
      final result = await Process.run('ffmpeg', args, runInShell: true);
      
      for (final f in tempFiles) {
        try { await File(f).delete(); } catch (_) {}
      }
      try { await concatDir.delete(recursive: true); } catch (_) {}
      
      print('Результат concat: exitCode=${result.exitCode}');
      return result.exitCode == 0;
    } else {
      print('=== ОБЫЧНЫЙ РЕЖИМ (без concat) ===');
      
      if (trimSeconds != null && trimSeconds > 0 && trimMode == 0) {
        args.addAll(['-t', trimSeconds.toStringAsFixed(2)]);
      }
      args.addAll(['-i', inputPath]);
      
      if (trimSeconds != null && trimSeconds > 0 && trimMode == 1) {
        final durationResult = await Process.run(
          'ffprobe',
          [
            '-v', 'error',
            '-show_entries', 'format=duration',
            '-of', 'default=noprint_wrappers=1:nokey=1',
            inputPath
          ],
          runInShell: true,
        );
        if (durationResult.exitCode == 0) {
          final fullDuration = double.parse(durationResult.stdout.toString().trim());
          final newDuration = fullDuration - trimSeconds;
          if (newDuration > 0) {
            args.addAll(['-t', newDuration.toStringAsFixed(2)]);
          }
        }
      }
      
      final enabledIndices = <int>[];
      for (int i = 0; i < audioTracks.length; i++) {
        if (audioTracks[i].isEnabled) {
          enabledIndices.add(i);
        }
      }
      
      if (needAudioReencode && enabledIndices.isNotEmpty) {
        print('Перекодирование аудио (обычный режим)');
        final List<String> audioFilters = [];
        final List<String> audioMaps = [];
        
        if (mixAudio && enabledIndices.length > 1) {
          final List<String> filterParts = [];
          final List<String> mixInputs = [];
          for (int i = 0; i < enabledIndices.length; i++) {
            final track = audioTracks[enabledIndices[i]];
            final factor = track.volumePercent / 100;
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
        } else {
          for (int i = 0; i < enabledIndices.length; i++) {
            final track = audioTracks[enabledIndices[i]];
            final factor = track.volumePercent / 100;
            if (factor != 1.0) {
              audioFilters.add('[0:a:${track.index}]volume=${factor.toStringAsFixed(2)}[a$i]');
              audioMaps.addAll(['-map', '[a$i]']);
            } else {
              audioMaps.addAll(['-map', '0:a:${track.index}']);
            }
          }
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
        final int audioCount = await _getAudioStreamCount(inputPath);
        print('Копирование аудио (без перекодирования), дорожек: $audioCount');
        for (int i = 0; i < audioCount; i++) {
          args.addAll(['-map', '0:a:$i']);
          print('  маппим 0:a:$i');
        }
      }
      
      args.addAll(['-map', '0:v:0']);
      if (copyVideo) {
        args.addAll(['-c:v', 'copy']);
      } else {
        args.addAll(['-c:v', videoCodec, '-crf', crf.toString()]);
      }
      args.addAll(['-y', outputPath]);
      
      print('=== ФИНАЛЬНАЯ КОМАНДА ===');
      print('ffmpeg ${args.join(' ')}');
      
      final result = await Process.run('ffmpeg', args, runInShell: true);
      print('Результат: exitCode=${result.exitCode}');
      if (result.exitCode != 0) {
        print('STDERR: ${result.stderr}');
      }
      return result.exitCode == 0;
    }
  }
}