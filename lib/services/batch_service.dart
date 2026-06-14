import 'dart:io';
import 'dart:math';

class BatchService {
  static Future<String> getMediaDuration(String path) async {
    final result = await Process.run('ffprobe', [
      '-v', 'error',
      '-show_entries', 'format=duration',
      '-of', 'default=noprint_wrappers=1:nokey=1',
      path,
    ], runInShell: true);
    if (result.exitCode == 0) {
      return result.stdout.toString().trim();
    }
    return '0';
  }

  static Future<String?> run({
    required String inputPath,
    required String outputPath,
    required String operation,
    double trimSeconds = 0,
    double trimStart = 0,
    double trimEnd = 0,
    bool trimLast = false,
  }) async {
    final List<String> args = [];

    switch (operation) {
      case 'delete_first':
        args.addAll(['-ss', trimSeconds.toStringAsFixed(2), '-i', inputPath, '-c', 'copy']);
        break;

      case 'delete_last':
        final durationStr = await getMediaDuration(inputPath);
        final duration = double.tryParse(durationStr) ?? 0;
        final newDuration = max(0, duration - trimSeconds);
        args.addAll(['-i', inputPath, '-t', newDuration.toStringAsFixed(2), '-c', 'copy']);
        break;

      case 'trim_first':
        args.addAll(['-ss', trimSeconds.toStringAsFixed(2), '-i', inputPath, '-c', 'copy']);
        break;

      case 'trim_last':
        final durationStr = await getMediaDuration(inputPath);
        final duration = double.tryParse(durationStr) ?? 0;
        final newDuration = max(0, duration - trimSeconds);
        args.addAll(['-i', inputPath, '-t', newDuration.toStringAsFixed(2), '-c', 'copy']);
        break;

      case 'trim_range':
        args.addAll(['-ss', trimStart.toStringAsFixed(2), '-to', trimEnd.toStringAsFixed(2), '-i', inputPath, '-c', 'copy']);
        break;

      case 'container_swap':
        args.addAll(['-i', inputPath, '-c', 'copy']);
        break;

      case 'audio_extract':
        args.addAll(['-i', inputPath, '-map', '0:a', '-c', 'copy']);
        break;

      case 'audio_normalize':
        args.addAll(['-i', inputPath, '-af', 'loudnorm=I=-14:LRA=-11:TP=-1', '-c:v', 'copy']);
        break;

      default:
        return 'Unknown operation: $operation';
    }

    args.addAll(['-y', outputPath]);

    final result = await Process.run('ffmpeg', args, runInShell: true);
    if (result.exitCode != 0) {
      return result.stderr.toString();
    }
    return null;
  }
}
