import 'package:flutter_riverpod/flutter_riverpod.dart';

enum BatchOp { trimFirst, trimLast, trimRange, containerSwap, audioExtract, audioNormalize }

enum BatchStatus { idle, running, completed, cancelled, error }

class BatchFile {
  final String inputPath;
  String? outputPath;
  BatchStatus status;
  String? error;
  double progress;

  BatchFile({
    required this.inputPath,
    this.outputPath,
    this.status = BatchStatus.idle,
    this.error,
    this.progress = 0,
  });

  BatchFile copyWith({
    String? inputPath,
    String? outputPath,
    BatchStatus? status,
    String? error,
    double? progress,
  }) {
    return BatchFile(
      inputPath: inputPath ?? this.inputPath,
      outputPath: outputPath ?? this.outputPath,
      status: status ?? this.status,
      error: error ?? this.error,
      progress: progress ?? this.progress,
    );
  }
}

class BatchState {
  final List<BatchFile> files;
  final BatchOp operation;
  final BatchStatus overallStatus;
  final bool overwriteOutput;
  final double trimSeconds;
  final double trimStart;
  final double trimEnd;
  final String outputDir;
  final String containerExt;

  const BatchState({
    this.files = const [],
    this.operation = BatchOp.containerSwap,
    this.overallStatus = BatchStatus.idle,
    this.overwriteOutput = false,
    this.trimSeconds = 0,
    this.trimStart = 0,
    this.trimEnd = 0,
    this.outputDir = '',
    this.containerExt = 'mkv',
  });

  int get succeeded => files.where((f) => f.status == BatchStatus.completed).length;
  int get failed => files.where((f) => f.status == BatchStatus.error).length;
  int get total => files.length;
  bool get isRunning => overallStatus == BatchStatus.running;

  BatchState copyWith({
    List<BatchFile>? files,
    BatchOp? operation,
    BatchStatus? overallStatus,
    bool? overwriteOutput,
    double? trimSeconds,
    double? trimStart,
    double? trimEnd,
    String? outputDir,
    String? containerExt,
  }) {
    return BatchState(
      files: files ?? this.files,
      operation: operation ?? this.operation,
      overallStatus: overallStatus ?? this.overallStatus,
      overwriteOutput: overwriteOutput ?? this.overwriteOutput,
      trimSeconds: trimSeconds ?? this.trimSeconds,
      trimStart: trimStart ?? this.trimStart,
      trimEnd: trimEnd ?? this.trimEnd,
      outputDir: outputDir ?? this.outputDir,
      containerExt: containerExt ?? this.containerExt,
    );
  }
}

class BatchNotifier extends StateNotifier<BatchState> {
  BatchNotifier() : super(const BatchState());

  void addFiles(List<String> paths) {
    final existing = Set<String>.from(state.files.map((f) => f.inputPath));
    final newFiles = paths.where((p) => !existing.contains(p)).map((p) => BatchFile(inputPath: p));
    state = state.copyWith(files: [...state.files, ...newFiles]);
  }

  void removeFile(int index) {
    final files = List<BatchFile>.from(state.files)..removeAt(index);
    state = state.copyWith(files: files);
  }

  void clearFiles() {
    state = state.copyWith(files: [], overallStatus: BatchStatus.idle);
  }

  void setOperation(BatchOp op) {
    state = state.copyWith(operation: op);
  }

  void setTrimSeconds(double s) {
    state = state.copyWith(trimSeconds: s);
  }

  void setTrimStart(double s) {
    state = state.copyWith(trimStart: s);
  }

  void setTrimEnd(double s) {
    state = state.copyWith(trimEnd: s);
  }

  void setOutputDir(String dir) {
    state = state.copyWith(outputDir: dir);
  }

  void setContainerExt(String ext) {
    state = state.copyWith(containerExt: ext);
  }

  void setOverwrite(bool v) {
    state = state.copyWith(overwriteOutput: v);
  }

  void updateFile(int index, BatchFile file) {
    final files = List<BatchFile>.from(state.files);
    files[index] = file;
    state = state.copyWith(files: files);
  }

  void setOverallStatus(BatchStatus s) {
    state = state.copyWith(overallStatus: s);
  }

  void reset() {
    state = const BatchState();
  }
}

final batchProvider = StateNotifierProvider<BatchNotifier, BatchState>((ref) {
  return BatchNotifier();
});
