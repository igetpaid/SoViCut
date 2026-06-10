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
    
    if (needConcat) {
      // Создаём concat.txt со списком активных фрагментов
      final activeClips = clips!.where((c) => c.isVisible).toList();
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
      args.addAll(['-fflags', '+genpts']);  // ← ключевое добавление
      
      if (trimSeconds != null && trimSeconds > 0 && trimMode == 0) {
        args.addAll(['-t', trimSeconds.toStringAsFixed(2)]);
      }
      
      // Видео
      args.addAll(['-map', '0:v:0', '-c:v', copyVideo ? 'copy' : videoCodec]);
      if (!copyVideo) {
        args.addAll(['-crf', crf.toString()]);
      }
      
      // Аудио
      final enabledIndices = <int>[];
      for (int i = 0; i < audioTracks.length; i++) {
        if (audioTracks[i].isEnabled) {
          enabledIndices.add(i);
        }
      }
      
      if (needAudioReencode && enabledIndices.isNotEmpty) {
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
        for (int i = 0; i < audioCount; i++) {
          args.addAll(['-map', '0:a:$i']);
        }
        args.addAll(['-c:a', 'copy']);
      }
      
      args.addAll(['-y', outputPath]);
      
      print('=== FFMPEG КОМАНДА ===');
      print('ffmpeg ${args.join(' ')}');
      
      final result = await Process.run('ffmpeg', args, runInShell: true);
      
      try { await concatDir.delete(recursive: true); } catch (e) {}
      
      print('=== EXIT CODE: ${result.exitCode} ===');
      if (result.exitCode != 0) {
        print('=== STDERR ===');
        print(result.stderr);
      }
      
      return result.exitCode == 0;
    } else {
      // Обычный экспорт (без concat)
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
        for (int i = 0; i < audioCount; i++) {
          args.addAll(['-map', '0:a:$i']);
        }
      }
      
      args.addAll(['-map', '0:v:0', '-c:v', copyVideo ? 'copy' : videoCodec]);
      if (!copyVideo) {
        args.addAll(['-crf', crf.toString()]);
      }
      args.addAll(['-y', outputPath]);
      
      print('=== FFMPEG КОМАНДА ===');
      print('ffmpeg ${args.join(' ')}');
      
      final result = await Process.run('ffmpeg', args, runInShell: true);
      
      print('=== EXIT CODE: ${result.exitCode} ===');
      if (result.exitCode != 0) {
        print('=== STDERR ===');
        print(result.stderr);
      }
      
      return result.exitCode == 0;
    }
  }
}