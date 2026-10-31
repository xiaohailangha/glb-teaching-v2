import 'package:flutter/material.dart';

import '../application/lesson_controller.dart';

class LessonNavigation extends StatelessWidget {
  const LessonNavigation({super.key, required this.controller});
  final LessonController controller;
  Widget arrow(int direction, String label, bool enabled) => Semantics(
    button: true,
    label: label,
    enabled: enabled,
    child: Tooltip(
      message: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? () => controller.navigateCourse(direction) : null,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            direction < 0 ? Icons.west_rounded : Icons.east_rounded,
            size: 22,
            color: enabled ? Colors.white54 : Colors.white12,
          ),
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      arrow(-1, '返回上一小段', controller.coursePosition > 0),
      const SizedBox(width: 12),
      arrow(1, '跳过本小段（不计通过）', controller.courseStep != 'summary'),
    ],
  );
}
