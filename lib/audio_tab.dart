import 'dart:io';
import 'package:flutter/material.dart';
import 'ffmpeg_service.dart';
import 'audio_track.dart';
import 'core/theme/app_colors.dart';
import 'core/localization/app_localizations.dart';

class AudioTab extends StatefulWidget {
  final bool isEnabled;
  final Function(bool) onEnabledChanged;
  final List<AudioTrack> tracks;
  final Function(List<AudioTrack>) onTracksChanged;
  final bool mixEnabled;
  final Function(bool) onMixEnabledChanged;
  final String? inputPath;

  const AudioTab({
    super.key,
    required this.isEnabled,
    required this.onEnabledChanged,
    required this.tracks,
    required this.onTracksChanged,
    required this.mixEnabled,
    required this.onMixEnabledChanged,
    this.inputPath,
  });

  @override
  State<AudioTab> createState() => _AudioTabState();
}

class _AudioTabState extends State<AudioTab> {
  int? _editingIndex;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildEnableRow(),
          if (widget.isEnabled) ...[
            const SizedBox(height: 8),
            _buildMixRow(),
            const SizedBox(height: 12),
            if (widget.tracks.isEmpty)
              _buildEmptyState()
            else
              ...widget.tracks.asMap().entries.map((entry) =>
                _buildTrackCard(entry.key, entry.value)),
          ],
        ],
      ),
    );
  }

  Widget _buildEnableRow() {
    return Row(
      children: [
        SizedBox(
          height: 24,
          child: Checkbox(
            value: widget.isEnabled,
            onChanged: (val) => widget.onEnabledChanged(val ?? false),
            activeColor: AppColors.accent,
          ),
        ),
        const SizedBox(width: 8),
        Text(AppLocalizations.t('audio.configure'), style: TextStyle(fontSize: 13, color: AppColors.textPrimary)),
      ],
    );
  }

  Widget _buildMixRow() {
    return Row(
      children: [
        SizedBox(
          height: 24,
          child: Checkbox(
            value: widget.mixEnabled,
            onChanged: (val) => widget.onMixEnabledChanged(val ?? false),
            activeColor: AppColors.accent,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(AppLocalizations.t('audio.mixTracks'),
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Text(AppLocalizations.t('audio.noTracks'),
            style: TextStyle(fontSize: 12, color: AppColors.textDim)),
      ),
    );
  }

  Widget _buildTrackCard(int index, AudioTrack track) {
    final isEditing = _editingIndex == index;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _buildTrackHeader(index, track, isEditing),
          if (track.isEnabled) ...[
            _buildTrackDetails(track),
            _buildVolumeControl(track, index),
            _buildTrackActions(index, track),
          ],
        ],
      ),
    );
  }

  Widget _buildTrackHeader(int index, AudioTrack track, bool isEditing) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
      child: Row(
        children: [
          SizedBox(
            height: 20,
            child: Checkbox(
              value: track.isEnabled,
              onChanged: (_) => _toggleTrack(index),
              activeColor: AppColors.accent,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: isEditing
                ? _buildRenameField(index, track)
                : GestureDetector(
                    onDoubleTap: () => setState(() => _editingIndex = index),
                    child: Text(
                      track.name.isNotEmpty ? track.name : AppLocalizations.t('audio.track', {'number': '${index + 1}'}),
                      style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
          ),
          Text(
            '${track.finalVolumeDb.toStringAsFixed(1)} dB',
            style: TextStyle(fontSize: 11, color: AppColors.textDim),
          ),
        ],
      ),
    );
  }

  Widget _buildRenameField(int index, AudioTrack track) {
    final controller = TextEditingController(text: track.name);
    return SizedBox(
      height: 28,
      child: TextField(
        controller: controller,
        style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(color: AppColors.accent),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(color: AppColors.accent),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(color: AppColors.accent, width: 2),
          ),
          isDense: true,
        ),
        autofocus: true,
        onSubmitted: (val) {
          _renameTrack(index, val);
          setState(() => _editingIndex = null);
        },
        onTapOutside: (_) {
          _renameTrack(index, controller.text);
          setState(() => _editingIndex = null);
        },
      ),
    );
  }

  Widget _buildTrackDetails(AudioTrack track) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          _chip(track.channelsText),
          const SizedBox(width: 4),
          _chip(track.sampleRateText),
          if (track.codec.isNotEmpty) ...[
            const SizedBox(width: 4),
            _chip(track.codec.toUpperCase()),
          ],
          if (track.language.isNotEmpty) ...[
            const SizedBox(width: 4),
            _chip(track.language.toUpperCase()),
          ],
        ],
      ),
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.bgHover,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(text, style: TextStyle(fontSize: 9, color: AppColors.textDim)),
    );
  }

  Widget _buildVolumeControl(AudioTrack track, int index) {
    final db = track.volumeDb;
    final absMin = track.originalVolume - 60;
    final absMax = track.originalVolume + 12;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.volume_up, size: 14, color: AppColors.textDim),
              const SizedBox(width: 4),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                  ),
                  child: Slider(
                    value: db.clamp(-60.0, 12.0),
                    min: -60,
                    max: 12,
                    divisions: 720,
                    activeColor: AppColors.accent,
                    onChanged: (val) => _changeVolume(index, val),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              SizedBox(
                width: 52,
                child: Text(
                  '${db.toStringAsFixed(1)} dB',
                  style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Icon(Icons.volume_down, size: 14, color: AppColors.textDim.withValues(alpha: 0.4)),
              const SizedBox(width: 4),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                  ),
                  child: Slider(
                    value: track.finalVolumeDb.clamp(absMin, absMax),
                    min: absMin,
                    max: absMax,
                    divisions: 720,
                    activeColor: AppColors.accent.withValues(alpha: 0.35),
                    onChanged: (val) => _changeVolumeAbsolute(index, val),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              SizedBox(
                width: 52,
                child: Text(
                  '${track.finalVolumeDb.toStringAsFixed(1)} dB',
                  style: TextStyle(fontSize: 10, color: AppColors.textDim),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Text('${AppLocalizations.t('audio.originalVolume')}: ${track.originalVolume.toStringAsFixed(1)} dB',
                  style: TextStyle(fontSize: 9, color: AppColors.textDim)),
              const Spacer(),
              Text('${AppLocalizations.t('audio.finalVolume')}: ${track.finalVolumeDb.toStringAsFixed(1)} dB',
                  style: TextStyle(fontSize: 9, color: AppColors.textDim)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrackActions(int index, AudioTrack track) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
      child: Row(
        children: [
          _actionButton(
            icon: Icons.auto_awesome,
            label: AppLocalizations.t('audio.normalize'),
            tooltip: AppLocalizations.t('audio.normalizeTo'),
            onTap: () => _normalizeTrack(index),
          ),
          const SizedBox(width: 4),
          _actionButton(
            icon: Icons.file_download_outlined,
            label: AppLocalizations.t('audio.exportTrack'),
            tooltip: AppLocalizations.t('audio.exportTrack'),
            onTap: () => _exportTrack(index),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 12, color: AppColors.textDim),
                const SizedBox(width: 4),
                Text(label,
                    style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _toggleTrack(int index) {
    setState(() {
      widget.tracks[index].isEnabled = !widget.tracks[index].isEnabled;
    });
    widget.onTracksChanged(widget.tracks);
  }

  void _changeVolume(int index, double db) {
    setState(() {
      widget.tracks[index].volumeDb = db;
    });
    widget.onTracksChanged(widget.tracks);
  }

  void _changeVolumeAbsolute(int index, double absoluteDb) {
    setState(() {
      widget.tracks[index].volumeDb = absoluteDb - widget.tracks[index].originalVolume;
    });
    widget.onTracksChanged(widget.tracks);
  }

  void _renameTrack(int index, String newName) {
    if (newName.trim().isEmpty) return;
    setState(() {
      widget.tracks[index].name = newName.trim();
    });
    widget.onTracksChanged(widget.tracks);
  }

  void _normalizeTrack(int index) {
    final track = widget.tracks[index];
    if (track.originalVolume <= -100) return;

    const targetLUFS = -14.0;
    final delta = targetLUFS - track.originalVolume;
    setState(() {
      widget.tracks[index].volumeDb = delta;
    });
    widget.onTracksChanged(widget.tracks);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.t('audio.normalizationInfo', {
            'original': track.originalVolume.toStringAsFixed(1),
            'target': targetLUFS.toStringAsFixed(1),
          }),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _exportTrack(int index) async {
    final track = widget.tracks[index];
    if (widget.tracks.isEmpty || widget.inputPath == null) return;

    final dir = File(widget.inputPath!).parent;
    if (!await dir.exists()) return;

    final result = await FFmpegService.extractAudioTrack(
      inputPath: widget.inputPath!,
      outputDir: dir.path,
      track: track,
    );

    if (result != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.t('audio.exported', {'result': result})),
          duration: const Duration(seconds: 3),
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.t('audio.exportError', {'name': track.name})),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}
