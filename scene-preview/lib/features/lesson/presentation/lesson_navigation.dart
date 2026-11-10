import 'package:flutter/material.dart';

import '../application/lesson_controller.dart';
import 'lesson_layout.dart';

class LessonNavigation extends StatelessWidget {
  const LessonNavigation({super.key, required this.controller});
  final LessonController controller;
  Widget arrow(int direction, String label, bool enabled, double size) =>
      Semantics(
        button: true,
        label: label,
        enabled: enabled,
        child: Tooltip(
          message: label,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: enabled ? () => controller.navigateCourse(direction) : null,
            child: SizedBox(
              width: size,
              height: size,
              child: Icon(
                direction < 0 ? Icons.west_rounded : Icons.east_rounded,
                size: size * .5,
                color: enabled ? Colors.white54 : Colors.white12,
              ),
            ),
          ),
        ),
      );
  @override
  Widget build(BuildContext context) {
    final size = LessonLayout.controlSize(MediaQuery.sizeOf(context));
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        arrow(
          -1,
          controller.backwardNavigationLabel,
          controller.canNavigateBackward,
          size,
        ),
        SizedBox(width: size * .2),
        arrow(
          1,
          controller.forwardNavigationLabel,
          controller.canNavigateForward,
          size,
        ),
      ],
    );
  }
}
