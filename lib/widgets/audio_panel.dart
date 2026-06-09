import 'package:flutter/material.dart';
import '../models/audio_track.dart';

class AudioPanel extends StatefulWidget {
  final bool isEnabled;
  final Function(bool) onEnabledChanged;
  final List<AudioTrack> tracks;
  final Function(List<AudioTrack>) onTracksChanged;
  final bool mixEnabled;
  final Function(bool) onMixEnabledChanged;
  
  const AudioPanel({
    super.key,
    required this.isEnabled,
    required this.onEnabledChanged,
    required this.tracks,
    required this.onTracksChanged,
    required this.mixEnabled,
    required this.onMixEnabledChanged,
  });

  @override
  State<AudioPanel> createState() => _AudioPanelState();
}

class _AudioPanelState extends State<AudioPanel> {
  void _toggleTrack(int index) {
    setState(() {
      widget.tracks[index].isEnabled = !widget.tracks[index].isEnabled;
    });
    widget.onTracksChanged(widget.tracks);
  }

  void _changeVolume(int index, double value) {
    setState(() {
      widget.tracks[index].volumePercent = value;
    });
    widget.onTracksChanged(widget.tracks);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Checkbox(
                value: widget.isEnabled,
                onChanged: (val) => widget.onEnabledChanged(val ?? false),
                activeColor: Colors.orange,
              ),
              const Text(
                'Управление аудио',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          if (widget.isEnabled) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Checkbox(
                  value: widget.mixEnabled,
                  onChanged: (val) => widget.onMixEnabledChanged(val ?? false),
                  activeColor: Colors.orange,
                ),
                const Text('Объединить все аудиодорожки в одну'),
              ],
            ),
            const SizedBox(height: 12),
            ...widget.tracks.asMap().entries.map((entry) => _buildTrackItem(entry.key, entry.value)),
            if (widget.tracks.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: Text('Аудиодорожки не найдены')),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildTrackItem(int index, AudioTrack track) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.grey[800],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Checkbox(
                  value: track.isEnabled,
                  onChanged: (_) => _toggleTrack(index),
                  activeColor: Colors.orange,
                ),
                Expanded(child: Text(track.name)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey[700],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('${track.originalVolume.toStringAsFixed(1)} dB'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.volume_up, size: 20, color: Colors.grey),
                Expanded(
                  child: Slider(
                    value: track.volumePercent,
                    min: 0,
                    max: 200,
                    divisions: 200,
                    activeColor: Colors.orange,
                    onChanged: track.isEnabled ? (val) => _changeVolume(index, val) : null,
                  ),
                ),
                SizedBox(
                  width: 50,
                  child: Text('${track.volumePercent.toInt()}%'),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Итоговая: ${track.finalVolumeDb.toStringAsFixed(1)} dB',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}