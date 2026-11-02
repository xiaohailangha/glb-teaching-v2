import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/avatar/scene/course_resources.dart';


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
  late List<int> _indices;
  late String _type;
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
    final type = courseTypes.firstWhere(
      (type) => type.courseIds.contains(widget.controller.courseId),
      orElse: () => courseTypes.first,
    );
    _type = type.id;
    _indices = [
      for (var i = 0; i < courseCatalog.length; i++)
        if (type.courseIds.contains(courseCatalog[i].id)) i,
    ];
    _position = AnimationController.unbounded(
      vsync: this,
      value: (_indices.length * 1000 + math.max(0, _indices.indexOf(initial)))
          .toDouble(),
    );
  }

  void _filter(CourseType type) {
    if (_opening || _type == type.id) return;
    final previous = _index;
    _position.stop();
    setState(() {
      _type = type.id;
      _indices = [
        for (var i = 0; i < courseCatalog.length; i++)
          if (type.courseIds.contains(courseCatalog[i].id)) i,
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

  void _activate(int slot) {
    if (_opening) return;
    if (slot == _position.value.round()) {
      _open();
    } else {
      _settle(slot.toDouble());
    }
  }

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
      return Semantics(
        container: true,
        explicitChildNodes: true,
        child: GestureDetector(
          key: const ValueKey('course-deck'),
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
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
                                child: SizedBox(
                                  width: width,
                                  height: cardHeight,
                                  child: Semantics(
                                    key: slot == center
                                        ? const ValueKey('active-course-target')
                                        : ValueKey('side-course-$slot'),
                                    container: true,
                                    button: true,
                                    enabled: !_opening,
                                    label:
                                        '${slot == center ? '进入课程' : '居中课程'}：${courseCatalog[_indices[slot % _indices.length]].title}',
                                    onTap: _opening
                                        ? null
                                        : () => _activate(slot),
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      excludeFromSemantics: true,
                                      onTap: _opening
                                          ? null
                                          : () => _activate(slot),
                                      child: ExcludeSemantics(
                                        child: _Poster(
                                          index:
                                              _indices[slot % _indices.length],
                                        ),
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
                            child: CourseTypeStrip(
                              selected: _type,
                              enabled: !_opening,
                              onSelected: _filter,
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
                      padding: const EdgeInsets.only(top: 4, bottom: 14),
                      child: Semantics(
                        label: '当前类型第${_page + 1}节，共${_indices.length}节课程',
                        child: ExcludeSemantics(
                          child: Text(
                            '${(_page + 1).toString().padLeft(2, '0')} / ${_indices.length.toString().padLeft(2, '0')}',
                            key: const ValueKey('course-position'),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              letterSpacing: 2,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
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

/// A horizontal type strip only. No search, menu button, or secondary picker.
class CourseTypeStrip extends StatefulWidget {
  const CourseTypeStrip({
    super.key,
    // ignore: prefer_initializing_formals
    List<CourseType>? types,
    required this.selected,
    required this.onSelected,
    this.enabled = true,
  // ignore: prefer_initializing_formals
  }) : _types = types;
  final List<CourseType>? _types;
  List<CourseType> get types => _types ?? courseTypes;
  final String selected;
  final ValueChanged<CourseType> onSelected;
  final bool enabled;
  @override
  State<CourseTypeStrip> createState() => _CourseTypeStripState();
}

class _CourseTypeStripState extends State<CourseTypeStrip> {
  final _keys = <String, GlobalKey>{};
  @override
  void initState() {
    super.initState();
    _reveal();
  }

  void _reveal() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    final target = _keys[widget.selected]?.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(
        target,
        alignment: .5,
        duration: Duration(
          milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 220,
        ),
      );
    }
  });
  @override
  void didUpdateWidget(CourseTypeStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) _reveal();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    key: const ValueKey('course-type-strip'),
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (final type in widget.types)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Semantics(
              selected: widget.selected == type.id,
              child: TextButton(
                key: _keys.putIfAbsent(type.id, () => GlobalKey()),
                onPressed: widget.enabled
                    ? () {
                        widget.onSelected(type);
                        _reveal();
                      }
                    : null,
                style: TextButton.styleFrom(
                  foregroundColor: widget.selected == type.id
                      ? _night
                      : Colors.white70,
                  backgroundColor: widget.selected == type.id
                      ? Colors.white.withValues(alpha: .92)
                      : Colors.white.withValues(alpha: .08),
                  minimumSize: const Size(48, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: const StadiumBorder(),
                ),
                child: Text(
                  type.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: widget.selected == type.id
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
      ],
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
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(28)),
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
                    colors: _palettes[(courseTypes.indexWhere((t) => t.courseIds.contains(courseCatalog[index].id)).clamp(0, _palettes.length - 1))],
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
                            'LESSON ${courseCatalog[index].title.split(' · ').first}',
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
                      right: 23,
                      child: FittedBox(
                        alignment: Alignment.topLeft,
                        fit: BoxFit.scaleDown,
                        child: Text(
                        courseCatalog[index].coverTitle.isEmpty ? 'Learn\n& grow.' : courseCatalog[index].coverTitle,
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
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      top: designHeight * .36,
                      height: designHeight * .42,
                      child: SvgPicture.asset(
                        courseCatalog[index].asset.startsWith('adult-')
                            ? 'assets/avatar/images/apple.svg'
                            : 'assets/avatar/images/cover-${courseCatalog[index].asset}.svg',
                        bundle: CourseResources.instance,
                        semanticsLabel: '${courseCatalog[index].title.split(' · ').last}主题插图',
                        fit: BoxFit.contain,
                        placeholderBuilder: (_) => const SizedBox.shrink(),
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
                            courseCatalog[index].example.isEmpty ? courseCatalog[index].goal : courseCatalog[index].example,
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
