import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../export_settings_tab.dart';

class ExportState {
  final ExportSettings settings;
  final bool isExporting;
  final double progress;
  final String? error;

  const ExportState({
    this.settings = const ExportSettings(
      audioCodec: AudioCodec.aac,
      bitrateMode: BitrateMode.cbr,
      audioBitrate: 192,
      sampleRate: 48000,
      channels: 2,
      videoCodec: VideoCodec.h264,
      videoQuality: VideoQuality.source,
      crf: 23,
    ),
    this.isExporting = false,
    this.progress = 0,
    this.error,
  });

  ExportState copyWith({
    ExportSettings? settings,
    bool? isExporting,
    double? progress,
    String? error,
  }) {
    return ExportState(
      settings: settings ?? this.settings,
      isExporting: isExporting ?? this.isExporting,
      progress: progress ?? this.progress,
      error: error,
    );
  }
}

class ExportNotifier extends StateNotifier<ExportState> {
  ExportNotifier() : super(const ExportState());

  void updateSettings(ExportSettings settings) {
    state = state.copyWith(settings: settings);
  }

  void setExporting(bool value) {
    state = state.copyWith(isExporting: value, progress: value ? 0 : 100);
  }

  void setProgress(double value) {
    state = state.copyWith(progress: value);
  }

  void setError(String? error) {
    state = state.copyWith(error: error, isExporting: false);
  }

  void reset() {
    state = const ExportState();
  }
}

final exportProvider = StateNotifierProvider<ExportNotifier, ExportState>((ref) {
  return ExportNotifier();
});
