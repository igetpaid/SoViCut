import 'dart:io';

class FFmpegUtils {
  /// Анализирует видеофайл и возвращает Map с информацией о потоках.
  /// Ключи: 'video' - список индексов видеопотоков, 'audio' - список индексов аудиопотоков.
  static Future<Map<String, List<int>>> getStreamIndices(String videoPath) async {
    final result = await Process.run(
      'ffprobe',
      [
        '-v', 'error',
        '-show_entries', 'stream=index,codec_type',
        '-of', 'default=noprint_wrappers=1:nokey=1',
        videoPath
      ],
      runInShell: true,
    );

    final lines = result.stdout.toString().trim().split('\n');
    final List<int> videoIndices = [];
    final List<int> audioIndices = [];

    for (int i = 0; i < lines.length; i++) {
      if (lines[i] == 'codec_type=video' && i > 0) {
        final indexLine = lines[i - 1];
        if (indexLine.startsWith('index=')) {
          final int index = int.parse(indexLine.split('=')[1]);
          videoIndices.add(index);
        }
      } else if (lines[i] == 'codec_type=audio' && i > 0) {
        final indexLine = lines[i - 1];
        if (indexLine.startsWith('index=')) {
          final int index = int.parse(indexLine.split('=')[1]);
          audioIndices.add(index);
        }
      }
    }

    return {'video': videoIndices, 'audio': audioIndices};
  }

  /// Строит аргументы для ffmpeg, чтобы скопировать ВСЕ потоки (видео и аудио) из исходного файла.
  static Future<List<String>> buildCopyAllStreamsArgs(String inputPath) async {
    final indices = await getStreamIndices(inputPath);
    final args = <String>[];

    // Добавляем все видеопотоки
    for (final idx in indices['video']!) {
      args.addAll(['-map', '0:v:$idx']);
    }

    // Добавляем все аудиопотоки (0-based per-type индекс)
    for (int i = 0; i < indices['audio']!.length; i++) {
      args.addAll(['-map', '0:a:$i']);
    }

    return args;
  }
}