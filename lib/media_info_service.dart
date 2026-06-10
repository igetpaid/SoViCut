import 'dart:io';
import 'dart:convert';

class AudioStreamInfo {
  final int index;
  final String title;
  final String codec;
  final int bitrate; // в kbps
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
      case 1: return 'Моно';
      case 2: return 'Стерео';
      case 6: return '5.1';
      case 8: return '7.1';
      default: return '$channels каналов';
    }
  }
  
  String get bitrateText => bitrate > 0 ? '${bitrate} kbps' : 'переменный';
  
  Map<String, String> get metadata {
    final map = <String, String>{};
    if (title.isNotEmpty) map['title'] = title;
    if (language.isNotEmpty) map['language'] = language;
    if (isDefault) map['default'] = '1';
    if (isForced) map['forced'] = '1';
    return map;
  }
  
  @override
  String toString() => 'AudioStreamInfo(index: $index, title: "$title")';
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
  String get bitrateText => bitrate > 0 ? '${bitrate} kbps' : 'переменный';
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
    if (size < 1024 * 1024 * 1024) return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
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

class MediaInfoService {
  /// Получает полную информацию о медиафайле
  static Future<MediaInfo> getMediaInfo(String path) async {
    final container = await _getContainerInfo(path);
    final videoStreams = await _getVideoStreams(path);
    final audioStreams = await _getAudioStreams(path);
    
    return MediaInfo(
      container: container,
      videoStreams: videoStreams,
      audioStreams: audioStreams,
    );
  }
  
  /// Получает информацию о контейнере
  static Future<ContainerInfo> _getContainerInfo(String path) async {
    final result = await Process.run(
      'ffprobe',
      [
        '-v', 'error',
        '-show_entries', 'format=format_name,size,duration,bit_rate',
        '-of', 'json',
        path
      ],
      runInShell: true,
    );
    
    final json = jsonDecode(result.stdout.toString());
    final format = json['format'];
    
    return ContainerInfo(
      format: format['format_name']?.toString() ?? 'unknown',
      size: _parseInt(format['size']),
      duration: _parseDouble(format['duration']),
      bitrate: _parseInt(format['bit_rate']) ~/ 1000,
    );
  }
  
  /// Получает информацию о видео потоках
  static Future<List<VideoStreamInfo>> _getVideoStreams(String path) async {
    final result = await Process.run(
      'ffprobe',
      [
        '-v', 'error',
        '-select_streams', 'v',
        '-show_entries', 'stream=index,codec_name,bit_rate,width,height,r_frame_rate,pix_fmt,color_space',
        '-of', 'json',
        path
      ],
      runInShell: true,
    );
    
    final List<VideoStreamInfo> streams = [];
    final json = jsonDecode(result.stdout.toString());
    final streamsJson = json['streams'] as List? ?? [];
    
    for (final stream in streamsJson) {
      final fpsStr = stream['r_frame_rate']?.toString() ?? '0/1';
      final fpsParts = fpsStr.split('/');
      double fps = 0;
      if (fpsParts.length == 2) {
        fps = _parseDouble(fpsParts[0]) / _parseDouble(fpsParts[1]);
      }
      
      streams.add(VideoStreamInfo(
        index: _parseInt(stream['index']),
        codec: stream['codec_name']?.toString() ?? 'unknown',
        bitrate: _parseInt(stream['bit_rate']) ~/ 1000,
        width: _parseInt(stream['width']),
        height: _parseInt(stream['height']),
        fps: fps,
        pixelFormat: stream['pix_fmt']?.toString() ?? 'unknown',
        colorSpace: stream['color_space']?.toString() ?? 'unknown',
      ));
    }
    
    return streams;
  }
  
  /// Получает информацию о аудио потоках (ПРАВИЛЬНЫЙ ПАРСИНГ)
  static Future<List<AudioStreamInfo>> _getAudioStreams(String path) async {
    final result = await Process.run(
      'ffprobe',
      [
        '-v', 'error',
        '-select_streams', 'a',
        '-show_entries', 'stream=index,codec_name,bit_rate,sample_rate,channels,disposition:stream_tags',
        '-of', 'json',
        path
      ],
      runInShell: true,
    );
    
    final List<AudioStreamInfo> streams = [];
    final json = jsonDecode(result.stdout.toString());
    final streamsJson = json['streams'] as List? ?? [];
    
    for (final stream in streamsJson) {
      // Извлекаем теги
      final tags = stream['tags'] as Map? ?? {};
      final disposition = stream['disposition'] as Map? ?? {};
      
      String title = tags['title']?.toString() ?? '';
      
      // Если title пустой, пробуем другие варианты
      if (title.isEmpty) {
        title = tags['TAG:title']?.toString() ?? '';
      }
      if (title.isEmpty) {
        title = 'Дорожка ${(_parseInt(stream['index']) + 1)}';
      }
      
      final index = _parseInt(stream['index']);
      final sampleRate = _parseInt(stream['sample_rate']);
      final channels = _parseInt(stream['channels']);
      final bitrate = _parseInt(stream['bit_rate']) ~/ 1000;
      
      print('DEBUG: stream $index - title="$title", sampleRate=$sampleRate, channels=$channels, bitrate=$bitrate');
      
      streams.add(AudioStreamInfo(
        index: index,
        title: title,
        codec: stream['codec_name']?.toString() ?? 'unknown',
        bitrate: bitrate,
        sampleRate: sampleRate,
        channels: channels,
        language: tags['language']?.toString() ?? '',
        isDefault: (_parseInt(disposition['default']) == 1),
        isForced: (_parseInt(disposition['forced']) == 1),
      ));
    }
    
    return streams;
  }
  
  /// Безопасный парсинг int из dynamic
  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    if (value is double) return value.toInt();
    return 0;
  }
  
  /// Безопасный парсинг double из dynamic
  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
  
  /// Быстрое получение только аудио потоков
  static Future<List<AudioStreamInfo>> getAudioStreams(String path) async {
    return _getAudioStreams(path);
  }
  
  /// Получение количества аудио потоков
  static Future<int> getAudioStreamCount(String path) async {
    final streams = await _getAudioStreams(path);
    return streams.length;
  }
}