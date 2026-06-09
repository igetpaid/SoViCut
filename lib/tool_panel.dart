import 'package:flutter/material.dart';
import 'trim_tab.dart';
import 'audio_tab.dart';
import 'export_tab.dart';
import 'audio_track.dart';
import 'clip.dart';

class ToolPanel extends StatelessWidget {
  final bool trimEnabled;
  final Function(bool) onTrimEnabledChanged;
  final Function(double, int) onTrimChanged;
  final double trimSeconds;
  final int trimMode;
  
  final bool audioEnabled;
  final Function(bool) onAudioEnabledChanged;
  final List<AudioTrack> audioTracks;
  final Function(List<AudioTrack>) onAudioTracksChanged;
  final bool mixEnabled;
  final Function(bool) onMixEnabledChanged;
  
  final List<Clip> clips;
  final String? videoPath;
  
  const ToolPanel({
    super.key,
    required this.trimEnabled,
    required this.onTrimEnabledChanged,
    required this.onTrimChanged,
    required this.trimSeconds,
    required this.trimMode,
    required this.audioEnabled,
    required this.onAudioEnabledChanged,
    required this.audioTracks,
    required this.onAudioTracksChanged,
    required this.mixEnabled,
    required this.onMixEnabledChanged,
    required this.clips,
    required this.videoPath,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[900],
      child: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            const TabBar(
              tabs: [
                Tab(text: 'Обрезка'),
                Tab(text: 'Аудио'),
                Tab(text: 'Инфо'),
              ],
              labelColor: Colors.orange,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.orange,
            ),
            Expanded(
              child: TabBarView(
                children: [
                  TrimTab(
                    isEnabled: trimEnabled,
                    onEnabledChanged: onTrimEnabledChanged,
                    onTrimChanged: onTrimChanged,
                    initialSeconds: trimSeconds,
                    initialMode: trimMode,
                  ),
                  AudioTab(
                    isEnabled: audioEnabled,
                    onEnabledChanged: onAudioEnabledChanged,
                    tracks: audioTracks,
                    onTracksChanged: onAudioTracksChanged,
                    mixEnabled: mixEnabled,
                    onMixEnabledChanged: onMixEnabledChanged,
                  ),
                  ExportTab(
                    audioTracks: audioTracks,
                    clips: clips,
                    videoPath: videoPath,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}