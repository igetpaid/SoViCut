import 'dart:io';
import 'audio_track.dart';

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

  static Future<bool> exportVideo({
    required String inputPath,
    required String outputPath,
    required List<AudioTrack> audioTracks,
    required bool mixAudio,
    double? trimSeconds,
    int? trimMode,
  }) async {
    final List<String> args = [];
    
    print('=== exportVideo: trimSeconds=$trimSeconds, trimMode=$trimMode ===');
    
    // ========== ОБРЕЗКА (режим "оставить первые N" — -t ДО -i) ==========
    if (trimSeconds != null && trimSeconds > 0 && trimMode == 0) {
      args.addAll(['-t', trimSeconds.toStringAsFixed(2)]);
      print('=== Добавлен -t для режима "оставить первые" ===');
    }
    
    // ========== ВХОДНОЙ ФАЙЛ ==========
    args.addAll(['-i', inputPath]);
    
    // ========== ОБРЕЗКА (режим "вырезать последние N" — -t ПОСЛЕ -i) ==========
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
          print('=== Добавлен -t для режима "вырезать последние": $newDuration ===');
        }
      }
    }
    
    // ========== АУДИО ==========
    final enabledIndices = <int>[];
    for (int i = 0; i < audioTracks.length; i++) {
      if (audioTracks[i].isEnabled) {
        enabledIndices.add(i);
      }
    }
    
    if (enabledIndices.isNotEmpty) {
      final List<String> audioFilters = [];
      final List<String> audioMaps = [];
      
      if (mixAudio && enabledIndices.length > 1) {
        // Микширование: объединяем все включённые дорожки в одну
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
        // Без микширования: обрабатываем каждую дорожку отдельно
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
    } else {
      // Копируем все оригинальные аудиодорожки
      final probeResult = await Process.run(
        'ffprobe',
        [
          '-v', 'error',
          '-show_entries', 'stream=codec_type',
          '-of', 'csv=p=0',
          inputPath
        ],
        runInShell: true,
      );
      final lines = probeResult.stdout.toString().trim().split('\n');
      int audioStreamCount = 0;
      for (final line in lines) {
        if (line.contains('audio')) audioStreamCount++;
      }
      for (int i = 0; i < audioStreamCount; i++) {
        args.addAll(['-map', '0:a:$i']);
      }
    }
    
    // ========== ВИДЕО ==========
    args.addAll(['-map', '0:v:0', '-c:v', 'copy']);
    
    // ========== ВЫХОДНОЙ ФАЙЛ ==========
    args.addAll(['-y', outputPath]);
    
    print('=== FFmpeg команда ===');
    print('ffmpeg ${args.join(' ')}');
    print('=======================');
    
    final result = await Process.run('ffmpeg', args, runInShell: true);
    
    print('=== EXIT CODE: ${result.exitCode} ===');
    if (result.exitCode != 0) {
      print('=== STDERR ===');
      print(result.stderr);
    }
    
    return result.exitCode == 0;
  }
}