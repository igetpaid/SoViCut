import 'package:flutter/material.dart';

class TrimWidget extends StatefulWidget {
  final bool isEnabled;
  final Function(bool) onEnabledChanged;
  final Function(double seconds, int mode) onTrimChanged;
  
  const TrimWidget({
    super.key,
    required this.isEnabled,
    required this.onEnabledChanged,
    required this.onTrimChanged,
  });

  @override
  State<TrimWidget> createState() => _TrimWidgetState();
}

class _TrimWidgetState extends State<TrimWidget> {
  final TextEditingController _secondsController = TextEditingController(text: '10');
  int _trimMode = 0;

  void _notify() {
    final seconds = double.tryParse(_secondsController.text) ?? 10;
    print('=== TRIM WIDGET: seconds=$seconds, mode=$_trimMode ===');
    widget.onTrimChanged(seconds, _trimMode);
  }

  @override
  void initState() {
    super.initState();
    _secondsController.addListener(_notify);
  }

  @override
  void dispose() {
    _secondsController.removeListener(_notify);
    _secondsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Checkbox(
                value: widget.isEnabled,
                onChanged: (val) {
                  widget.onEnabledChanged(val ?? false);
                  if (val == true) _notify(); // при включении тоже отправляем
                },
                activeColor: Colors.orange,
              ),
              const Text(
                'Обрезка видео',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          if (widget.isEnabled) ...[
            const SizedBox(height: 12),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Оставить первые N секунд')),
                ButtonSegment(value: 1, label: Text('Вырезать последние N секунд')),
              ],
              selected: {_trimMode},
              onSelectionChanged: (Set<int> newSelection) {
                setState(() {
                  _trimMode = newSelection.first;
                });
                _notify();
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _secondsController,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: 'Секунд',
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