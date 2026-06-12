import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

class FFmpegUtils {
  /// Анализирует видеофайл и возвращает Map с информацией о потоках.
  /// Ключи: 'video' - список индексов видеопотоков, 'audio' - список индексов аудиопотоков.
  static Future<Map<String, List<int>>> getStreamIndices(String videoPath) async {
    final result = await Process.run(
      'ffprobe',
      [
        '-v', 'error',
        '-show_entries', 'stream=index,codec_type',
        '-of', 'default=noprint_wrappers=1:nokey=1',
        videoPath
      ],
      runInShell: true,
    );

    final lines = result.stdout.toString().trim().split('\n');
    final List<int> videoIndices = [];
    final List<int> audioIndices = [];

    for (int i = 0; i < lines.length; i++) {
      if (lines[i] == 'codec_type=video' && i > 0) {
        final indexLine = lines[i - 1];
        if (indexLine.startsWith('index=')) {
          final int index = int.parse(indexLine.split('=')[1]);
          videoIndices.add(index);
        }
      } else if (lines[i] == 'codec_type=audio' && i > 0) {
        final indexLine = lines[i - 1];
        if (indexLine.startsWith('index=')) {
          final int index = int.parse(indexLine.split('=')[1]);
          audioIndices.add(index);
        }
      }
    }

    return {'video': videoIndices, 'audio': audioIndices};
  }

  /// Строит аргументы для ffmpeg, чтобы скопировать ВСЕ потоки (видео и аудио) из исходного файла.
  static Future<List<String>> buildCopyAllStreamsArgs(String inputPath) async {
    final indices = await getStreamIndices(inputPath);
    final args = <String>[];

    // Добавляем все видеопотоки
    for (final idx in indices['video']!) {
      args.addAll(['-map', '0:v:$idx']);
    }

    // Добавляем все аудиопотоки (0-based per-type индекс)
    for (int i = 0; i < indices['audio']!.length; i++) {
      args.addAll(['-map', '0:a:$i']);
    }

    return args;
  }

  /// Запускает ffmpeg с отслеживанием прогресса.
  /// [args] — аргументы ffmpeg (без `-progress` и `-nostats` — добавляются автоматически).
  /// [totalDuration] — общая длительность в секундах для расчёта процента.
  /// [onProgress] — callback с прогрессом 0.0–1.0.
  /// [cancel] — когда становится true, процесс ffmpeg убивается.
  /// Возвращает exit code (или -1 если отменён).
  static Future<int> runWithProgress({
    required List<String> args,
    required double totalDuration,
    void Function(double progress)? onProgress,
    ValueNotifier<bool>? cancel,
  }) async {
    final progressArgs = [
      ...args,
      '-progress', 'pipe:1',
      '-nostats',
    ];

    final process = await Process.start('ffmpeg', progressArgs,
        runInShell: true,
    );

    cancel?.addListener(() {
      if (cancel.value) {
        process.kill();
      }
    });

    process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      if (line.startsWith('out_time_us=')) {
        final us = int.tryParse(line.split('=')[1]);
        if (us != null && totalDuration > 0) {
          final progress = (us / 1000000 / totalDuration).clamp(0.0, 1.0);
          onProgress?.call(progress);
        }
      }
    });

    process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      if (line.trim().isNotEmpty) {
        print('[ffmpeg] $line');
      }
    });

    final code = await process.exitCode;
    if (cancel?.value == true) return -1;
    return code;
  }
}