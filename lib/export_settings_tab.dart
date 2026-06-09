import 'package:flutter/material.dart';

class ExportSettingsTab extends StatefulWidget {
  final int originalAudioBitrate;
  final int originalSampleRate;
  final int originalChannels;
  final Function(ExportSettings) onSettingsChanged;
  
  const ExportSettingsTab({
    super.key,
    required this.originalAudioBitrate,
    required this.originalSampleRate,
    required this.originalChannels,
    required this.onSettingsChanged,
  });

  @override
  State<ExportSettingsTab> createState() => _ExportSettingsTabState();
}

class _ExportSettingsTabState extends State<ExportSettingsTab> {
  bool _customEnabled = false;
  
  // Audio settings
  AudioCodec _audioCodec = AudioCodec.aac;
  BitrateMode _bitrateMode = BitrateMode.cbr;
  int _customBitrate = 192;
  int _sampleRate = 48000;
  int _channels = 2;
  
  // Video settings
  bool _videoSettingsEnabled = false;
  VideoCodec _videoCodec = VideoCodec.h264;
  VideoQuality _videoQuality = VideoQuality.source;
  int _customCrf = 23;
  
  @override
  void initState() {
    super.initState();
    _customBitrate = widget.originalAudioBitrate ~/ 1000;
    _sampleRate = widget.originalSampleRate;
    _channels = widget.originalChannels;
  }

