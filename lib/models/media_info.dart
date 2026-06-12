import '../core/localization/app_localizations.dart';

class AudioStreamInfo {
  final int index;
  final String title;
  final String codec;
  final int bitrate;
  final int sampleRate;
  final int channels;
  final String language;
  final bool isDefault;
  final bool isForced;

  AudioStreamInfo({
    required this.index,
    required this.title,
    required this.codec,
    required this.bitrate,
    required this.sampleRate,
    required this.channels,
    required this.language,
    required this.isDefault,
    required this.isForced,
  });

  String get channelsText {
    switch (channels) {
      case 1:
        return AppLocalizations.t('audio.mono');
      case 2:
        return AppLocalizations.t('audio.stereo');
      case 6:
        return AppLocalizations.t('audio.channels5_1');
      case 8:
        return AppLocalizations.t('audio.channels7_1');
      default:
        return AppLocalizations.t('audio.channelsCount', {'count': '$channels'});
    }
  }

  String get bitrateText =>
      bitrate > 0 ? '${bitrate} kbps' : AppLocalizations.t('mediaInfo.variableBitrate');

  Map<String, String> get metadata {
    final map = <String, String>{};
    if (title.isNotEmpty) map['title'] = title;
    if (language.isNotEmpty) map['language'] = language;
    if (isDefault) map['default'] = '1';
    if (isForced) map['forced'] = '1';
    return map;
  }

  @override
  String toString() =>
      'AudioStreamInfo(index: $index, title: "$title")';
}

class VideoStreamInfo {
  final int index;
  final String codec;
  final int bitrate;
  final int width;
  final int height;
  final double fps;
  final String pixelFormat;
  final String colorSpace;

  VideoStreamInfo({
    required this.index,
    required this.codec,
    required this.bitrate,
    required this.width,
    required this.height,
    required this.fps,
    required this.pixelFormat,
    required this.colorSpace,
  });

  String get resolution => '${width}x$height';
  String get bitrateText =>
      bitrate > 0 ? '${bitrate} kbps' : AppLocalizations.t('mediaInfo.variableBitrate');
  String get fpsText => fps.toStringAsFixed(2);
}

class ContainerInfo {
  final String format;
  final int size;
  final double duration;
  final int bitrate;

  ContainerInfo({
    required this.format,
    required this.size,
    required this.duration,
    required this.bitrate,
  });

  String get sizeText {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String get durationText {
    final dur = Duration(seconds: duration.toInt());
    final hours = dur.inHours;
    final minutes = dur.inMinutes.remainder(60);
    final seconds = dur.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String get bitrateText => '$bitrate kbps';
}

class MediaInfo {
  final ContainerInfo container;
  final List<VideoStreamInfo> videoStreams;
  final List<AudioStreamInfo> audioStreams;

  MediaInfo({
    required this.container,
    required this.videoStreams,
    required this.audioStreams,
  });

  bool get hasVideo => videoStreams.isNotEmpty;
  bool get hasAudio => audioStreams.isNotEmpty;
  int get videoCount => videoStreams.length;
  int get audioCount => audioStreams.length;
}
