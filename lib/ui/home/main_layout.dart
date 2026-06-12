import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class MainLayout extends StatelessWidget {
  final Widget toolbar;
  final Widget preview;
  final Widget rightPanel;
  final Widget timeline;

  const MainLayout({
    super.key,
    required this.toolbar,
    required this.preview,
    required this.rightPanel,
    required this.timeline,
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
                children: [
                  Expanded(
                    flex: 7,
                    child: Container(
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: preview,
                    ),
                  ),
                  SizedBox(
                    width: 320,
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(0, 4, 4, 4),
                      decoration: BoxDecoration(
                        color: AppColors.bgSurface,
                        borderRadius: BorderRadius.circular(8),
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
