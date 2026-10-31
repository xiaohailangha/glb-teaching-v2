import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:flutter_svg/flutter_svg.dart';

import '../application/lesson_controller.dart';
import '../domain/course_catalog.dart';

const _night = Color(0xFF111D26);
const _mint = Color(0xFFD6F38B);
const _palettes = [
  [Color(0xFFFFC985), Color(0xFFF48168)],
  [Color(0xFFB2EFE0), Color(0xFF56B8B6)],
  [Color(0xFFD6C8FC), Color(0xFFA18DD6)],
  [Color(0xFFFFD69C), Color(0xFFDB927A)],
  [Color(0xFFF2E5A4), Color(0xFF9ECFA6)],
  [Color(0xFFB6DBF4), Color(0xFF7CA3D7)],
  [Color(0xFFFAB9BC), Color(0xFFDC819B)],
  [Color(0xFFD9EAA7), Color(0xFF9FBE86)],
];
const _art = [
  ('apple', 'banana'),
  ('water', 'milk'),
  ('tea', 'coffee'),
  ('banana', 'coffee'),
  ('red_apple', 'green_apple'),
  ('big_apple', 'small_apple'),
  ('two_apples', 'three_apples'),
  ('small_red_apple', 'two_green_apples'),
];
const _titles = [
  'Apple\n& banana.',
  'Take\na sip.',
  'Please\n& thanks.',
  'Your\nlittle shop.',
  'Pick\na color.',
  'Big\nor small?',
  'One, two,\nmore.',
  'Make\nit yours.',
];
const _phrases = [
  'I want an apple.',
  'I want some water.',
  'An apple, please.',
  'I want a banana.',
  'A red apple.',
  'A big apple.',
  'Two apples.',
  'Two green apples.',
];

/// A full-screen, infinitely wrapping poster deck. Course identity is independent
/// of its visual position; swiping never starts or changes a saved lesson.
class CourseLibraryPage extends StatefulWidget {
  const CourseLibraryPage({super.key, required this.controller});
  final LessonController controller;
  @override
  State<CourseLibraryPage> createState() => _CourseLibraryPageState();
}

