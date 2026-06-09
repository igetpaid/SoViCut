import 'package:flutter/material.dart';
import 'audio_track.dart';
import 'clip.dart';

class ExportTab extends StatelessWidget {
  final List<AudioTrack> audioTracks;
  final List<Clip> clips;
  final String? videoPath;
  
  const ExportTab({
    super.key,
    required this.audioTracks,
    required this.clips,
    this.videoPath,
  });

  double get totalDuration {
    return clips.fold(0.0, (sum, clip) => sum + clip.duration);
  }

  String formatDuration(double seconds) {
    final duration = Duration(seconds: seconds.toInt());
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final secs = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  String getFileNameWithoutExtension(String path) {
    final fileName = path.split('\\').last;
    final lastDot = fileName.lastIndexOf('.');
    if (lastDot == -1) return fileName;
    return fileName.substring(0, lastDot);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Информация о видео',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _infoRow('Исходный файл', videoPath?.split('\\').last ?? '—'),
          const Divider(),
          _infoRow('Исходная длительность', videoPath != null ? formatDuration(totalDuration) : '—'),
          const Divider(),
          _infoRow('Длительность после обрезки', formatDuration(totalDuration)),
          const Divider(),
          _infoRow('Аудиодорожек', '${audioTracks.length}'),
          const SizedBox(height: 8),
          ...audioTracks.map((track) => Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 4),
            child: Text(
              '• ${track.name} (${track.originalVolume.toStringAsFixed(1)} dB)',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          )),
          const Divider(),
          _infoRow('Фрагментов', '${clips.length} (${clips.where((c) => c.isVisible).length} видимых)'),
          const Divider(),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Сохранится как:',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                Text(
                  videoPath != null 
                      ? '${getFileNameWithoutExtension(videoPath!)}_edited.mp4'
                      : '—',
                  style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                ),
                const SizedBox(height: 8),
                const Text(
                  'в папку:',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                Text(
                  videoPath != null 
                      ? videoPath!.substring(0, videoPath!.lastIndexOf('\\'))
                      : '—',
                  style: const TextStyle(fontSize: 11, color: Colors.grey, fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Widget _infoRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ],
    ),
  );
}