import 'package:flutter/material.dart';
import 'core/localization/app_localizations.dart';

class TrimTab extends StatefulWidget {
  final bool isEnabled;
  final Function(bool) onEnabledChanged;
  final Function(double seconds, int mode) onTrimChanged;
  final double initialSeconds;
  final int initialMode;
  
  const TrimTab({
    super.key,
    required this.isEnabled,
    required this.onEnabledChanged,
    required this.onTrimChanged,
    this.initialSeconds = 10,
    this.initialMode = 0,
  });

  @override
  State<TrimTab> createState() => _TrimTabState();
}

class _TrimTabState extends State<TrimTab> {
  late final TextEditingController _secondsController;
  late int _trimMode;

  @override
  void initState() {
    super.initState();
    _secondsController = TextEditingController(text: widget.initialSeconds.toString());
    _trimMode = widget.initialMode;
    _secondsController.addListener(_notify);
  }

  @override
  void didUpdateWidget(TrimTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Обновляем значения, если они изменились снаружи
    if (widget.initialSeconds != oldWidget.initialSeconds) {
      _secondsController.text = widget.initialSeconds.toString();
    }
    if (widget.initialMode != oldWidget.initialMode) {
      _trimMode = widget.initialMode;
    }
  }

  @override
  void dispose() {
    _secondsController.removeListener(_notify);
    _secondsController.dispose();
    super.dispose();
  }

  void _notify() {
    final seconds = double.tryParse(_secondsController.text) ?? 10;
    widget.onTrimChanged(seconds, _trimMode);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Checkbox(
                value: widget.isEnabled,
                onChanged: (val) {
                  widget.onEnabledChanged(val ?? false);
                  if (val == true) _notify();
                },
                activeColor: Colors.orange,
              ),
              Text(AppLocalizations.t('trim.enable'), style: const TextStyle(fontSize: 16)),
            ],
          ),
          if (widget.isEnabled) ...[
            const SizedBox(height: 16),
            SegmentedButton<int>(
              segments: [
                ButtonSegment(value: 0, label: Text(AppLocalizations.t('trim.keepFirst'))),
                ButtonSegment(value: 1, label: Text(AppLocalizations.t('trim.removeLast'))),
              ],
              selected: {_trimMode},
              onSelectionChanged: (Set<int> newSelection) {
                setState(() {
                  _trimMode = newSelection.first;
                });
                _notify();
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _secondsController,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: AppLocalizations.t('trim.secondsHint'),
                hintStyle: TextStyle(color: Colors.grey),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}