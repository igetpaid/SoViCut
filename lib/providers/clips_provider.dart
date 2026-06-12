import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/clip.dart';

class ClipsState {
  final List<Clip> clips;
  final int nextId;

  const ClipsState({this.clips = const [], this.nextId = 1});

  ClipsState copyWith({List<Clip>? clips, int? nextId}) {
    return ClipsState(
      clips: clips ?? this.clips,
      nextId: nextId ?? this.nextId,
    );
  }

  double get totalDuration {
    return clips.fold(0.0, (sum, clip) => sum + clip.duration);
  }

  int get visibleCount => clips.where((c) => c.isVisible).length;
}

class ClipsNotifier extends StateNotifier<ClipsState> {
  ClipsNotifier() : super(const ClipsState());

  void setClips(List<Clip> clips) {
    final maxId = clips.isEmpty ? 0 : clips.map((c) => c.id).reduce((a, b) => a > b ? a : b);
    state = ClipsState(clips: clips, nextId: maxId + 1);
  }

  void initFromDuration(double duration, String sourcePath) {
    state = ClipsState(
      clips: [
        Clip(
          id: 0,
          sourcePath: sourcePath,
          startTime: 0,
          endTime: duration,
          isVisible: true,
        ),
      ],
      nextId: 1,
    );
  }

  void splitClip(int clipIndex, double splitTimeInClip) {
    if (clipIndex < 0 || clipIndex >= state.clips.length) return;
    final clip = state.clips[clipIndex];
    if (!clip.isVisible) return;

    final splitAbsolute = clip.startTime + splitTimeInClip;
    final newClips = List<Clip>.from(state.clips);

    newClips[clipIndex] = Clip(
      id: clip.id,
      sourcePath: clip.sourcePath,
      startTime: clip.startTime,
      endTime: splitAbsolute,
      isVisible: true,
    );
    newClips.insert(
      clipIndex + 1,
      Clip(
        id: state.nextId,
        sourcePath: clip.sourcePath,
        startTime: splitAbsolute,
        endTime: clip.endTime,
        isVisible: true,
      ),
    );

    state = ClipsState(clips: newClips, nextId: state.nextId + 1);
  }

  void deleteClip(int clipIndex) {
    if (clipIndex < 0 || clipIndex >= state.clips.length) return;
    final clips = List<Clip>.from(state.clips);
    clips[clipIndex] = clips[clipIndex].copyWith(isVisible: false);
    state = state.copyWith(clips: clips);
  }

  void restoreClip(int clipIndex) {
    if (clipIndex < 0 || clipIndex >= state.clips.length) return;
    final clips = List<Clip>.from(state.clips);
    clips[clipIndex] = clips[clipIndex].copyWith(isVisible: true);
    state = state.copyWith(clips: clips);
  }

  void reset() {
    state = const ClipsState();
  }
}

final clipsProvider = StateNotifierProvider<ClipsNotifier, ClipsState>((ref) {
  return ClipsNotifier();
});
