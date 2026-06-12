import 'package:flutter/material.dart';
import 'trim_tab.dart';
import 'audio_tab.dart';
import 'export_settings_tab.dart';
import 'clips_tab.dart';
import 'audio_track.dart';
import 'core/localization/app_localizations.dart';
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
  final Function(int) onDeleteClip;
  final Function(int) onRestoreClip;
  
  final int originalAudioBitrate;
  final int originalSampleRate;
  final int originalChannels;
  final Function(ExportSettings) onExportSettingsChanged;
  
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
    required this.onDeleteClip,
    required this.onRestoreClip,
    required this.originalAudioBitrate,
    required this.originalSampleRate,
    required this.originalChannels,
    required this.onExportSettingsChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[900],
      child: DefaultTabController(
        length: 4,
        child: Column(
          children: [
            TabBar(
              tabs: [
                Tab(text: AppLocalizations.t('tabs.trim')),
                Tab(text: AppLocalizations.t('tabs.audio')),
                Tab(text: AppLocalizations.t('tabs.clips')),
                Tab(text: AppLocalizations.t('tabs.export')),
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
                    inputPath: videoPath,
                  ),
                  ClipsTab(
                    clips: clips,
                    onDelete: onDeleteClip,
                    onRestore: onRestoreClip,
                  ),
                  ExportSettingsTab(
                    videoPath: videoPath,
                    audioTracks: audioTracks,
                    onSettingsChanged: onExportSettingsChanged,
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