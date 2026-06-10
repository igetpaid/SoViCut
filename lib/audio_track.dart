import 'dart:math';

class AudioTrack {
  final int index;
  final String name;
  bool isEnabled;
  double volumePercent;
  final double originalVolume;

  AudioTrack({
    required this.index,
    required this.name,
    required this.isEnabled,
    required this.volumePercent,
    required this.originalVolume,
  });

  double get finalVolumeDb {
    if (volumePercent == 100) return originalVolume;
    return originalVolume + 20 * log(volumePercent / 100) / ln10;
  }

  String get volumeFilter {
    if (!isEnabled) return 'volume=0';
    if (volumePercent == 100) return '';
    final factor = volumePercent / 100;
    return 'volume=${factor.toStringAsFixed(2)}';
  }
}

const double ln10 = 2.302585092994046;