import 'dart:io';
import '../../core/constants.dart';

class ThumbnailEntry {
  final double timeInSeconds;
  final String path;

  ThumbnailEntry({required this.timeInSeconds, required this.path});
}

class ThumbnailService {
  static Future<List<ThumbnailEntry>> generateThumbnails({
    required String videoPath,
    required String outputDir,
    required double duration,
  }) async {
    final entries = <ThumbnailEntry>[];
    final dir = Directory(outputDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final interval = AppConstants.scrubThumbnailInterval;
    final count = (duration / interval).ceil();

    for (int i = 0; i < count && i < 3600; i++) {
      final time = i * interval;
      final outFile = '$outputDir\\thumb_${i.toString().padLeft(5, '0')}.jpg';

      final result = await Process.run(
        'ffmpeg',
        [
          '-ss', time.toStringAsFixed(2),
          '-i', videoPath,
          '-vframes', '1',
          '-s', '${AppConstants.scrubThumbnailWidth}x${AppConstants.scrubThumbnailHeight}',
          '-q:v', '10',
          '-y', outFile,
        ],
        runInShell: true,
      );
      if (result.exitCode == 0) {
        entries.add(ThumbnailEntry(timeInSeconds: time, path: outFile));
      }
    }
    return entries;
  }

  static Future<void> cleanThumbnailDir(String dirPath) async {
    try {
      final dir = Directory(dirPath);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (_) {}
  }
}
