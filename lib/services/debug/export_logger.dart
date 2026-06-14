import 'dart:io';
import 'package:path_provider/path_provider.dart';

class ExportLogger {
  final File file;
  final IOSink _sink;
  final DateTime _startTime = DateTime.now();
  bool _closed = false;

  ExportLogger._(this.file, this._sink);

  static Future<ExportLogger> create({String? label}) async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory('${support.path}\\debug\\exports');
    if (!await dir.exists()) await dir.create(recursive: true);
    final ts = _formatFilenameDate(DateTime.now());
    final safeLabel = (label ?? '').replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final name = 'export_$ts${safeLabel.isNotEmpty ? '_$safeLabel' : ''}.txt';
    final file = File('${dir.path}\\$name');
    final sink = file.openWrite();
    return ExportLogger._(file, sink);
  }

  void header(String key, String value) {
    _sink.writeln('$key: $value');
  }

  void section(String title) {
    _sink.writeln('\n=== $title ===');
  }

  void log(String line) {
    _sink.writeln('[${_timestamp()}] $line');
  }

  void command(String executable, List<String> args) {
    _sink.writeln('cmd> $executable ${args.join(' ')}');
  }

  void stderr(String line) {
    _sink.writeln('[${_timestamp()}] [stderr] $line');
  }

  void stdout(String line) {
    _sink.writeln('[${_timestamp()}] [stdout] $line');
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    final elapsed = DateTime.now().difference(_startTime);
    section('Result');
    header('Ended', _formatDateTime(DateTime.now()));
    header('Elapsed', '${elapsed.inSeconds}.${(elapsed.inMilliseconds % 1000).toString().padLeft(3, '0')}s');
    await _sink.flush();
    await _sink.close();
  }

  String _timestamp() {
    final now = DateTime.now();
    final ms = now.millisecond.toString().padLeft(3, '0');
    return '${_pad(now.hour)}:${_pad(now.minute)}:${_pad(now.second)}.$ms';
  }

  static String _formatFilenameDate(DateTime dt) {
    return '${dt.year}${_pad(dt.month)}${_pad(dt.day)}_${_pad(dt.hour)}${_pad(dt.minute)}${_pad(dt.second)}';
  }

  static String _formatDateTime(DateTime dt) {
    return '${dt.year}-${_pad(dt.month)}-${_pad(dt.day)} ${_pad(dt.hour)}:${_pad(dt.minute)}:${_pad(dt.second)}';
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');
}
