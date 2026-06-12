import 'dart:math';

class AudioTrack {
  final int index;
  String name;
  bool isEnabled;
  double volumePercent;
  final double originalVolume;
  final int channels;
  final int sampleRate;
  final String codec;
  final String language;

  AudioTrack({
    required this.index,
    required this.name,
    required this.isEnabled,
    required this.volumePercent,
    required this.originalVolume,
    this.channels = 2,
    this.sampleRate = 48000,
    this.codec = '',
    this.language = '',
  });

  double get finalVolumeDb {
    if (volumePercent == 100) return originalVolume;
    return originalVolume + 20 * log(volumePercent / 100) / ln10;
  }

  double get volumeDb {
    return 20 * log(volumePercent / 100) / ln10;
  }

  set volumeDb(double db) {
    volumePercent = (100 * pow(10, db / 20)).clamp(0, 1000).toDouble();
  }

  String get channelsText {
    switch (channels) {
      case 1: return 'Mono';
      case 2: return 'Stereo';
      case 6: return '5.1';
      case 8: return '7.1';
      default: return '$channels ch';
    }
  }

  String get sampleRateText {
    if (sampleRate >= 1000) return '${(sampleRate / 1000).toStringAsFixed(1)} kHz';
    return '$sampleRate Hz';
  }

  String get volumeFilter {
    if (!isEnabled) return 'volume=0';
    final factor = volumePercent / 100;
    return 'volume=${factor.toStringAsFixed(2)}';
  }

  Map<String, dynamic> toJson() => {
        'index': index,
        'name': name,
        'isEnabled': isEnabled,
        'volumePercent': volumePercent,
        'originalVolume': originalVolume,
        'channels': channels,
        'sampleRate': sampleRate,
        'codec': codec,
        'language': language,
      };

  factory AudioTrack.fromJson(Map<String, dynamic> json) => AudioTrack(
        index: json['index'] as int,
        name: json['name'] as String? ?? '',
        isEnabled: json['isEnabled'] as bool? ?? true,
        volumePercent: (json['volumePercent'] as num?)?.toDouble() ?? 100,
        originalVolume: (json['originalVolume'] as num?)?.toDouble() ?? -100,
        channels: json['channels'] as int? ?? 2,
        sampleRate: json['sampleRate'] as int? ?? 48000,
        codec: json['codec'] as String? ?? '',
        language: json['language'] as String? ?? '',
      );

  AudioTrack copyWith({
    int? index,
    String? name,
    bool? isEnabled,
    double? volumePercent,
    double? originalVolume,
    int? channels,
    int? sampleRate,
    String? codec,
    String? language,
  }) {
    return AudioTrack(
      index: index ?? this.index,
      name: name ?? this.name,
      isEnabled: isEnabled ?? this.isEnabled,
      volumePercent: volumePercent ?? this.volumePercent,
      originalVolume: originalVolume ?? this.originalVolume,
      channels: channels ?? this.channels,
      sampleRate: sampleRate ?? this.sampleRate,
      codec: codec ?? this.codec,
      language: language ?? this.language,
    );
  }
}

const double ln10 = 2.302585092994046;
