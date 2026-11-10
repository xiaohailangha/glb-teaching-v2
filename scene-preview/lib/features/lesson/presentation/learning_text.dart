import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../application/lesson_controller.dart';

/// Native shaping owns spaces and wrapping; word hit testing does not create
/// independent layout boxes that waste the available reading width.
class LearningText extends StatefulWidget {
  const LearningText(
    this.text, {
    super.key,
    required this.controller,
    this.size = 30,
    this.animate = true,
  });
  final String text;
  final LessonController controller;
  final double size;
  final bool animate;
  @override
  State<LearningText> createState() => _LearningTextState();
}

class _LearningTextState extends State<LearningText> {
  final _taps = <int, TapGestureRecognizer>{};
  void _clearTaps() {
    for (final tap in _taps.values) {
      tap.dispose();
    }
    _taps.clear();
  }

  @override
  void didUpdateWidget(LearningText old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text || old.controller != widget.controller)
      _clearTaps();
  }

  @override
  void dispose() {
    _clearTaps();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final c = widget.controller,
          focus = c.teachingCard?['focus'] as List? ?? const [];
      var size = widget.size;
      final base = TextStyle(
        fontFamily: 'NotoSansIPA',
        fontSize: size,
        height: 1.22,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      );
      if (RegExp(r"^[A-Za-z]+[.,!?;:]*$").hasMatch(widget.text.trim())) {
        final p = TextPainter(
          text: TextSpan(text: widget.text, style: base),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout();
        if (p.width > box.maxWidth) size *= box.maxWidth / p.width;
        p.dispose();
      }
      final spans = <InlineSpan>[];
      for (final token in RegExp(
        r"[A-Za-z]+(?:'[A-Za-z]+)?|[^A-Za-z]+",
      ).allMatches(widget.text)) {
        final value = token[0]!;
        if (!RegExp(r'^[A-Za-z]').hasMatch(value)) {
          spans.add(TextSpan(text: value));
          continue;
        }
        final key = value.toLowerCase();
        final status = c.wordFeedback
            .where((w) => w['word'] == key)
            .firstOrNull?['status'];
        final speaking = c.playing && c.spokenWord == key,
            emphasized = focus.contains(key);
        final wrong = status != null && status != 'good';
        final color = wrong || emphasized || speaking
            ? const Color(0xFFFFD4A3)
            : status == 'good'
            ? const Color(0xFFBDE5DD)
            : Colors.white;
        final tap = _taps.putIfAbsent(token.start, TapGestureRecognizer.new)
          ..onTap = () => c.previewWord(value);
        spans.add(
          TextSpan(
            text: value,
            recognizer: tap,
            mouseCursor: SystemMouseCursors.click,
            style: TextStyle(
              color: color,
              shadows: emphasized || speaking
                  ? const [Shadow(color: Color(0x38FFCE91), blurRadius: 10)]
                  : null,
              decoration: wrong || emphasized
                  ? TextDecoration.underline
                  : TextDecoration.none,
              decorationStyle: wrong
                  ? TextDecorationStyle.wavy
                  : TextDecorationStyle.solid,
              decorationColor: color.withValues(alpha: .65),
              decorationThickness: 1.3,
            ),
          ),
        );
      }
      final text = SizedBox(
        width: box.maxWidth,
        child: Text.rich(
          TextSpan(children: spans),
          key: const ValueKey('learning-shaped-text'),
          style: base.copyWith(fontSize: size),
        ),
      );
      if (!widget.animate || MediaQuery.disableAnimationsOf(context)) return text;
      return TweenAnimationBuilder<double>(
        key: ValueKey(widget.text),
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOutCubic,
        child: text,
        builder: (context, value, child) => Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 7 * (1 - value)),
            child: child,
          ),
        ),
      );
    },
  );
}
