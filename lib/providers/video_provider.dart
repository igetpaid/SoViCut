import 'package:flutter_riverpod/flutter_riverpod.dart';

class VideoState {
  final String? path;
  final double duration;
  final double previewPosition;

  const VideoState({
    this.path,
    this.duration = 0,
    this.previewPosition = 0,
  });

  VideoState copyWith({
    String? path,
    double? duration,
    double? previewPosition,
  }) {
    return VideoState(
      path: path ?? this.path,
      duration: duration ?? this.duration,
      previewPosition: previewPosition ?? this.previewPosition,
    );
  }

  String get fileName {
    if (path == null) return '';
    return path!.split('\\').last.split('/').last;
  }
}

class VideoNotifier extends StateNotifier<VideoState> {
  VideoNotifier() : super(const VideoState());

  void loadVideo(String path) {
    state = VideoState(path: path);
  }

  void setDuration(double duration) {
    state = state.copyWith(duration: duration);
  }

  void setPreviewPosition(double position) {
    state = state.copyWith(previewPosition: position);
  }

  void reset() {
    state = const VideoState();
  }
}

final videoProvider = StateNotifierProvider<VideoNotifier, VideoState>((ref) {
  return VideoNotifier();
});
