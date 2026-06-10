import 'dart:io';
import 'audio_track.dart';
import 'clip.dart';
import 'export_settings_tab.dart';

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
  });

  String get name;
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
    buffer.writeln('⚠️ Обнаружены очень короткие фрагменты (< $threshold сек):');
    for (int i = 0; i < shortClipIndices.length; i++) {
      buffer.writeln('  Фрагмент ${shortClipIndices[i] + 1}: ${shortClipDurations[i].toStringAsFixed(3)} сек');
    }
    buffer.writeln('\nЭто может привести к артефактам или потере звука.');
    buffer.writeln('Выберите способ обработки:');
    return buffer.toString();
  }
}