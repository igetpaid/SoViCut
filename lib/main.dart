import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';

void main() {
  runApp(const SoViCutApp());
}

class SoViCutApp extends StatelessWidget {
  const SoViCutApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SoViCut',
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.orange,
        colorScheme: const ColorScheme.dark(
          primary: Colors.orange,
          secondary: Colors.orange,
        ),
      ),
      home: const MainScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final TextEditingController _trimController = TextEditingController(text: '10');
  String _message = 'Выберите видео или перетащите его сюда';
  String? _videoPath;
  bool _isProcessing = false;
  int _trimMode = 0;
  bool _isDragging = false;

  void _setVideoPath(String path) {
    setState(() {
      _videoPath = path;
      _message = '✅ Видео: ${path.split('\\').last}';
    });
  }

  Future<void> _pickVideo() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        _setVideoPath(result.files.single.path!);
      }
    } catch (e) {
      setState(() {
        _message = '❌ Ошибка выбора файла: $e';
      });
    }
  }

  Future<void> _trimVideo() async {
    if (_videoPath == null || _videoPath!.isEmpty) {
      setState(() {
        _message = '❌ Сначала выберите видео';
      });
      return;
    }

    final seconds = double.tryParse(_trimController.text);
    if (seconds == null || seconds <= 0) {
      setState(() {
        _message = '❌ Введите корректное количество секунд';
      });
      return;
    }

    setState(() {
      _isProcessing = true;
      if (_trimMode == 0) {
        _message = '⏳ Оставляем первые $seconds секунд...';
      } else {
        _message = '⏳ Вырезаем последние $seconds секунд...';
      }
    });

    try {
      final outputDir = await getDownloadsDirectory();
      final fileName = _videoPath!.split('\\').last.replaceFirst('.', '_trimmed.');
      final outputPath = '${outputDir!.path}\\$fileName';
      
      List<String> args;
      if (_trimMode == 0) {
        args = [
          '-i', _videoPath!,
          '-t', seconds.toString(),
          '-c', 'copy',
          '-y',
          outputPath
        ];
      } else {
        final durationResult = await Process.run(
          'ffprobe',
          [
            '-v', 'error',
            '-show_entries', 'format=duration',
            '-of', 'default=noprint_wrappers=1:nokey=1',
            _videoPath!
          ],
          runInShell: true,
        );
        
        if (durationResult.exitCode != 0) {
          setState(() {
            _message = '❌ Не удалось определить длительность видео\n${durationResult.stderr}';
          });
          return;
        }
        
        final duration = double.parse(durationResult.stdout.toString().trim());
        final newDuration = duration - seconds;
        
        if (newDuration <= 0) {
          setState(() {
            _message = '❌ Видео короче, чем $seconds секунд (длина: ${duration.toStringAsFixed(1)}с)';
          });
          return;
        }
        
        args = [
          '-i', _videoPath!,
          '-t', newDuration.toString(),
          '-c', 'copy',
          '-y',
          outputPath
        ];
      }

      final result = await Process.run('ffmpeg', args, runInShell: true);

      if (result.exitCode == 0) {
        if (_trimMode == 0) {
          _message = '✅ Готово! Оставлены первые $seconds секунд\nСохранено в Загрузках\n$fileName';
        } else {
          _message = '✅ Готово! Последние $seconds секунд вырезаны\nСохранено в Загрузках\n$fileName';
        }
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Готово!\n$fileName')),
        );
      } else {
        setState(() {
          _message = '❌ Ошибка FFmpeg (код ${result.exitCode})\n${result.stderr.toString().substring(0, 200)}';
        });
      }
    } catch (e) {
      setState(() {
        _message = '❌ Исключение: $e';
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1a1a1a), Color(0xFF0d0d0d)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'SoViCut',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Sound • Video • Cut',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[400],
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 40),
                
                // Drag & Drop область
                DropTarget(
                  onDragEntered: (detail) {
                    setState(() {
                      _isDragging = true;
                    });
                  },
                  onDragExited: (detail) {
                    setState(() {
                      _isDragging = false;
                    });
                  },
                  onDragDone: (detail) {
                    setState(() {
                      _isDragging = false;
                    });
                    if (detail.files.isNotEmpty && detail.files.first.path != null) {
                      _setVideoPath(detail.files.first.path!);
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    height: 120,
                    decoration: BoxDecoration(
                      color: _isDragging 
                          ? Colors.orange.withOpacity(0.2) 
                          : Colors.grey[900],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _isDragging ? Colors.orange : Colors.grey[800]!,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isDragging ? Icons.file_upload : Icons.drag_handle,
                          size: 40,
                          color: _isDragging ? Colors.orange : Colors.grey[600],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isDragging ? 'Отпустите для загрузки' : 'Перетащите видео сюда',
                          style: TextStyle(
                            color: _isDragging ? Colors.orange : Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Кнопка выбора файла
                ElevatedButton.icon(
                  onPressed: _pickVideo,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Выбрать видео'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[800],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.video_library, size: 48, color: Colors.grey),
                      const SizedBox(height: 12),
                      Text(_message, style: const TextStyle(fontSize: 14, color: Colors.grey), textAlign: TextAlign.center),
                      if (_videoPath != null) ...[
                        const SizedBox(height: 8),
                        Text(_videoPath!, style: const TextStyle(fontSize: 10, color: Colors.grey), textAlign: TextAlign.center),
                      ],
                      const SizedBox(height: 16),
                      
                      Row(
                        children: [
                          Expanded(
                            child: SegmentedButton<int>(
                              segments: const [
                                ButtonSegment(value: 0, label: Text('Оставить первые N секунд')),
                                ButtonSegment(value: 1, label: Text('Вырезать последние N секунд')),
                              ],
                              selected: {_trimMode},
                              onSelectionChanged: (Set<int> newSelection) {
                                setState(() {
                                  _trimMode = newSelection.first;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _trimController,
                              style: const TextStyle(color: Colors.white),
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                hintText: 'Секунд',
                                hintStyle: TextStyle(color: Colors.grey),
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.cut, color: Colors.orange),
                            onPressed: _isProcessing ? null : _trimVideo,
                            tooltip: 'Обрезать',
                          ),
                        ],
                      ),
                      
                      if (_message.startsWith('❌')) ...[
                        const SizedBox(height: 10),
                        TextButton.icon(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: _message));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Текст ошибки скопирован')),
                            );
                          },
                          icon: const Icon(Icons.copy, size: 16),
                          label: const Text('Копировать ошибку'),
                          style: TextButton.styleFrom(foregroundColor: Colors.grey),
                        ),
                      ],
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _trimVideo,
                  icon: _isProcessing
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.play_arrow),
                  label: Text(_isProcessing ? 'Обработка...' : 'Выполнить'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                    textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}