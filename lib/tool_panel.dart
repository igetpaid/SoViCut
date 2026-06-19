import 'package:flutter/material.dart';
import 'trim_tab.dart';
import 'audio_tab.dart';
import 'export_settings_tab.dart';
import 'clips_tab.dart';
import 'audio_track.dart';
import 'core/theme/app_colors.dart';
import 'core/localization/app_localizations.dart';
import 'clip.dart';

class ToolPanel extends StatelessWidget {
  final TabController tabController;
  final bool trimEnabled;
  final Function(bool) onTrimEnabledChanged;
  final Function(double, int) onTrimChanged;
  final double trimSeconds;
  final int trimMode;
  
  final bool audioMuted;
  final Function(bool) onAudioMutedChanged;
  final List<AudioTrack> audioTracks;
  final Function(List<AudioTrack>) onAudioTracksChanged;
  final bool mixEnabled;
  final Function(bool) onMixEnabledChanged;
  
  final List<Clip> clips;
  final String? videoPath;
  final Function(int) onDeleteClip;
  final Function(int) onRestoreClip;
  final Function(int)? onSelectClip;
  final int? selectedClipIndex;
  
  final int originalAudioBitrate;
  final int originalSampleRate;
  final int originalChannels;
  final Function(ExportSettings) onExportSettingsChanged;
  
  const ToolPanel({
    super.key,
    required this.tabController,
    required this.trimEnabled,
    required this.onTrimEnabledChanged,
    required this.onTrimChanged,
    required this.trimSeconds,
    required this.trimMode,
    required this.audioMuted,
    required this.onAudioMutedChanged,
    required this.audioTracks,
    required this.onAudioTracksChanged,
    required this.mixEnabled,
    required this.onMixEnabledChanged,
    required this.clips,
    required this.videoPath,
    required this.onDeleteClip,
    required this.onRestoreClip,
    this.onSelectClip,
    this.selectedClipIndex,
    required this.originalAudioBitrate,
    required this.originalSampleRate,
    required this.originalChannels,
    required this.onExportSettingsChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.bgSurface,
      child: Column(
        children: [
          Container(
            height: 36,
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: TabBar(
              controller: tabController,
              isScrollable: false,
              labelPadding: EdgeInsets.zero,
              tabs: [
                Tab(text: AppLocalizations.t('tabs.audio')),
                Tab(text: AppLocalizations.t('tabs.clips')),
                Tab(text: AppLocalizations.t('tabs.trim')),
                Tab(text: AppLocalizations.t('tabs.export')),
              ],
              labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
              unselectedLabelStyle: const TextStyle(fontSize: 11),
              labelColor: AppColors.accent,
              unselectedLabelColor: AppColors.textDim,
              indicatorColor: AppColors.accent,
              indicatorWeight: 2,
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: tabController,
              children: [
                AudioTab(
                  muted: audioMuted,
                  onMutedChanged: onAudioMutedChanged,
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
                  onSelect: onSelectClip,
                  selectedIndex: selectedClipIndex,
                ),
                TrimTab(
                  isEnabled: trimEnabled,
                  onEnabledChanged: onTrimEnabledChanged,
                  onTrimChanged: onTrimChanged,
                  initialSeconds: trimSeconds,
                  initialMode: trimMode,
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
    );
  }
}