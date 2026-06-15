import 'package:flutter/material.dart';
import 'audio_track.dart';
import 'media_info_service.dart';
import 'models/media_info.dart';
import 'core/localization/app_localizations.dart';

enum AudioCodec { aac, mp3, pcm }
enum BitrateMode { cbr, vbr }
enum VideoCodec { h264, h265, vp9 }
enum VideoQuality { source, high, medium, low }

class ExportSettings {
  final AudioCodec audioCodec;
  final BitrateMode bitrateMode;
  final int audioBitrate;
  final int sampleRate;
  final int channels;
  final VideoCodec videoCodec;
  final VideoQuality videoQuality;
  final int crf;
  final bool preserveOriginalTrackNames;
  final bool preserveAllAudioStreams;
  final List<int> enabledAudioStreams;
  final bool mixToSingleTrack;
  final Map<int, String> originalTrackTitles;
  
  const ExportSettings({
    required this.audioCodec,
    required this.bitrateMode,
    required this.audioBitrate,
    required this.sampleRate,
    required this.channels,
    required this.videoCodec,
    required this.videoQuality,
    required this.crf,
    this.preserveOriginalTrackNames = true,
    this.preserveAllAudioStreams = true,
    this.enabledAudioStreams = const [],
    this.mixToSingleTrack = false,
    this.originalTrackTitles = const {},
  });

  static const youtube = ExportSettings(
    audioCodec: AudioCodec.aac,
    bitrateMode: BitrateMode.cbr,
    audioBitrate: 192,
    sampleRate: 48000,
    channels: 2,
    videoCodec: VideoCodec.h264,
    videoQuality: VideoQuality.high,
    crf: 18,
  );

  static const telegram = ExportSettings(
    audioCodec: AudioCodec.aac,
    bitrateMode: BitrateMode.vbr,
    audioBitrate: 128,
    sampleRate: 44100,
    channels: 1,
    videoCodec: VideoCodec.h264,
    videoQuality: VideoQuality.medium,
    crf: 23,
  );

  static const archive = ExportSettings(
    audioCodec: AudioCodec.aac,
    bitrateMode: BitrateMode.cbr,
    audioBitrate: 320,
    sampleRate: 48000,
    channels: 2,
    videoCodec: VideoCodec.h264,
    videoQuality: VideoQuality.source,
    crf: 18,
  );
  
  factory ExportSettings.defaults({
    required int originalBitrate,
    required int originalSampleRate,
    required int originalChannels,
  }) {
    return ExportSettings(
      audioCodec: AudioCodec.aac,
      bitrateMode: BitrateMode.cbr,
      audioBitrate: originalBitrate ~/ 1000,
      sampleRate: originalSampleRate,
      channels: originalChannels,
      videoCodec: VideoCodec.h264,
      videoQuality: VideoQuality.source,
      crf: 23,
      preserveOriginalTrackNames: true,
      preserveAllAudioStreams: true,
      enabledAudioStreams: const [],
      mixToSingleTrack: false,
      originalTrackTitles: const {},
    );
  }
  
  String get audioCodecName {
    switch (audioCodec) {
      case AudioCodec.aac: return 'aac';
      case AudioCodec.mp3: return 'libmp3lame';
      case AudioCodec.pcm: return 'pcm_s16le';
    }
  }
  
  String get videoCodecName {
    switch (videoCodec) {
      case VideoCodec.h264: return 'libx264';
      case VideoCodec.h265: return 'libx265';
      case VideoCodec.vp9: return 'libvpx-vp9';
    }
  }
  
  ExportSettings copyWith({
    AudioCodec? audioCodec,
    BitrateMode? bitrateMode,
    int? audioBitrate,
    int? sampleRate,
    int? channels,
    VideoCodec? videoCodec,
    VideoQuality? videoQuality,
    int? crf,
    bool? preserveOriginalTrackNames,
    bool? preserveAllAudioStreams,
    List<int>? enabledAudioStreams,
    bool? mixToSingleTrack,
    Map<int, String>? originalTrackTitles,
  }) {
    return ExportSettings(
      audioCodec: audioCodec ?? this.audioCodec,
      bitrateMode: bitrateMode ?? this.bitrateMode,
      audioBitrate: audioBitrate ?? this.audioBitrate,
      sampleRate: sampleRate ?? this.sampleRate,
      channels: channels ?? this.channels,
      videoCodec: videoCodec ?? this.videoCodec,
      videoQuality: videoQuality ?? this.videoQuality,
      crf: crf ?? this.crf,
      preserveOriginalTrackNames: preserveOriginalTrackNames ?? this.preserveOriginalTrackNames,
      preserveAllAudioStreams: preserveAllAudioStreams ?? this.preserveAllAudioStreams,
      enabledAudioStreams: enabledAudioStreams ?? this.enabledAudioStreams,
      mixToSingleTrack: mixToSingleTrack ?? this.mixToSingleTrack,
      originalTrackTitles: originalTrackTitles ?? this.originalTrackTitles,
    );
  }
}

