import 'audio_track.dart';
import 'clip.dart';
import 'export_settings_tab.dart';
import 'core/localization/app_localizations.dart';

/// Абстрактный класс для стратегий экспорта
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

/// Merges adjacent visible clips (same source, contiguous time) into single segments.
List<Clip> mergeAdjacentVisibleClips(List<Clip> clips) {
  final visible = clips.where((c) => c.isVisible).toList();
  if (visible.isEmpty) return visible;
  final merged = <Clip>[];
  Clip? current;
  for (final clip in visible) {
    if (current == null) {
      current = clip;
    } else if (current.sourcePath == clip.sourcePath && (clip.startTime - current.endTime).abs() < 0.001) {
      current = Clip(
        id: current.id,
        sourcePath: current.sourcePath,
        startTime: current.startTime,
        endTime: clip.endTime,
        isVisible: true,
      );
    } else {
      merged.add(current);
      current = clip;
    }
  }
  if (current != null) merged.add(current);
  return merged;
}

/// Результат проверки коротких фрагментов
class ShortClipCheckResult {
  final bool hasShortClips;
  final List<int> shortClipIndices;
  final List<double> shortClipDurations;
  final double threshold;

  ShortClipCheckResult({
    required this.hasShortClips,
    required this.shortClipIndices,
    required this.shortClipDurations,
    this.threshold = 0.5,
  });

  String getWarningMessage() {
    if (!hasShortClips) return '';
    final buffer = StringBuffer();
    buffer.writeln(AppLocalizations.t('strategy.shortClipsDetected', {'threshold': '$threshold'}));
    for (int i = 0; i < shortClipIndices.length; i++) {
      buffer.writeln('  ${AppLocalizations.t('strategy.clipInfo', {'number': '${shortClipIndices[i] + 1}', 'duration': shortClipDurations[i].toStringAsFixed(3)})}');
    }
    buffer.writeln();
    buffer.writeln(AppLocalizations.t('strategy.mayCauseArtifacts'));
    buffer.writeln(AppLocalizations.t('strategy.chooseAction'));
    return buffer.toString();
  }
}