import 'dart:io';
import 'audio_track.dart';
import 'media_info_service.dart';

class FFmpegService {
  static Future<List<AudioTrack>> analyzeAudio(String videoPath) async {
    try {
      final audioStreams = await MediaInfoService.getAudioStreams(videoPath);
      
      final List<AudioTrack> tracks = [];
      for (int i = 0; i < audioStreams.length; i++) {
        final stream = audioStreams[i];
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
        } catch (e) {
          print('Ошибка получения громкости для дорожки ${stream.index}: $e');
        }
        
        tracks.add(AudioTrack(
          index: stream.index,
          name: stream.title,
          isEnabled: true,
          volumePercent: 100,
          originalVolume: originalVolume,
          channels: stream.channels,
          sampleRate: stream.sampleRate,
          codec: stream.codec,
          language: stream.language,
        ));
      }
      return tracks;
    } catch (e) {
      print('Ошибка analyzeAudio: $e');
      return [];
    }
  }

  static String extensionForCodec(String codec) {
    const Map<String, String> map = {
      'aac': 'aac',
      'mp3': 'mp3',
      'ac3': 'ac3',
      'eac3': 'eac3',
      'dts': 'dts',
      'flac': 'flac',
      'opus': 'opus',
      'vorbis': 'ogg',
      'pcm_s16le': 'wav',
      'pcm_s24le': 'wav',
      'pcm_f32le': 'wav',
      'alac': 'm4a',
      'truehd': 'mkv',
    };
    return map[codec] ?? 'mka';
  }

  static Future<String?> extractAudioTrack({
    required String inputPath,
    required String outputDir,
    required AudioTrack track,
  }) async {
    final ext = extensionForCodec(track.codec);
    final audioStreams = await MediaInfoService.getAudioStreams(inputPath);
    final perTypeIdx = audioStreams.indexWhere((s) => s.index == track.index);
    final baseName = track.name.isNotEmpty
        ? track.name
        : 'audio_track_$perTypeIdx';
    final sanitized = baseName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final outputPath = '$outputDir\\$sanitized.$ext';

    final args = [
      '-i', inputPath,
      '-map', '0:a:$perTypeIdx',
      '-c', 'copy',
      '-y', outputPath,
    ];

    final result = await Process.run('ffmpeg', args, runInShell: true);
    if (result.exitCode != 0) {
      print('Ошибка экспорта дорожки: ${result.stderr}');
      return null;
    }
    return outputPath;
  }
}