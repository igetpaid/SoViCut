import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class MainLayout extends StatelessWidget {
  final Widget toolbar;
  final Widget preview;
  final Widget rightPanel;
  final Widget timeline;
  final double rightPanelWidth;
  final ValueChanged<double> onSplitChanged;

  const MainLayout({
    super.key,
    required this.toolbar,
    required this.preview,
    required this.rightPanel,
    required this.timeline,
    required this.rightPanelWidth,
    required this.onSplitChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: AppColors.bgDark,
        child: Column(
          children: [
            toolbar,
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Preview
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(4, 4, 2, 4),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.border, width: 1),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: preview,
                    ),
                  ),
                  // Resizable divider
                  _SplitDivider(
                    rightPanelWidth: rightPanelWidth,
                    onSplitChanged: onSplitChanged,
                  ),
                  // Right panel
                  SizedBox(
                    width: rightPanelWidth,
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(2, 4, 4, 4),
                      decoration: BoxDecoration(
                        color: AppColors.bgSurface,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.border),
                      ),
                      clipBehavior: Clip.hardEdge,
                      child: rightPanel,
                    ),
                  ),
                ],
              ),
            ),
            timeline,
          ],
        ),
      ),
    );
  }
}

class _SplitDivider extends StatefulWidget {
  final double rightPanelWidth;
  final ValueChanged<double> onSplitChanged;

  const _SplitDivider({
    required this.rightPanelWidth,
    required this.onSplitChanged,
  });

  @override
  State<_SplitDivider> createState() => _SplitDividerState();
}

class _SplitDividerState extends State<_SplitDivider> {
  bool _isHovering = false;
  double? _startGlobalX;
  double? _startWidth;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      cursor: SystemMouseCursors.resizeLeftRight,
      child: GestureDetector(
        onHorizontalDragStart: (details) {
          _startGlobalX = details.globalPosition.dx;
          _startWidth = widget.rightPanelWidth;
        },
        onHorizontalDragUpdate: (details) {
          if (_startGlobalX != null && _startWidth != null) {
            final totalDelta = details.globalPosition.dx - _startGlobalX!;
            final newWidth = _startWidth! - totalDelta;
            widget.onSplitChanged(newWidth.clamp(250.0, 500.0));
          }
        },
        onHorizontalDragEnd: (_) {
          _startGlobalX = null;
          _startWidth = null;
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: _isHovering ? 6 : 4,
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: _isHovering
                ? AppColors.accent.withValues(alpha: 0.6)
                : AppColors.border,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}
