import 'dart:io';

class FfmpegCheckResult {
  final bool ffmpegFound;
  final bool ffprobeFound;
  final String? ffmpegPath;
  final String? ffprobePath;
  final String? ffmpegVersion;
  final String? ffprobeVersion;

  const FfmpegCheckResult({
    required this.ffmpegFound,
    required this.ffprobeFound,
    this.ffmpegPath,
    this.ffprobePath,
    this.ffmpegVersion,
    this.ffprobeVersion,
  });

  bool get allFound => ffmpegFound && ffprobeFound;
}

class FfmpegDetectionService {
  static Future<FfmpegCheckResult> check() async {
    final ffmpeg = await _checkTool('ffmpeg');
    final ffprobe = await _checkTool('ffprobe');
    return FfmpegCheckResult(
      ffmpegFound: ffmpeg.found,
      ffprobeFound: ffprobe.found,
      ffmpegPath: ffmpeg.path,
      ffprobePath: ffprobe.path,
      ffmpegVersion: ffmpeg.version,
      ffprobeVersion: ffprobe.version,
    );
  }

  static Future<({bool found, String? path, String? version})> _checkTool(
      String tool) async {
    try {
      final result = await Process.run(
        tool,
        ['-version'],
        runInShell: true,
      );
      if (result.exitCode == 0) {
        final versionLine = result.stdout.toString().split('\n').first;
        return (found: true, path: tool, version: versionLine);
      }
    } catch (_) {}
    return (found: false, path: null, version: null);
  }
}
