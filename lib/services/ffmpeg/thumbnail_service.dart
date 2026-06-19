import 'dart:io';
import '../../core/constants.dart';

class ThumbnailEntry {
  final double timeInSeconds;
  final String path;

  ThumbnailEntry({required this.timeInSeconds, required this.path});
}

class ThumbnailService {
  /// Generates thumbnails at 1 fps in a single FFmpeg pass.
  /// Returns list of [ThumbnailEntry] sorted by time.
  static Future<List<ThumbnailEntry>> generateThumbnails({
    required String videoPath,
    required String outputDir,
    double? duration,
  }) async {
    final dir = Directory(outputDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    // Single FFmpeg process: decode video once, output 1 frame/second
    // -threads 2: leave CPU for Flutter UI
    await Process.run(
      'ffmpeg',
      [
        '-i', videoPath,
        '-vf', 'fps=1,scale=${AppConstants.scrubThumbnailWidth}:${AppConstants.scrubThumbnailHeight}',
        '-q:v', '10',
        '-vsync', '0',
        '-threads', '2',
        '-y',
        '$outputDir\\thumb_%05d.jpg',
      ],
      runInShell: true,
    );

    // Collect generated files, sorted by name (= by time)
    final files = await dir.list().toList();
    files.sort((a, b) => a.path.compareTo(b.path));

    final entries = <ThumbnailEntry>[];
    for (int i = 0; i < files.length; i++) {
      entries.add(ThumbnailEntry(
        timeInSeconds: i.toDouble(),
        path: files[i].path,
      ));
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
