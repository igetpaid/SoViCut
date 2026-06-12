import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/audio_track.dart';

class AudioState {
  final List<AudioTrack> tracks;
  final bool enabled;
  final bool mixEnabled;

  const AudioState({
    this.tracks = const [],
    this.enabled = false,
    this.mixEnabled = false,
  });

  AudioState copyWith({
    List<AudioTrack>? tracks,
    bool? enabled,
    bool? mixEnabled,
  }) {
    return AudioState(
      tracks: tracks ?? this.tracks,
      enabled: enabled ?? this.enabled,
      mixEnabled: mixEnabled ?? this.mixEnabled,
    );
  }
}

class AudioNotifier extends StateNotifier<AudioState> {
  AudioNotifier() : super(const AudioState());

  void setTracks(List<AudioTrack> tracks) {
    state = state.copyWith(tracks: tracks);
  }

  void toggleTrack(int index) {
    final tracks = List<AudioTrack>.from(state.tracks);
    tracks[index].isEnabled = !tracks[index].isEnabled;
    state = state.copyWith(tracks: tracks);
  }

  void setVolume(int index, double percent) {
    final tracks = List<AudioTrack>.from(state.tracks);
    tracks[index].volumePercent = percent;
    state = state.copyWith(tracks: tracks);
  }

  void setVolumeDb(int index, double db) {
    final tracks = List<AudioTrack>.from(state.tracks);
    tracks[index].volumeDb = db;
    state = state.copyWith(tracks: tracks);
  }

  void setEnabled(bool value) {
    state = state.copyWith(enabled: value);
  }

  void setMixEnabled(bool value) {
    state = state.copyWith(mixEnabled: value);
  }

  void normalizeTrack(int index, double targetLufs) {
    final tracks = List<AudioTrack>.from(state.tracks);
    final track = tracks[index];
    if (track.originalVolume > -100) {
      final delta = targetLufs - track.originalVolume;
      track.volumeDb = delta;
    }
    state = state.copyWith(tracks: tracks);
  }

  void renameTrack(int index, String newName) {
    final tracks = List<AudioTrack>.from(state.tracks);
    state = state.copyWith(tracks: [
      for (int i = 0; i < tracks.length; i++)
        if (i == index)
          tracks[i].copyWith(name: newName)
        else
          tracks[i],
    ]);
  }

  void reset() {
    state = const AudioState();
  }
}

final audioProvider = StateNotifierProvider<AudioNotifier, AudioState>((ref) {
  return AudioNotifier();
});