class ExportSettingsTab extends StatefulWidget {
  final String? videoPath;
  final List<AudioTrack> audioTracks;
  final Function(ExportSettings) onSettingsChanged;
  
  const ExportSettingsTab({
    super.key,
    required this.videoPath,
    required this.audioTracks,
    required this.onSettingsChanged,
  });

  @override
  State<ExportSettingsTab> createState() => _ExportSettingsTabState();
}

class _ExportSettingsTabState extends State<ExportSettingsTab> {
  late ExportSettings _settings;
  MediaInfo? _mediaInfo;
  bool _isLoading = true;
  String _error = '';
  double _estimatedOutputSizeMb = 0;
  
  @override
  void initState() {
    super.initState();
    _settings = ExportSettings.defaults(
      originalBitrate: 192000,
      originalSampleRate: 48000,
      originalChannels: 2,
    );
    _loadMediaInfo();
  }
  
  Future<void> _loadMediaInfo() async {
    if (widget.videoPath == null) {
      setState(() {
        _isLoading = false;
        _error = AppLocalizations.t('export.notLoaded');
      });
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      _mediaInfo = await MediaInfoService.getMediaInfo(widget.videoPath!);
      
      final Map<int, String> originalTitles = {};
      for (final stream in _mediaInfo!.audioStreams) {
        originalTitles[stream.index] = stream.title;
      }
      
      _settings = _settings.copyWith(
        originalTrackTitles: originalTitles,
      );
      
      if (_mediaInfo!.audioStreams.isNotEmpty) {
        final firstAudio = _mediaInfo!.audioStreams.first;
        _settings = _settings.copyWith(
          sampleRate: firstAudio.sampleRate,
          channels: firstAudio.channels,
          audioBitrate: firstAudio.bitrate > 0 ? firstAudio.bitrate : 192,
        );
      }
      
      _calculateEstimatedSize();
      _notifyChanged();
    } catch (e) {
      _error = AppLocalizations.t('errors.genericError', {'error': '$e'});
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  void _calculateEstimatedSize() {
    if (_mediaInfo == null) return;
    
    double estimatedSizeMb = _mediaInfo!.container.size / (1024 * 1024);
    
    if (_settings.audioBitrate != _mediaInfo!.container.bitrate) {
      final durationSec = _mediaInfo!.container.duration;
      final audioSizeOld = (_mediaInfo!.container.bitrate * 1000 * durationSec) / 8 / (1024 * 1024);
      final audioSizeNew = (_settings.audioBitrate * 1000 * durationSec) / 8 / (1024 * 1024);
      estimatedSizeMb = estimatedSizeMb - audioSizeOld + audioSizeNew;
    }
    
    if (_settings.videoQuality != VideoQuality.source && _mediaInfo!.videoStreams.isNotEmpty) {
      double estimatedVideoBitrate = 2000;
      final pixels = _mediaInfo!.videoStreams.first.width * _mediaInfo!.videoStreams.first.height;
      if (pixels <= 640 * 480) { estimatedVideoBitrate = 500; }
      else if (pixels <= 1280 * 720) { estimatedVideoBitrate = 1500; }
      else if (pixels <= 1920 * 1080) { estimatedVideoBitrate = 3000; }
      else if (pixels <= 3840 * 2160) { estimatedVideoBitrate = 8000; }
      else { estimatedVideoBitrate = 12000; }

      if (_settings.crf < 18) { estimatedVideoBitrate *= 2; }
      else if (_settings.crf > 28) { estimatedVideoBitrate *= 0.5; }
      
      final durationSec = _mediaInfo!.container.duration;
      final videoSizeNew = (estimatedVideoBitrate * 1000 * durationSec) / 8 / (1024 * 1024);
      final videoSizeOld = _mediaInfo!.videoStreams.first.bitrate * durationSec / 8 / (1024 * 1024);
      estimatedSizeMb = estimatedSizeMb - videoSizeOld + videoSizeNew;
    }
    
    _estimatedOutputSizeMb = estimatedSizeMb;
  }
  
  void _notifyChanged() {
    _calculateEstimatedSize();
    widget.onSettingsChanged(_settings);
  }
  
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '📊 ${AppLocalizations.t('export.title')}',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.orange),
          ),
          const SizedBox(height: 16),
          
