import 'dart:io';
import 'audio_track.dart';
import 'clip.dart';
import 'export_settings_tab.dart';
import 'ffmpeg_utils.dart';
import 'media_info_service.dart';

class FFmpegService {
  static Future<List<AudioTrack>> analyzeAudio(String videoPath) async {
    try {
      final audioStreams = await MediaInfoService.getAudioStreams(videoPath);
      
      final List<AudioTrack> tracks = [];
      for (final stream in audioStreams) {
        double originalVolume = -100;
        try {
          final volumeResult = await Process.run(
            'ffmpeg',
            [
              '-i', videoPath,
              '-map', '0:a:${stream.index}',
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
        } catch (e) {
          print('Ошибка получения громкости для дорожки ${stream.index}: $e');
        }
        
        tracks.add(AudioTrack(
          index: stream.index,
          name: stream.title,
          isEnabled: true,
          volumePercent: 100,
          originalVolume: originalVolume,
        ));
      }
      return tracks;
    } catch (e) {
      print('Ошибка analyzeAudio: $e');
      return [];
    }
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
    
    final streamIndices = await FFmpegUtils.getStreamIndices(inputPath);
    final List<int> videoIndices = streamIndices['video']!;
    final List<int> audioIndices = streamIndices['audio']!;
    final int audioCount = audioIndices.length;
    
    final originalAudioStreams = await MediaInfoService.getAudioStreams(inputPath);
    print('=== ОРИГИНАЛЬНЫЕ АУДИОДОРОЖКИ ===');
    for (final stream in originalAudioStreams) {
      print('  ${stream.index}: "${stream.title}"');
    }
    
    print('=== ИНДЕКСЫ ПОТОКОВ ===');
    print('Видео: $videoIndices');
    print('Аудио: $audioIndices (всего: $audioCount)');
    print('needConcat: $needConcat, needAudioReencode: $needAudioReencode');
    
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
        
        final tempPath = '${Directory.systemTemp.path}\\sovicut_temp_${DateTime.now().millisecondsSinceEpoch}_$i.mp4';
        tempFiles.add(tempPath);
        
        final List<String> tempArgs = [];
        tempArgs.addAll(['-i', inputPath]);
        tempArgs.addAll(['-ss', clip.startTime.toStringAsFixed(6)]);
        tempArgs.addAll(['-t', clip.duration.toStringAsFixed(6)]);
        
        if (!needAudioReencode) {
          for (final idx in videoIndices) {
            tempArgs.addAll(['-map', '0:v:$idx']);
          }
          for (int idx = 0; idx < audioCount; idx++) {
            tempArgs.addAll(['-map', '0:a:$idx']);
            final originalStream = originalAudioStreams.firstWhere(
              (s) => s.index == idx,
              orElse: () => AudioStreamInfo(
                index: idx,
                title: '',
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
              tempArgs.addAll(['-metadata:s:a:$idx', 'title=${originalStream.title}']);
            }
          }
          tempArgs.addAll(['-c:v', 'copy', '-c:a', 'copy']);
          print('Фрагмент ${i+1}: копирование всех $audioCount аудиопотоков');
        } else {
          tempArgs.addAll(['-map', '0:v:0']);
          if (copyVideo) {
            tempArgs.addAll(['-c:v', 'copy']);
          } else {
            tempArgs.addAll(['-c:v', videoCodec, '-crf', crf.toString()]);
          }
          
          final enabledTracks = audioTracks.where((t) => t.isEnabled).toList();
          print('Фрагмент ${i+1}: перекодирование аудио, включённых дорожек: ${enabledTracks.length}');
          
          if (mixAudio && enabledTracks.length > 1) {
            final List<String> filterParts = [];
            final List<String> mixInputs = [];
            final List<String> trackNames = [];
            
            for (int j = 0; j < enabledTracks.length; j++) {
              final track = enabledTracks[j];
              final factor = track.volumePercent / 100;
              final originalStream = originalAudioStreams.firstWhere(
                (s) => s.index == track.index,
                orElse: () => AudioStreamInfo(
                  index: track.index,
                  title: '',
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
                filterParts.add('[0:a:${track.index}]volume=${factor.toStringAsFixed(2)}[a$j]');
                mixInputs.add('[a$j]');
              } else {
                mixInputs.add('[0:a:${track.index}]');
              }
            }
            
            if (filterParts.isNotEmpty) {
              tempArgs.addAll(['-filter_complex', filterParts.join('; ')]);
            }
            tempArgs.addAll(['-filter_complex', '${mixInputs.join('')}amix=inputs=${mixInputs.length}:duration=longest[aout]']);
            tempArgs.addAll(['-map', '[aout]']);
            
            final mixedTitle = 'Mixed: ${trackNames.join(" + ")}';
            tempArgs.addAll(['-metadata:s:a:0', 'title=$mixedTitle']);
          } else {
            int outputIndex = 0;
            for (final track in enabledTracks) {
              final factor = track.volumePercent / 100;
              final originalStream = originalAudioStreams.firstWhere(
                (s) => s.index == track.index,
                orElse: () => AudioStreamInfo(
                  index: track.index,
                  title: '',
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
                tempArgs.addAll(['-filter_complex', '[0:a:${track.index}]volume=${factor.toStringAsFixed(2)}[a${track.index}]']);
                tempArgs.addAll(['-map', '[a${track.index}]']);
              } else {
                tempArgs.addAll(['-map', '0:a:${track.index}']);
              }
              
              if (originalStream.title.isNotEmpty) {
                tempArgs.addAll(['-metadata:s:a:$outputIndex', 'title=${originalStream.title}']);
              }
              outputIndex++;
            }
          }
          tempArgs.addAll(['-c:a', targetAudioCodec, '-b:a', '${targetAudioBitrate}k']);
          if (exportSettings != null && exportSettings.bitrateMode == BitrateMode.vbr) {
            tempArgs.addAll(['-q:a', '2']);
          }
          tempArgs.addAll(['-ar', targetSampleRate.toString()]);
          tempArgs.addAll(['-ac', targetChannels.toString()]);
        }
        
        tempArgs.addAll(['-y', tempPath]);
        
        final tempResult = await Process.run('ffmpeg', tempArgs, runInShell: true);
        if (tempResult.exitCode != 0) {
          print('ОШИБКА при обработке фрагмента $i: ${tempResult.stderr}');
          for (final f in tempFiles) { try { await File(f).delete(); } catch (_) {} }
          return false;
        }
      }
      
      if (tempFiles.isEmpty) return false;
      
      final concatDir = await Directory.systemTemp.createTemp('sovicut_concat_final');
      final concatPath = '${concatDir.path}\\concat.txt';
      final concatFile = File(concatPath);
      final content = StringBuffer();
      for (final temp in tempFiles) {
        content.writeln("file '$temp'");
      }
      await concatFile.writeAsString(content.toString());
      
      args.clear();
      args.addAll(['-f', 'concat', '-safe', '0', '-i', concatPath]);
      
      final firstFileInfo = await MediaInfoService.getMediaInfo(tempFiles.first);
      final audioStreamsCount = firstFileInfo.audioStreams.length;
      
      for (int i = 0; i < tempFiles.length; i++) {
        for (int j = 0; j < audioStreamsCount; j++) {
          args.addAll(['-map', '${i}:a:$j']);
        }
      }
      args.addAll(['-map', '0:v:0']);
      args.addAll(['-c:v', 'copy', '-c:a', 'copy']);
      
      for (int j = 0; j < firstFileInfo.audioStreams.length; j++) {
        final stream = firstFileInfo.audioStreams[j];
        if (stream.title.isNotEmpty) {
          args.addAll(['-metadata:s:a:$j', 'title=${stream.title}']);
        }
      }
      
      if (trimSeconds != null && trimSeconds > 0 && trimMode == 0) {
        args.addAll(['-t', trimSeconds.toStringAsFixed(2)]);
      }
      args.addAll(['-y', outputPath]);
      
      print('=== ФИНАЛЬНАЯ КОМАНДА СКЛЕЙКИ ===');
      print('ffmpeg ${args.join(' ')}');
      
      final result = await Process.run('ffmpeg', args, runInShell: true);
      
      for (final f in tempFiles) { try { await File(f).delete(); } catch (_) {} }
      try { await concatDir.delete(recursive: true); } catch (_) {}
      
      if (result.exitCode != 0) {
        print('Ошибка склейки: ${result.stderr}');
        return false;
      }
      
      print('=== ЭКСПОРТ УСПЕШНО ЗАВЕРШЁН ===');
      return true;
      
    } else {
      print('=== ОБЫЧНЫЙ ЭКСПОРТ ===');
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
      
      if (!needAudioReencode) {
        for (final idx in videoIndices) {
          args.addAll(['-map', '0:v:$idx']);
        }
        for (int idx = 0; idx < audioCount; idx++) {
          args.addAll(['-map', '0:a:$idx']);
          final originalStream = originalAudioStreams.firstWhere(
            (s) => s.index == idx,
            orElse: () => AudioStreamInfo(
              index: idx,
              title: '',
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
            args.addAll(['-metadata:s:a:$idx', 'title=${originalStream.title}']);
          }
        }
        args.addAll(['-c:v', 'copy', '-c:a', 'copy']);
        print('Копирование всех $audioCount аудиопотоков');
      } else {
        args.addAll(['-map', '0:v:0']);
        if (copyVideo) {
          args.addAll(['-c:v', 'copy']);
        } else {
          args.addAll(['-c:v', videoCodec, '-crf', crf.toString()]);
        }
        
        final enabledTracks = audioTracks.where((t) => t.isEnabled).toList();
        print('Перекодирование аудио, включённых дорожек: ${enabledTracks.length}');
        
        if (mixAudio && enabledTracks.length > 1) {
          final List<String> filterParts = [];
          final List<String> mixInputs = [];
          final List<String> trackNames = [];
          
          for (int j = 0; j < enabledTracks.length; j++) {
            final track = enabledTracks[j];
            final factor = track.volumePercent / 100;
            final originalStream = originalAudioStreams.firstWhere(
              (s) => s.index == track.index,
              orElse: () => AudioStreamInfo(
                index: track.index,
                title: '',
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
              filterParts.add('[0:a:${track.index}]volume=${factor.toStringAsFixed(2)}[a$j]');
              mixInputs.add('[a$j]');
            } else {
              mixInputs.add('[0:a:${track.index}]');
            }
          }
          
          if (filterParts.isNotEmpty) {
            args.addAll(['-filter_complex', filterParts.join('; ')]);
          }
          args.addAll(['-filter_complex', '${mixInputs.join('')}amix=inputs=${mixInputs.length}:duration=longest[aout]']);
          args.addAll(['-map', '[aout]']);
          
          final mixedTitle = 'Mixed: ${trackNames.join(" + ")}';
          args.addAll(['-metadata:s:a:0', 'title=$mixedTitle']);
        } else {
          int outputIndex = 0;
          for (final track in enabledTracks) {
            final factor = track.volumePercent / 100;
            final originalStream = originalAudioStreams.firstWhere(
              (s) => s.index == track.index,
              orElse: () => AudioStreamInfo(
                index: track.index,
                title: '',
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
              args.addAll(['-filter_complex', '[0:a:${track.index}]volume=${factor.toStringAsFixed(2)}[a${track.index}]']);
              args.addAll(['-map', '[a${track.index}]']);
            } else {
              args.addAll(['-map', '0:a:${track.index}']);
            }
            
            if (originalStream.title.isNotEmpty) {
              args.addAll(['-metadata:s:a:$outputIndex', 'title=${originalStream.title}']);
            }
            outputIndex++;
          }
        }
        args.addAll(['-c:a', targetAudioCodec, '-b:a', '${targetAudioBitrate}k']);
        if (exportSettings != null && exportSettings.bitrateMode == BitrateMode.vbr) {
          args.addAll(['-q:a', '2']);
        }
        args.addAll(['-ar', targetSampleRate.toString()]);
        args.addAll(['-ac', targetChannels.toString()]);
      }
      
      args.addAll(['-y', outputPath]);
      print('Команда: ffmpeg ${args.join(' ')}');
      
      final result = await Process.run('ffmpeg', args, runInShell: true);
      if (result.exitCode != 0) {
        print('Ошибка: ${result.stderr}');
        return false;
      }
      
      print('=== ЭКСПОРТ УСПЕШНО ЗАВЕРШЁН ===');
      return true;
    }
  }
}