  void _notifyChanged() {
    if (!_customEnabled) {
      widget.onSettingsChanged(ExportSettings.defaults(
        originalBitrate: widget.originalAudioBitrate,
        originalSampleRate: widget.originalSampleRate,
        originalChannels: widget.originalChannels,
      ));
      return;
    }
    
    widget.onSettingsChanged(ExportSettings(
      audioCodec: _audioCodec,
      bitrateMode: _bitrateMode,
      audioBitrate: _customBitrate,
      sampleRate: _sampleRate,
      channels: _channels,
      videoCodec: _videoCodec,
      videoQuality: _videoQuality,
      crf: _customCrf,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Заголовок
          const Text(
            'Настройка экспорта',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const Divider(),
          
          // ========== АУДИО ==========
          Row(
            children: [
              const Icon(Icons.audiotrack, size: 20, color: Colors.orange),
              const SizedBox(width: 8),
              const Text('Аудио', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              Switch(
                value: _customEnabled,
                onChanged: (val) {
                  setState(() {
                    _customEnabled = val;
                  });
                  _notifyChanged();
                },
                activeColor: Colors.orange,
              ),
              const SizedBox(width: 8),
              Text(_customEnabled ? 'Пользовательские' : 'Как в исходном'),
            ],
          ),
          
          if (_customEnabled) ...[
            const SizedBox(height: 16),
            
            // Кодек
            _buildDropdown(
              label: 'Аудио кодек',
              value: _audioCodec,
              items: const [
                DropdownMenuItem(value: AudioCodec.aac, child: Text('AAC (рекомендуется)')),
                DropdownMenuItem(value: AudioCodec.mp3, child: Text('MP3')),
                DropdownMenuItem(value: AudioCodec.pcm, child: Text('PCM / WAV (без сжатия)')),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() => _audioCodec = val);
                  _notifyChanged();
                }
              },
            ),
            
            const SizedBox(height: 12),
            
            // Режим битрейта
            _buildDropdown(
              label: 'Режим битрейта',
              value: _bitrateMode,
              items: const [
                DropdownMenuItem(value: BitrateMode.cbr, child: Text('CBR (Constant Bitrate) — точный размер')),
                DropdownMenuItem(value: BitrateMode.vbr, child: Text('VBR (Variable Bitrate) — лучшее качество/размер')),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() => _bitrateMode = val);
                  _notifyChanged();
                }
              },
            ),
            
            const SizedBox(height: 12),
            
            // Битрейт
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Битрейт: ${_customBitrate} kbps'),
                      Slider(
                        value: _customBitrate.toDouble(),
                        min: 32,
                        max: 512,
                        divisions: (512 - 32) ~/ 16,
                        activeColor: Colors.orange,
                        onChanged: (val) {
                          setState(() => _customBitrate = val.toInt());
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
                    controller: TextEditingController(text: _customBitrate.toString()),
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'kbps',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) {
                      final int? newVal = int.tryParse(val);
                      if (newVal != null && newVal >= 32 && newVal <= 512) {
                        setState(() => _customBitrate = newVal);
                        _notifyChanged();
                      }
                    },
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Частота дискретизации
            _buildDropdown(
              label: 'Частота дискретизации',
              value: _sampleRate,
              items: const [
                DropdownMenuItem(value: 22050, child: Text('22.05 kHz (AM радио)')),
                DropdownMenuItem(value: 44100, child: Text('44.1 kHz (CD качество)')),
                DropdownMenuItem(value: 48000, child: Text('48 kHz (стандарт видео)')),
                DropdownMenuItem(value: 96000, child: Text('96 kHz (Hi-Res)')),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() => _sampleRate = val);
                  _notifyChanged();
                }
              },
            ),
            
            const SizedBox(height: 12),
            
            // Количество каналов
            _buildDropdown(
              label: 'Каналов',
              value: _channels,
              items: const [
                DropdownMenuItem(value: 1, child: Text('Моно')),
                DropdownMenuItem(value: 2, child: Text('Стерео')),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() => _channels = val);
                  _notifyChanged();
                }
              },
            ),
          ],
          
          const SizedBox(height: 24),
          const Divider(),
          
          // ========== ВИДЕО ==========
          Row(
            children: [
              const Icon(Icons.video_settings, size: 20, color: Colors.orange),
              const SizedBox(width: 8),
              const Text('Видео', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              Switch(
                value: _videoSettingsEnabled,
                onChanged: (val) {
                  setState(() {
                    _videoSettingsEnabled = val;
                  });
                  _notifyChanged();
                },
                activeColor: Colors.orange,
              ),
              const SizedBox(width: 8),
              Text(_videoSettingsEnabled ? 'Пользовательские' : 'Как в исходном'),
            ],
          ),
          
          if (_videoSettingsEnabled) ...[
            const SizedBox(height: 16),
            
            // Кодек
            _buildDropdown(
              label: 'Видео кодек',
              value: _videoCodec,
              items: const [
                DropdownMenuItem(value: VideoCodec.h264, child: Text('H.264 / AVC (совместимый)')),
                DropdownMenuItem(value: VideoCodec.h265, child: Text('H.265 / HEVC (меньше размер)')),
                DropdownMenuItem(value: VideoCodec.vp9, child: Text('VP9 (WebM)')),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() => _videoCodec = val);
                  _notifyChanged();
                }
              },
            ),
            
            const SizedBox(height: 12),
            
            // Качество
            _buildDropdown(
              label: 'Качество',
              value: _videoQuality,
              items: const [
                DropdownMenuItem(value: VideoQuality.source, child: Text('Исходное (без перекодирования)')),
                DropdownMenuItem(value: VideoQuality.high, child: Text('Высокое (CRF 18)')),
                DropdownMenuItem(value: VideoQuality.medium, child: Text('Среднее (CRF 23)')),
                DropdownMenuItem(value: VideoQuality.low, child: Text('Низкое (CRF 28)')),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() => _videoQuality = val);
                  if (val == VideoQuality.high) _customCrf = 18;
                  if (val == VideoQuality.medium) _customCrf = 23;
                  if (val == VideoQuality.low) _customCrf = 28;
                  _notifyChanged();
                }
              },
            ),
            
            if (_videoQuality == VideoQuality.source) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info, size: 16, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'При выборе "Исходное" видео будет скопировано без перекодирования (быстро, без потери качества).',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            if (_videoQuality != VideoQuality.source) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('CRF (качество): ${_customCrf} (меньше = лучше)'),
                        Slider(
                          value: _customCrf.toDouble(),
                          min: 0,
                          max: 51,
                          divisions: 51,
                          activeColor: Colors.orange,
                          onChanged: (val) {
                            setState(() => _customCrf = val.toInt());
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
                      controller: TextEditingController(text: _customCrf.toString()),
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (val) {
                        final int? newVal = int.tryParse(val);
                        if (newVal != null && newVal >= 0 && newVal <= 51) {
                          setState(() => _customCrf = newVal);
                          _notifyChanged();
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ],
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

// ========== МОДЕЛИ ДАННЫХ ==========

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
  
  ExportSettings({
    required this.audioCodec,
    required this.bitrateMode,
    required this.audioBitrate,
    required this.sampleRate,
    required this.channels,
    required this.videoCodec,
    required this.videoQuality,
    required this.crf,
  });
  
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
}