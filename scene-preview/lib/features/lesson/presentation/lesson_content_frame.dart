import 'package:flutter/material.dart';

const lessonHeaderHeight = 80.0;
const lessonPhaseHeight = 26.0;

/// Content grows downward from a stable reading position, never recenters.
class LessonContentFrame extends StatelessWidget {
  const LessonContentFrame({super.key, required this.child, this.header});
  final Widget child;
  final Widget? header;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => Padding(
      padding: EdgeInsets.only(top: (box.maxHeight * .12).clamp(16.0, 64.0)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: lessonHeaderHeight + lessonPhaseHeight,
            child: header,
          ),
          Expanded(
            child: Align(
              alignment: Alignment.topLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.topLeft,
                child: SizedBox(width: box.maxWidth, child: child),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget lessonSwitchLayout(Widget? current, List<Widget> previous) => Stack(
  alignment: Alignment.topLeft,
  children: [
    for (final child in previous)
      IgnorePointer(child: ExcludeSemantics(child: child)),
    ?current,
  ],
);