class _CourseLibraryPageState extends State<CourseLibraryPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _position;
  Map<String, Map<String, dynamic>> _records = {};
  bool _opening = false;
  double _stride = 220;
  int get _index => _position.value.round() % courseCatalog.length;
  @override
  void initState() {
    super.initState();
    final initial = courseCatalog.indexWhere(
      (c) => c.id == widget.controller.courseId,
    );
    _position = AnimationController.unbounded(
      vsync: this,
      value: (8000 + math.max(0, initial)).toDouble(),
    );
    _load();
  }

  Future<void> _load() async {
    try {
      final records = await widget.controller.readCourseCheckpoints();
      if (mounted) setState(() => _records = records);
    } catch (_) {
      /* The deck remains usable if local storage is unavailable. */
    }
  }

  void _settle(double target) {
    if (_opening) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _position.value = target;
    } else {
      _position.animateTo(
        target,
        duration: const Duration(milliseconds: 460),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _next(int delta) =>
      _settle((_position.value.round() + delta).toDouble());
  Future<void> _open() async {
    if (_opening) return;
    _position.stop();
    final course = courseCatalog[_index];
    setState(() => _opening = true);
    try {
      await widget.controller.selectCourse(course.id);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      setState(() => _opening = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('课程暂时未能打开，请再试一次')));
    }
  }

  @override
  void dispose() {
    _position.dispose();
    super.dispose();
  }

  Widget _controls(bool landscape) {
    final course = courseCatalog[_index];
    final started = _records.containsKey(course.id);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        landscape ? 0 : 28,
        8,
        28,
        landscape ? 12 : 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: landscape
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Text(
            course.goal,
            textAlign: landscape ? TextAlign.left : TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: landscape ? 21 : 19,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            started ? '接着上次的地方，继续开口。' : '听一个单词，慢慢说成一句话。',
            textAlign: landscape ? TextAlign.left : TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF91A5AF),
              fontSize: 12,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: landscape ? 280 : 340,
            height: 54,
            child: FilledButton(
              onPressed: _opening ? null : _open,
              style: FilledButton.styleFrom(
                backgroundColor: _mint,
                foregroundColor: _night,
                disabledBackgroundColor: _mint.withValues(alpha: .4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_opening)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _night,
                      ),
                    )
                  else
                    Text(
                      started ? '继续这一课' : '开始这一课',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  const SizedBox(width: 14),
                  const Icon(Icons.arrow_forward_rounded, size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: '上一课',
                onPressed: _opening ? null : () => _next(-1),
                icon: const Icon(
                  Icons.chevron_left_rounded,
                  color: Color(0xFFAEC0C8),
                ),
              ),
              Semantics(
                liveRegion: true,
                child: Text(
                  '${(_index + 1).toString().padLeft(2, '0')}  /  08',
                  key: const ValueKey('course-position'),
                  style: const TextStyle(
                    color: Color(0xFFAEC0C8),
                    fontSize: 12,
                    letterSpacing: 3,
                  ),
                ),
              ),
              IconButton(
                tooltip: '下一课',
                onPressed: _opening ? null : () => _next(1),
                icon: const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFFAEC0C8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _deck() => LayoutBuilder(
    builder: (context, box) {
      final reduced = MediaQuery.disableAnimationsOf(context);
      final height = math.min(540.0, box.maxHeight * .91);
      final width = math.min(math.min(370.0, box.maxWidth * .77), height * .70);
      final cardHeight = width / .70;
      _stride = width * .72;
      final position = _position.value;
      final center = position.round();
      // Draw the nearest poster last: side cards never cover the main card.
      final slots = [for (var i = center - 3; i <= center + 3; i++) i]
        ..sort((a, b) => (b - position).abs().compareTo((a - position).abs()));
      return Semantics(
        label: '课程卡片，左右滑动切换',
        onIncrease: _opening ? null : () => _next(1),
        onDecrease: _opening ? null : () => _next(-1),
        child: GestureDetector(
          key: const ValueKey('course-deck'),
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: _opening ? null : (_) => _position.stop(),
          onHorizontalDragUpdate: _opening
              ? null
              : (event) => _position.value -= event.delta.dx / _stride,
          onHorizontalDragEnd: _opening
              ? null
              : (event) {
                  final velocity = event.primaryVelocity ?? 0;
                  final target = velocity.abs() > 450
                      ? (velocity < 0
                            ? _position.value.floor() + 1
                            : _position.value.ceil() - 1)
                      : _position.value.round();
                  _settle(target.toDouble());
                },
          onHorizontalDragCancel: () =>
              _settle(_position.value.roundToDouble()),
          child: ClipRect(
            child: SizedBox.expand(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  for (final slot in slots)
                    Builder(
                      builder: (context) {
                        final delta = slot - position;
                        final distance = delta.abs();
                        final scale = reduced
                            ? 1.0
                            : math.pow(.78, distance).toDouble();
                        return Transform.translate(
                          offset: Offset(
                            delta * width * .62,
                            reduced ? 0 : distance * 16,
                          ),
                          child: Transform.scale(
                            scale: scale,
                            child: Transform.rotate(
                              angle: reduced
                                  ? 0
                                  : delta.clamp(-2.0, 2.0) * .045,
                              child: Opacity(
                                opacity: math.max(0.0, 1 - distance * .25),
                                child: IgnorePointer(
                                  child: ExcludeSemantics(
                                    excluding: slot != center,
                                    child: SizedBox(
                                      width: width,
                                      height: cardHeight,
                                      child: _Poster(
                                        index: slot % courseCatalog.length,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _night,
    body: AnimatedBuilder(
      animation: _position,
      builder: (context, _) {
        final landscape =
            MediaQuery.sizeOf(context).width >
            MediaQuery.sizeOf(context).height * 1.25;
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -.25),
              radius: 1.0,
              colors: [Color.lerp(_night, _palettes[_index][1], .13)!, _night],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 0),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: '返回课堂',
                        onPressed: _opening
                            ? null
                            : () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const Expanded(
                        child: Text(
                          '挑一课，开口说',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                if (landscape)
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(flex: 6, child: _deck()),
                        Expanded(
                          flex: 4,
                          child: SingleChildScrollView(child: _controls(true)),
                        ),
                      ],
                    ),
                  )
                else ...[
                  Expanded(child: _deck()),
                  _controls(false),
                ],
              ],
            ),
          ),
        );
      },
    ),
  );
}

class _Poster extends StatelessWidget {
  const _Poster({required this.index});
  final int index;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      // A single scalable composition keeps the same poster proportions on small
      // phones, landscape devices and larger text settings without clipping.
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .35),
              blurRadius: 28,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: FittedBox(
            fit: BoxFit.fill,
            child: SizedBox(
              width: 320,
              height: 457,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: _palettes[index],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -90,
                      top: 130,
                      child: Container(
                        width: 350,
                        height: 350,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: .16),
                        ),
                      ),
                    ),
                    Positioned(
                      left: -80,
                      top: 210,
                      child: Container(
                        width: 260,
                        height: 260,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: .22),
                            width: 1,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 24,
                      top: 24,
                      right: 24,
                      child: Row(
                        children: [
                          Text(
                            'LESSON ${(index + 1).toString().padLeft(2, '0')}',
                            style: const TextStyle(
                              color: Color(0xFF34434A),
                              fontSize: 10,
                              letterSpacing: 2,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          const Icon(
                            Icons.auto_awesome,
                            size: 17,
                            color: Color(0xFF34434A),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      left: 23,
                      top: 60,
                      child: Text(
                        _titles[index],
                        textScaler: TextScaler.noScaling,
                        style: const TextStyle(
                          fontFamily: 'Arial',
                          fontSize: 49,
                          height: .98,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -2.5,
                          color: Color(0xFF20343D),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 21,
                      top: 164,
                      child: Transform.rotate(
                        angle: -.15,
                        child: SvgPicture.asset(
                          'assets/avatar/images/${_art[index].$1}.svg',
                          width: 190,
                          height: 190,
                          excludeFromSemantics: true,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 5,
                      top: 217,
                      child: Transform.rotate(
                        angle: .18,
                        child: SvgPicture.asset(
                          'assets/avatar/images/${_art[index].$2}.svg',
                          width: 155,
                          height: 155,
                          excludeFromSemantics: true,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 25,
                      bottom: 27,
                      right: 25,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            courseCatalog[index].title.split(' · ').last,
                            textScaler: TextScaler.noScaling,
                            style: const TextStyle(
                              color: Color(0xFF20343D),
                              fontSize: 23,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _phrases[index],
                            textScaler: TextScaler.noScaling,
                            style: const TextStyle(
                              color: Color(0xFF34434A),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
