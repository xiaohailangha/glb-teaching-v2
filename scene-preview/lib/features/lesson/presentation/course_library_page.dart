import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'package:flutter_svg/flutter_svg.dart';

import '../application/lesson_controller.dart';
import '../domain/course_catalog.dart';

const _night = Color(0xFF111D26);
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

/// The teaching route stays mounted and visible through the frosted overlay.
Future<void> showCourseLibrary(
  BuildContext context,
  LessonController controller,
) {
  final reduced = MediaQuery.disableAnimationsOf(context);
  return Navigator.of(context).push<void>(
    PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      transitionDuration: Duration(milliseconds: reduced ? 0 : 220),
      reverseTransitionDuration: Duration(milliseconds: reduced ? 0 : 180),
      pageBuilder: (_, _, _) => CourseLibraryPage(controller: controller),
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

class CourseLibraryPage extends StatefulWidget {
  const CourseLibraryPage({super.key, required this.controller});
  final LessonController controller;
  @override
  State<CourseLibraryPage> createState() => _CourseLibraryPageState();
}

class _CourseLibraryPageState extends State<CourseLibraryPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _position;
  List<int> _indices = List.generate(courseCatalog.length, (i) => i);
  String? _type;
  bool _opening = false;
  double _stride = 220;
  int get _page => _position.value.round() % _indices.length;
  int get _index => _indices[_page];
  @override
  void initState() {
    super.initState();
    final initial = courseCatalog.indexWhere(
      (c) => c.id == widget.controller.courseId,
    );
    _position = AnimationController.unbounded(
      vsync: this,
      value: (courseCatalog.length * 1000 + math.max(0, initial)).toDouble(),
    );
  }

  void _filter(CourseType? type) {
    if (_opening || _type == type?.id) return;
    final previous = _index;
    _position.stop();
    setState(() {
      _type = type?.id;
      _indices = [
        for (var i = 0; i < courseCatalog.length; i++)
          if (type == null || type.courseIds.contains(courseCatalog[i].id)) i,
      ];
      _position.value =
          (_indices.length * 1000 + math.max(0, _indices.indexOf(previous)))
              .toDouble();
    });
  }

  void _settle(double target) {
    if (_opening) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _position.value = target;
    } else {
      _position.animateTo(
        target,
        duration: const Duration(milliseconds: 420),
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

  Widget _typeTab(CourseType? type) {
    final selected = _type == type?.id;
    return Semantics(
      selected: selected,
      child: TextButton(
        onPressed: _opening ? null : () => _filter(type),
        style: TextButton.styleFrom(
          foregroundColor: selected ? Colors.white : Colors.white60,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: const RoundedRectangleBorder(),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              type?.title ?? '全部',
              style: TextStyle(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
            const SizedBox(height: 7),
            Container(
              height: 2,
              width: 18,
              decoration: BoxDecoration(
                color: selected ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _deck() => LayoutBuilder(
    builder: (context, box) {
      final reduced = MediaQuery.disableAnimationsOf(context);
      final portrait = box.maxHeight > box.maxWidth;
      final cardHeight = math.min(
        portrait ? 720.0 : 570.0,
        box.maxHeight * .93,
      );
      final width = math.min(
        portrait ? box.maxWidth * .80 : 410.0,
        cardHeight * .70,
      );
      final position = _position.value;
      final center = position.round();
      _stride = width * .72;
      final slots =
          _indices.length == 1
                ? [center]
                : [for (var i = center - 3; i <= center + 3; i++) i]
            ..sort(
              (a, b) => (b - position).abs().compareTo((a - position).abs()),
            );
      final activeRect = Rect.fromCenter(
        center: Offset(box.maxWidth / 2, box.maxHeight / 2),
        width: width,
        height: cardHeight,
      );
      return Semantics(
        container: true,
        explicitChildNodes: true,
        child: GestureDetector(
          key: const ValueKey('course-deck'),
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTapUp: _opening
              ? null
              : (event) {
                  if (activeRect.contains(event.localPosition)) _open();
                },
          onHorizontalDragStart: _opening || _indices.length < 2
              ? null
              : (_) => _position.stop(),
          onHorizontalDragUpdate: _opening || _indices.length < 2
              ? null
              : (event) => _position.value -= event.delta.dx / _stride,
          onHorizontalDragEnd: _opening || _indices.length < 2
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
                        return Transform.translate(
                          offset: Offset(
                            delta * width * .62,
                            reduced ? 0 : distance * 12,
                          ),
                          child: Transform.scale(
                            scale: reduced
                                ? 1
                                : math.pow(.78, distance).toDouble(),
                            child: Transform.rotate(
                              angle: reduced
                                  ? 0
                                  : delta.clamp(-2.0, 2.0) * .035,
                              child: Opacity(
                                opacity: math.max(0.0, 1 - distance * .25),
                                child: IgnorePointer(
                                  child: ExcludeSemantics(
                                    child: SizedBox(
                                      width: width,
                                      height: cardHeight,
                                      child: _Poster(
                                        index: _indices[slot % _indices.length],
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
                  Positioned.fromRect(
                    rect: activeRect,
                    child: Semantics(
                      key: const ValueKey('active-course-target'),
                      container: true,
                      button: true,
                      enabled: !_opening,
                      label: '进入课程：${courseCatalog[_index].title}',
                      hint: '左右滑动切换，点击当前卡片进入',
                      onTap: _opening ? null : _open,
                      child: const IgnorePointer(child: SizedBox.expand()),
                    ),
                  ),
                  if (_opening)
                    const Center(
                      child: CircularProgressIndicator(color: Colors.white),
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
  Widget build(BuildContext context) => PopScope(
    canPop: !_opening,
    child: Scaffold(
      backgroundColor: Colors.transparent,
      body: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  _night.withValues(alpha: .30),
                  _night.withValues(alpha: .20),
                  _night.withValues(alpha: .44),
                ],
              ),
            ),
            child: SafeArea(
              child: AnimatedBuilder(
                animation: _position,
                builder: (context, _) => Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 12,
                        right: 10,
                        top: 3,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _typeTab(null),
                                  for (final type in courseTypes)
                                    _typeTab(type),
                                ],
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: '关闭课程',
                            onPressed: _opening
                                ? null
                                : () => Navigator.pop(context),
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(child: _deck()),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            tooltip: '上一课',
                            onPressed: _opening || _indices.length < 2
                                ? null
                                : () => _next(-1),
                            icon: const Icon(
                              Icons.chevron_left_rounded,
                              color: Colors.white70,
                            ),
                          ),
                          Text(
                            '${(_page + 1).toString().padLeft(2, '0')} / ${_indices.length.toString().padLeft(2, '0')}  ·  点击卡片进入',
                            key: const ValueKey('course-position'),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              letterSpacing: 1,
                            ),
                          ),
                          IconButton(
                            tooltip: '下一课',
                            onPressed: _opening || _indices.length < 2
                                ? null
                                : () => _next(1),
                            icon: const Icon(
                              Icons.chevron_right_rounded,
                              color: Colors.white70,
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
      ),
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
      final designHeight = box.maxHeight / box.maxWidth * 320;
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
              height: designHeight,
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
                      top: designHeight * .36,
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
                      top: designHeight * .48,
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
