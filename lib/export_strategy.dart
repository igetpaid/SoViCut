import 'audio_track.dart';
import 'clip.dart';
import 'export_settings_tab.dart';

abstract class ExportStrategy {
  Future<bool> export({
    required String inputPath,
    required String outputPath,
    required List<AudioTrack> audioTracks,
    required bool mixAudio,
    double? trimSeconds,
    int? trimMode,
    required List<Clip> clips,
    ExportSettings? exportSettings,
    void Function(double progress, String stage)? onProgress,
    bool Function()? isCancelled,
  });

  String get name;
}
