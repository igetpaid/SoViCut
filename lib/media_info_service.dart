import 'dart:io';
import 'dart:convert';
import 'models/media_info.dart';

class MediaInfoService {
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
      final tags = stream['tags'] as Map? ?? {};
      final disposition = stream['disposition'] as Map? ?? {};
      final int index = _parseInt(stream['index']);
      String title = tags['title']?.toString() ?? '';
      if (title.isEmpty) {
        title = tags['TAG:title']?.toString() ?? '';
      }
      streams.add(AudioStreamInfo(
        index: index,
        title: title,
        codec: stream['codec_name']?.toString() ?? 'unknown',
        bitrate: _parseInt(stream['bit_rate']) ~/ 1000,
        sampleRate: _parseInt(stream['sample_rate']),
        channels: _parseInt(stream['channels']),
        language: tags['language']?.toString() ?? '',
        isDefault: (_parseInt(disposition['default']) == 1),
        isForced: (_parseInt(disposition['forced']) == 1),
      ));
    }
    streams.sort((a, b) => a.index.compareTo(b.index));
    return streams;
  }
  
  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    if (value is double) return value.toInt();
    return 0;
  }
  
  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
  
  static Future<List<AudioStreamInfo>> getAudioStreams(String path) async {
    return _getAudioStreams(path);
  }
  
  static Future<int> getAudioStreamCount(String path) async {
    final streams = await _getAudioStreams(path);
    return streams.length;
  }
}
