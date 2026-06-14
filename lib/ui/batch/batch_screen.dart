import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/batch_provider.dart';
import '../../services/batch_service.dart';
import '../../core/localization/app_localizations.dart';

class BatchScreen extends ConsumerWidget {
  const BatchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(batchProvider);
    final notifier = ref.read(batchProvider.notifier);

    return Container(
      color: AppColors.bgDark,
      child: Column(
        children: [
          _buildToolbar(context, state, notifier),
          Divider(height: 1, color: AppColors.border),
          Expanded(
            child: Row(
              children: [
                Expanded(flex: 3, child: _buildFileList(context, state, notifier)),
                Container(width: 1, color: AppColors.border),
                SizedBox(width: 320, child: _buildSettings(context, state, notifier)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(BuildContext context, BatchState state, BatchNotifier notifier) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: AppColors.bgSurface,
      child: Row(
        children: [
          Text(AppLocalizations.t('batch.title'),
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(width: 16),
          _toolButton(AppLocalizations.t('batch.addFiles'), Icons.add, () => _pickFiles(context, notifier)),
          const SizedBox(width: 4),
          _toolButton(AppLocalizations.t('batch.clear'), Icons.clear_all, state.files.isEmpty ? null : () => notifier.clearFiles()),
          const Spacer(),
          if (state.files.isNotEmpty)
            Text(AppLocalizations.t('batch.summary', {'total': '${state.total}', 'succeeded': '${state.succeeded}', 'failed': '${state.failed}'}),
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(width: 8),
          _runButton(context, state, notifier),
        ],
      ),
    );
  }

  Widget _toolButton(String label, IconData icon, VoidCallback? onPressed) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: onPressed != null ? AppColors.textDim : AppColors.textDim.withValues(alpha: 0.3)),
              if (label.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(label,
                    style: TextStyle(fontSize: 11,
                        color: onPressed != null ? AppColors.textSecondary : AppColors.textDim.withValues(alpha: 0.3))),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _runButton(BuildContext context, BatchState state, BatchNotifier notifier) {
    final canRun = state.files.isNotEmpty && !state.isRunning;
    return SizedBox(
      height: 32,
      child: ElevatedButton.icon(
        onPressed: canRun ? () => _runBatch(context, notifier, state) : null,
        icon: state.isRunning
            ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.bgDark))
            : Icon(state.overallStatus == BatchStatus.completed ? Icons.check : Icons.play_arrow, size: 14),
        label: Text(_runLabel(state)),
        style: ElevatedButton.styleFrom(
          backgroundColor: state.overallStatus == BatchStatus.completed ? Colors.green : AppColors.accent,
          foregroundColor: AppColors.bgDark,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
    );
  }

  String _runLabel(BatchState state) {
    if (state.isRunning) return '...';
    if (state.overallStatus == BatchStatus.completed) return AppLocalizations.t('batch.complete');
    return AppLocalizations.t('batch.start');
  }

  Widget _buildFileList(BuildContext context, BatchState state, BatchNotifier notifier) {
    if (state.files.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.queue_play_next_outlined, size: 48, color: AppColors.textDim.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text(AppLocalizations.t('batch.dropFiles'),
                style: TextStyle(fontSize: 12, color: AppColors.textDim)),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () => _pickFiles(context, notifier),
              icon: Icon(Icons.add, size: 14, color: AppColors.accent),
              label: Text(AppLocalizations.t('batch.addFiles'), style: TextStyle(fontSize: 12, color: AppColors.accent)),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(4),
      itemCount: state.files.length,
      itemBuilder: (context, index) {
        final file = state.files[index];
        final name = file.inputPath.split(Platform.pathSeparator).last;
        return Container(
          margin: const EdgeInsets.only(bottom: 2),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(4),
          ),
          child: ListTile(
            dense: true,
            leading: _statusIcon(file.status),
            title: Text(name,
                style: TextStyle(fontSize: 11, color: AppColors.textPrimary),
                overflow: TextOverflow.ellipsis),
            trailing: IconButton(
              icon: Icon(Icons.close, size: 14, color: AppColors.textDim),
              onPressed: state.isRunning ? null : () => notifier.removeFile(index),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
        );
      },
    );
  }

  Widget _statusIcon(BatchStatus status) {
    switch (status) {
      case BatchStatus.idle:
        return Icon(Icons.circle_outlined, size: 14, color: AppColors.textDim);
      case BatchStatus.running:
        return SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent));
      case BatchStatus.completed:
        return Icon(Icons.check_circle, size: 14, color: Colors.green);
      case BatchStatus.cancelled:
        return Icon(Icons.cancel, size: 14, color: Colors.orange);
      case BatchStatus.error:
        return Icon(Icons.error, size: 14, color: Colors.red);
    }
  }

  Widget _buildSettings(BuildContext context, BatchState state, BatchNotifier notifier) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocalizations.t('batch.operations'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          ...BatchOp.values.map((op) => _opRadio(op, state.operation, (v) => notifier.setOperation(v))),
          const SizedBox(height: 16),
          ..._buildOpSettings(context, state, notifier),
          const SizedBox(height: 16),
          Text(AppLocalizations.t('batch.outputFolder'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          _buildOutputDir(state, notifier),
          if (state.operation == BatchOp.containerSwap) ...[
            const SizedBox(height: 12),
            Text(AppLocalizations.t('batch.containerFormat'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            _buildContainerExtPicker(state, notifier),
          ],
        ],
      ),
    );
  }

  Widget _opRadio(BatchOp op, BatchOp current, ValueChanged<BatchOp> onChanged) {
    final labels = {
      BatchOp.deleteFirst: AppLocalizations.t('batch.deleteFirst'),
      BatchOp.deleteLast: AppLocalizations.t('batch.deleteLast'),
      BatchOp.trimFirst: AppLocalizations.t('batch.keepFirst'),
      BatchOp.trimLast: AppLocalizations.t('batch.keepLast'),
      BatchOp.trimRange: AppLocalizations.t('batch.removeRange'),
      BatchOp.containerSwap: AppLocalizations.t('batch.convertContainer'),
      BatchOp.audioExtract: AppLocalizations.t('batch.extractAudio'),
      BatchOp.audioNormalize: AppLocalizations.t('batch.normalizeAudio'),
    };
    return InkWell(
      onTap: () => onChanged(op),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Icon(
              op == current ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              size: 16,
              color: op == current ? AppColors.accent : AppColors.textDim,
            ),
            const SizedBox(width: 8),
            Text(labels[op] ?? '',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildOpSettings(BuildContext context, BatchState state, BatchNotifier notifier) {
    switch (state.operation) {
      case BatchOp.deleteFirst:
      case BatchOp.trimFirst:
        return [
          _labeledSlider(context, AppLocalizations.t('batch.secondsFromStart'), state.trimSeconds, 0, 3600, (v) => notifier.setTrimSeconds(v)),
        ];
      case BatchOp.deleteLast:
      case BatchOp.trimLast:
        return [
          _labeledSlider(context, AppLocalizations.t('batch.secondsFromEnd'), state.trimSeconds, 0, 3600, (v) => notifier.setTrimSeconds(v)),
        ];
      case BatchOp.trimRange:
        return [
          _labeledSlider(context, AppLocalizations.t('batch.fromSec'), state.trimStart, 0, 3600, (v) => notifier.setTrimStart(v)),
          const SizedBox(height: 8),
          _labeledSlider(context, AppLocalizations.t('batch.toSec'), state.trimEnd, 0, 3600, (v) => notifier.setTrimEnd(v)),
        ];
      case BatchOp.containerSwap:
      case BatchOp.audioExtract:
      case BatchOp.audioNormalize:
        return [];
    }
  }

  Widget _labeledSlider(BuildContext context, String label, double value, double min, double max, ValueChanged<double> onChanged) {
    final controller = TextEditingController(text: value.toStringAsFixed(3));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                ),
                child: Slider(
                  value: value.clamp(min, max),
                  min: min,
                  max: max,
                  activeColor: AppColors.textSecondary,
                  onChanged: (v) {
                    onChanged(v);
                    controller.text = v.toStringAsFixed(3);
                  },
                ),
              ),
            ),
            SizedBox(
              width: 70,
              child: TextField(
                controller: controller,
                style: TextStyle(fontSize: 11, color: AppColors.textPrimary),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: AppColors.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: AppColors.textSecondary)),
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                onSubmitted: (t) {
                  final v = double.tryParse(t);
                  if (v != null && v >= min && v <= max) {
                    onChanged(v);
                  } else {
                    controller.text = value.toStringAsFixed(3);
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOutputDir(BatchState state, BatchNotifier notifier) {
    return InkWell(
      onTap: () async {
        final dir = await FilePicker.platform.getDirectoryPath();
        if (dir != null) notifier.setOutputDir(dir);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(Icons.folder_open, size: 14, color: AppColors.textDim),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                state.outputDir.isEmpty ? AppLocalizations.t('common.selectFolder') : state.outputDir,
                style: TextStyle(
                  fontSize: 11,
                  color: state.outputDir.isEmpty ? AppColors.textDim : AppColors.textSecondary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContainerExtPicker(BatchState state, BatchNotifier notifier) {
    final exts = ['mkv', 'avi', 'mov', 'webm', 'ts', 'mp4'];
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: exts.map((ext) {
        final isSelected = state.containerExt == ext;
        return InkWell(
          onTap: () => notifier.setContainerExt(ext),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.accent.withValues(alpha: 0.15) : AppColors.bgCard,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: isSelected ? AppColors.accent : AppColors.border),
            ),
            child: Text('.$ext',
                style: TextStyle(
                  fontSize: 11,
                  color: isSelected ? AppColors.accent : AppColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                )),
          ),
        );
      }).toList(),
    );
  }

  Future<void> _pickFiles(BuildContext context, BatchNotifier notifier) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['mp4', 'mkv', 'avi', 'mov', 'webm', 'flv', 'wmv', 'ts', 'mts', 'm2ts', '3gp'],
    );
    if (result != null) {
      final paths = result.files.map((f) => f.path).where((p) => p != null).cast<String>().toList();
      notifier.addFiles(paths);
    }
  }

  Future<void> _runBatch(BuildContext context, BatchNotifier notifier, BatchState state) async {
    if (state.outputDir.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.t('common.specifyOutputFolder')), duration: const Duration(seconds: 2)),
      );
      return;
    }

    final outDir = Directory(state.outputDir);
    if (!await outDir.exists()) {
      await outDir.create(recursive: true);
    }

    notifier.setOverallStatus(BatchStatus.running);

    final opLabels = {
      BatchOp.deleteFirst: 'delete_first',
      BatchOp.deleteLast: 'delete_last',
      BatchOp.trimFirst: 'trim_first',
      BatchOp.trimLast: 'trim_last',
      BatchOp.trimRange: 'trim_range',
      BatchOp.containerSwap: 'container_swap',
      BatchOp.audioExtract: 'audio_extract',
      BatchOp.audioNormalize: 'audio_normalize',
    };

    String extFromInput(String path) {
      final ext = path.split('.').last;
      return state.operation == BatchOp.containerSwap ? state.containerExt : ext;
    }

    for (int i = 0; i < state.files.length; i++) {
      if (state.overallStatus == BatchStatus.cancelled) break;

      final file = state.files[i];
      notifier.updateFile(i, file.copyWith(status: BatchStatus.running));

      final ext = extFromInput(file.inputPath);
      final baseName = file.inputPath.split(Platform.pathSeparator).last;
      final outName = '${baseName.substring(0, baseName.lastIndexOf('.'))}_processed.$ext';
      final outputPath = '${state.outputDir}\\$outName';

      final error = await BatchService.run(
        inputPath: file.inputPath,
        outputPath: outputPath,
        operation: opLabels[state.operation]!,
        trimSeconds: state.trimSeconds,
        trimStart: state.trimStart,
        trimEnd: state.trimEnd,
      );

      if (error != null) {
        notifier.updateFile(i, file.copyWith(status: BatchStatus.error, error: error));
      } else {
        notifier.updateFile(i, file.copyWith(status: BatchStatus.completed, outputPath: outputPath));
      }
    }

    notifier.setOverallStatus(BatchStatus.completed);
  }
}
