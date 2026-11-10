import 'package:flutter/material.dart';

/// Browser orientation locking is not available on every iPhone. Keep the
/// existing lesson mounted, but expose a landscape classroom only.
class LandscapeClassroom extends StatefulWidget {
  const LandscapeClassroom({
    super.key,
    required this.child,
    this.onPortrait,
    this.onLandscape,
  });
  final Widget child;
  final VoidCallback? onPortrait, onLandscape;
  @override
  State<LandscapeClassroom> createState() => _LandscapeClassroomState();
}

class _LandscapeClassroomState extends State<LandscapeClassroom> {
  bool? _portrait;
  int _change = 0;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final portrait = box.maxHeight > box.maxWidth;
      if (_portrait != portrait) {
        _portrait = portrait;
        final change = ++_change;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || change != _change) return;
          (portrait ? widget.onPortrait : widget.onLandscape)?.call();
        });
      }
      final stage = portrait ? Size(box.maxHeight, box.maxWidth) : box.biggest;
      return Stack(
        fit: StackFit.expand,
        children: [
          Offstage(
            offstage: portrait,
            child: TickerMode(
              enabled: !portrait,
              child: OverflowBox(
                minWidth: stage.width,
                maxWidth: stage.width,
                minHeight: stage.height,
                maxHeight: stage.height,
                child: MediaQuery(
                  data: MediaQuery.of(context).copyWith(size: stage),
                  child: widget.child,
                ),
              ),
            ),
          ),
          if (portrait)
            const ColoredBox(
              color: Color(0xFF484A49),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.screen_rotation_rounded,
                      size: 46,
                      color: Color(0xFFBDE5DD),
                    ),
                    SizedBox(height: 20),
                    Text(
                      '请横屏学习',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      '将手机横过来，继续当前课堂',
                      style: TextStyle(fontSize: 16, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );
}