          _buildPresetsSection(),
          const SizedBox(height: 16),
          
          _buildFileInfoSection(),
          const SizedBox(height: 24),
          const Divider(color: Colors.orange),
          const SizedBox(height: 16),
          
          _buildAudioSettingsSection(),
          const SizedBox(height: 24),
          const Divider(color: Colors.orange),
          const SizedBox(height: 16),
          
          _buildVideoSettingsSection(),
          const SizedBox(height: 24),
          const Divider(color: Colors.orange),
          const SizedBox(height: 16),
          
          _buildSizeEstimationSection(),
        ],
      ),
    );
  }
  
  Widget _buildPresetsSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[700]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.flash_on, color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                Text('🎯 ${AppLocalizations.t('export.presets')}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const Divider(height: 0, color: Colors.grey),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _presetButton('YouTube', ExportSettings.youtube, Icons.play_circle_outline),
                const SizedBox(width: 8),
                _presetButton('Telegram', ExportSettings.telegram, Icons.send_outlined),
                const SizedBox(width: 8),
                _presetButton('Archive', ExportSettings.archive, Icons.archive_outlined),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _presetButton(String label, ExportSettings preset, IconData icon) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            setState(() {
              _settings = preset;
            });
            _notifyChanged();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: identical(_settings, preset) ? Colors.orange : Colors.grey[700]!,
                width: identical(_settings, preset) ? 2 : 1,
              ),
              color: identical(_settings, preset) ? Colors.orange.withValues(alpha: 0.1) : null,
            ),
            child: Column(
              children: [
                Icon(icon, color: identical(_settings, preset) ? Colors.orange : Colors.grey, size: 20),
                const SizedBox(height: 4),
                Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFileInfoSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[700]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Icons.info, color: Colors.orange, size: 20),
                SizedBox(width: 8),
                Text('📁 ${AppLocalizations.t('export.fileInfo')}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const Divider(height: 0, color: Colors.grey),
          
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_error, style: const TextStyle(color: Colors.red)),
            )
          else if (_mediaInfo != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow(AppLocalizations.t('export.format'), _mediaInfo!.container.format.toUpperCase()),
                  _buildInfoRow(AppLocalizations.t('export.fileSize'), _mediaInfo!.container.sizeText),
                  _buildInfoRow(AppLocalizations.t('export.duration'), _mediaInfo!.container.durationText),
                  _buildInfoRow(AppLocalizations.t('export.bitrate'), _mediaInfo!.container.bitrateText),
                  
                  const SizedBox(height: 12),
                  Text(AppLocalizations.t('export.videoSection'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ..._mediaInfo!.videoStreams.map((v) => Padding(
                    padding: const EdgeInsets.only(left: 12, top: 4),
                    child: Text(
                      '• ${v.codec.toUpperCase()} | ${v.resolution} | ${v.fpsText} fps | ${v.bitrateText}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  )),
                  
                  const SizedBox(height: 12),
                  Text(AppLocalizations.t('export.audioSection'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ..._mediaInfo!.audioStreams.asMap().entries.map((entry) => Padding(
                    padding: const EdgeInsets.only(left: 12, top: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${entry.key + 1}. "${entry.value.title}"',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white),
                        ),
                        Text(
                          '   ${entry.value.codec.toUpperCase()} | ${entry.value.bitrateText} | ${entry.value.sampleRate} Hz | ${entry.value.channelsText}${entry.value.language.isNotEmpty ? ' | ${entry.value.language}' : ''}',
                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildAudioSettingsSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[700]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.audiotrack, color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                Text('🎚️ ${AppLocalizations.t('export.audioSettings')}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const Divider(height: 0, color: Colors.grey),
          
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  title: Text(AppLocalizations.t('export.preserveTracks')),
                  subtitle: Text(AppLocalizations.t('export.preserveTracksDesc')),
                  value: _settings.preserveOriginalTrackNames,
                  onChanged: (val) {
                    setState(() => _settings = _settings.copyWith(preserveOriginalTrackNames: val));
                    _notifyChanged();
                  },
                  activeThumbColor: Colors.orange,
                  contentPadding: EdgeInsets.zero,
                ),
                
                SwitchListTile(
                  title: Text(AppLocalizations.t('export.preserveAll')),
                  subtitle: Text(AppLocalizations.t('export.preserveAllDesc')),
                  value: _settings.preserveAllAudioStreams,
                  onChanged: (val) {
                    setState(() => _settings = _settings.copyWith(preserveAllAudioStreams: val));
                    _notifyChanged();
                  },
                  activeThumbColor: Colors.orange,
                  contentPadding: EdgeInsets.zero,
                ),
                
                if (!_settings.preserveAllAudioStreams && _mediaInfo != null)
                  Column(
                    children: [
                      const SizedBox(height: 8),
                      Text(AppLocalizations.t('export.selectTracks'), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 8),
                      ..._mediaInfo!.audioStreams.map((stream) => CheckboxListTile(
                        title: Text(stream.title, style: const TextStyle(fontSize: 13)),
                        subtitle: Text('${stream.codec.toUpperCase()} | ${stream.bitrateText}'),
                        value: _settings.enabledAudioStreams.contains(stream.index),
                        onChanged: (val) {
                          setState(() {
                            final newList = List<int>.from(_settings.enabledAudioStreams);
                            if (val == true) {
                              newList.add(stream.index);
                            } else {
                              newList.remove(stream.index);
                            }
                            _settings = _settings.copyWith(enabledAudioStreams: newList);
                          });
                          _notifyChanged();
                        },
                        activeColor: Colors.orange,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      )),
                    ],
                  ),
                
                const SizedBox(height: 12),
                const Divider(color: Colors.grey),
                const SizedBox(height: 12),
                
                SwitchListTile(
                  title: Text(AppLocalizations.t('export.mixToSingle')),
                  subtitle: Text(AppLocalizations.t('export.mixToSingleDesc')),
                  value: _settings.mixToSingleTrack,
                  onChanged: (val) {
                    setState(() => _settings = _settings.copyWith(mixToSingleTrack: val));
                    _notifyChanged();
                  },
                  activeThumbColor: Colors.orange,
                  contentPadding: EdgeInsets.zero,
                ),
                
                const SizedBox(height: 12),
                const Divider(color: Colors.grey),
                const SizedBox(height: 12),
                
                _buildDropdown(
                  label: AppLocalizations.t('export.audioCodec'),
                  value: _settings.audioCodec,
                  items: const [
                    DropdownMenuItem(value: AudioCodec.aac, child: Text('AAC')),
                    DropdownMenuItem(value: AudioCodec.mp3, child: Text('MP3')),
                    DropdownMenuItem(value: AudioCodec.pcm, child: Text('PCM / WAV')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _settings = _settings.copyWith(audioCodec: val));
                      _notifyChanged();
                    }
                  },
                ),
                
                const SizedBox(height: 12),
                
                _buildDropdown(
                  label: AppLocalizations.t('export.bitrateMode'),
                  value: _settings.bitrateMode,
                  items: [
                    const DropdownMenuItem(value: BitrateMode.cbr, child: Text('CBR')),
                    const DropdownMenuItem(value: BitrateMode.vbr, child: Text('VBR')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _settings = _settings.copyWith(bitrateMode: val));
                      _notifyChanged();
                    }
                  },
                ),
                
                const SizedBox(height: 12),
                
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(AppLocalizations.t('export.bitrateValue', {'value': '${_settings.audioBitrate}'})),
                          Slider(
                            value: _settings.audioBitrate.toDouble(),
                            min: 32,
                            max: 512,
                            divisions: (512 - 32) ~/ 16,
                            activeColor: Colors.orange,
                            onChanged: (val) {
                              setState(() => _settings = _settings.copyWith(audioBitrate: val.toInt()));
                              _notifyChanged();
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 80,
                      child: TextField(
                        controller: TextEditingController(text: _settings.audioBitrate.toString()),
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'kbps',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (val) {
                          final int? newVal = int.tryParse(val);
                          if (newVal != null && newVal >= 32 && newVal <= 512) {
                            setState(() => _settings = _settings.copyWith(audioBitrate: newVal));
                            _notifyChanged();
                          }
                        },
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                _buildDropdown(
                  label: AppLocalizations.t('export.sampleRate'),
                  value: _settings.sampleRate,
                  items: const [
                    DropdownMenuItem(value: 22050, child: Text('22.05 kHz')),
                    DropdownMenuItem(value: 44100, child: Text('44.1 kHz')),
                    DropdownMenuItem(value: 48000, child: Text('48 kHz')),
                    DropdownMenuItem(value: 96000, child: Text('96 kHz')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _settings = _settings.copyWith(sampleRate: val));
                      _notifyChanged();
                    }
                  },
                ),
                
                const SizedBox(height: 12),
                
                _buildDropdown(
                  label: AppLocalizations.t('export.channels'),
                  value: _settings.channels,
                  items: [
                    DropdownMenuItem(value: 1, child: Text(AppLocalizations.t('audio.mono'))),
                    DropdownMenuItem(value: 2, child: Text(AppLocalizations.t('audio.stereo'))),
                    const DropdownMenuItem(value: 6, child: Text('5.1')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _settings = _settings.copyWith(channels: val));
                      _notifyChanged();
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildVideoSettingsSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[700]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.video_settings, color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                Text('🎬 ${AppLocalizations.t('export.videoSettings')}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const Divider(height: 0, color: Colors.grey),
          
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDropdown(
                  label: AppLocalizations.t('export.videoCodec'),
                  value: _settings.videoCodec,
                  items: const [
                    DropdownMenuItem(value: VideoCodec.h264, child: Text('H.264 / AVC')),
                    DropdownMenuItem(value: VideoCodec.h265, child: Text('H.265 / HEVC')),
                    DropdownMenuItem(value: VideoCodec.vp9, child: Text('VP9')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _settings = _settings.copyWith(videoCodec: val));
                      _notifyChanged();
                    }
                  },
                ),
                
                const SizedBox(height: 12),
                
                _buildDropdown(
                  label: AppLocalizations.t('export.quality'),
                  value: _settings.videoQuality,
                  items: [
                    DropdownMenuItem(value: VideoQuality.source, child: Text(AppLocalizations.t('export.source'))),
                    DropdownMenuItem(value: VideoQuality.high, child: Text(AppLocalizations.t('export.high'))),
                    DropdownMenuItem(value: VideoQuality.medium, child: Text(AppLocalizations.t('export.medium'))),
                    DropdownMenuItem(value: VideoQuality.low, child: Text(AppLocalizations.t('export.low'))),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      int newCrf = _settings.crf;
                      if (val == VideoQuality.high) newCrf = 18;
                      if (val == VideoQuality.medium) newCrf = 23;
                      if (val == VideoQuality.low) newCrf = 28;
                      setState(() => _settings = _settings.copyWith(videoQuality: val, crf: newCrf));
                      _notifyChanged();
                    }
                  },
                ),
                
                if (_settings.videoQuality == VideoQuality.source)
          Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'ℹ️ ${AppLocalizations.t('export.noReencode')}',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ),
                
                if (_settings.videoQuality != VideoQuality.source) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(AppLocalizations.t('export.crf', {'value': '${_settings.crf}'})),
                            Slider(
                              value: _settings.crf.toDouble(),
                              min: 0,
                              max: 51,
                              divisions: 51,
                              activeColor: Colors.orange,
                              onChanged: (val) {
                                setState(() => _settings = _settings.copyWith(crf: val.toInt()));
                                _notifyChanged();
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 60,
                        child: TextField(
                          controller: TextEditingController(text: _settings.crf.toString()),
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(border: OutlineInputBorder()),
                          onChanged: (val) {
                            final int? newVal = int.tryParse(val);
                            if (newVal != null && newVal >= 0 && newVal <= 51) {
                              setState(() => _settings = _settings.copyWith(crf: newVal));
                              _notifyChanged();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSizeEstimationSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.calculate, color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                Text('📈 ${AppLocalizations.t('export.sizeEstimate')}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const Divider(height: 0, color: Colors.grey),
          
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                _buildInfoRow(AppLocalizations.t('export.originalSize'), _mediaInfo?.container.sizeText ?? '—'),
                _buildInfoRow(AppLocalizations.t('export.estimatedSize'), '${_estimatedOutputSizeMb.toStringAsFixed(1)} MB'),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: _mediaInfo != null ? (_estimatedOutputSizeMb / (_mediaInfo!.container.size / (1024 * 1024))) : 0,
                  backgroundColor: Colors.grey[700],
                  color: Colors.orange,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 140, child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }
  
  Widget _buildDropdown<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required Function(T?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[800]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              items: items,
              onChanged: onChanged,
              dropdownColor: Colors.grey[900],
              style: const TextStyle(color: Colors.white),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              isExpanded: true,
            ),
          ),
        ),
      ],
    );
  }
}