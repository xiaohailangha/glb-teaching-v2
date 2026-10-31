import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../application/lesson_controller.dart';
import '../domain/course_catalog.dart';

const _ink = Color(0xFF243E35);
const _muted = Color(0xFF738078);
const _paper = Color(0xFFF7F6F0);
const _covers = [
  Color(0xFFF3D9BD),
  Color(0xFFD8E8E4),
  Color(0xFFE7DFF0),
  Color(0xFFF4DDCD),
  Color(0xFFE9E7BF),
  Color(0xFFDDE8F0),
  Color(0xFFF4DEDC),
  Color(0xFFDDE6C9),
];
const _pictures = [
  ('apple', 'banana'),
  ('water', 'milk'),
  ('tea', 'coffee'),
  ('banana', 'coffee'),
  ('red_apple', 'green_apple'),
  ('big_apple', 'small_apple'),
  ('two_apples', 'three_apples'),
  ('small_red_apple', 'two_green_apples'),
];
const _english = [
  'A LITTLE APPLE',
  'SOMETHING TO DRINK',
  'A LITTLE KINDNESS',
  'AT THE LITTLE SHOP',
  'A WORLD OF COLORS',
  'BIG & SMALL',
  'ONE, TWO, THREE',
  'PUT IT ALL TOGETHER',
];

class CourseLibraryPage extends StatefulWidget {
  const CourseLibraryPage({super.key, required this.controller});
  final LessonController controller;
  @override
  State<CourseLibraryPage> createState() => _CourseLibraryPageState();
}

class _CourseLibraryPageState extends State<CourseLibraryPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _arrival = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  Map<String, Map<String, dynamic>> _records = {};
  final Map<String, int> _lengths = {};
  bool _loading = true;
  String? _error, _opening;
  int _unit = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _arrival.value = 1;
    } else {
      _arrival.forward();
    }
  }

  Future<void> _load() async {
    try {
      final records = await widget.controller.readCourseCheckpoints();
      for (final course in courseCatalog) {
        final data = jsonDecode(
          await rootBundle.loadString(
            'assets/avatar/courses/${course.asset}.json',
          ),
        );
        _lengths[course.id] = (data['stages'] as List).length;
      }
      if (mounted) {
        setState(() {
          _records = records;
          _loading = false;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '学习记录暂时未能读取';
        });
      }
    }
  }

  double _progress(String id) {
    final index = _records[id]?['index'];
    final total = _lengths[id] ?? 0;
    return index is num && total > 1
        ? (index / (total - 1)).clamp(0.0, 1.0)
        : 0;
  }

  Future<void> _open(CourseInfo course) async {
    if (_opening != null) return;
    setState(() => _opening = course.id);
    try {
      await widget.controller.selectCourse(course.id);
      if (!mounted) return;
      Navigator.pop(context);
      // Selecting a card only prepares the lesson; the learner taps the teacher to start.
    } catch (_) {
      if (mounted) {
        setState(() => _opening = null);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('暂时无法打开课程，请重试')));
      }
    }
  }

  @override
  void dispose() {
    _arrival.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.controller.activeCourse;
    final intro = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'YOUR LEARNING JOURNEY',
          style: TextStyle(
            color: _muted,
            fontSize: 11,
            letterSpacing: 2.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          '每一次开口，\n都是新的开始。',
          style: TextStyle(
            color: _ink,
            fontSize: 34,
            fontWeight: FontWeight.w700,
            height: 1.35,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          '从单词到短语，再把它说成一句话。',
          style: TextStyle(color: _muted, fontSize: 14, height: 1.7),
        ),
      ],
    );
    final resume = Material(
      color: _ink,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _opening == null ? () => _open(current) : null,
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Row(
            children: [
              const Icon(
                Icons.bookmark_outline_rounded,
                color: Color(0xFFD7E8BB),
                size: 30,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _records.containsKey(current.id)
                          ? '接着上次的足迹'
                          : '今天，从这一课开始',
                      style: const TextStyle(
                        color: Color(0xFFB8CCBF),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      current.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 7),
                    const Text(
                      '进入课堂后，轻触人物开始',
                      style: TextStyle(color: Color(0xFFB8CCBF), fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _opening == current.id
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.arrow_forward_rounded,
                      color: Color(0xFFD7E8BB),
                    ),
            ],
          ),
        ),
      ),
    );
    return Scaffold(
      backgroundColor: _paper,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: _paper,
        surfaceTintColor: _paper,
        toolbarHeight: 68,
        titleSpacing: 0,
        title: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  const Icon(Icons.spa_outlined, color: _ink, size: 24),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'snow speaks',
                      style: TextStyle(
                        color: _ink,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        letterSpacing: .5,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _opening == null
                        ? () => Navigator.pop(context)
                        : null,
                    icon: const Icon(Icons.close_rounded, size: 20),
                    label: const Text('返回课堂'),
                    style: TextButton.styleFrom(
                      foregroundColor: _ink,
                      minimumSize: const Size(100, 44),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LayoutBuilder(
                          builder: (context, box) => box.maxWidth >= 700
                              ? Row(
                                  children: [
                                    Expanded(child: intro),
                                    const SizedBox(width: 40),
                                    Expanded(child: resume),
                                  ],
                                )
                              : Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    intro,
                                    const SizedBox(height: 22),
                                    resume,
                                  ],
                                ),
                        ),
                        const SizedBox(height: 28),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final (i, title) in [
                              '全部课程',
                              '单元一 · 想要什么',
                              '单元二 · 描述事物',
                            ].indexed)
                              ChoiceChip(
                                label: Text(title),
                                selected: _unit == i,
                                onSelected: (_) => setState(() => _unit = i),
                                showCheckmark: false,
                                selectedColor: const Color(0xFFDDE8DA),
                                backgroundColor: _paper,
                                side: BorderSide(
                                  color: _unit == i
                                      ? const Color(0xFFDDE8DA)
                                      : const Color(0xFFDFE3DA),
                                ),
                                labelStyle: TextStyle(
                                  color: _ink,
                                  fontSize: 12,
                                  fontWeight: _unit == i
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 9,
                                ),
                              ),
                          ],
                        ),
                        if (_loading)
                          const Padding(
                            padding: EdgeInsets.only(top: 12),
                            child: LinearProgressIndicator(minHeight: 2),
                          ),
                        if (_error != null)
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: const TextStyle(color: _muted),
                                ),
                              ),
                              TextButton(
                                onPressed: _load,
                                child: const Text('重试'),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            for (final unit in [1, 2])
              if (_unit == 0 || _unit == unit)
                SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1180),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  '0$unit',
                                  style: const TextStyle(
                                    color: _muted,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    unit == 1 ? '我想要什么' : '说清是哪一个',
                                    style: const TextStyle(
                                      color: _ink,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const Text(
                                  '4 节课',
                                  style: TextStyle(color: _muted, fontSize: 12),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final columns = constraints.maxWidth >= 1000
                                    ? 4
                                    : constraints.maxWidth >= 650
                                    ? 3
                                    : constraints.maxWidth >= 430
                                    ? 2
                                    : 1;
                                return Wrap(
                                  spacing: 16,
                                  runSpacing: 20,
                                  children: [
                                    for (
                                      var i = (unit - 1) * 4;
                                      i < unit * 4;
                                      i++
                                    )
                                      SizedBox(
                                        width:
                                            (constraints.maxWidth -
                                                (columns - 1) * 16) /
                                            columns,
                                        child: FadeTransition(
                                          opacity: CurvedAnimation(
                                            parent: _arrival,
                                            curve: Interval(
                                              (i % 4) * .09,
                                              1,
                                              curve: Curves.easeOut,
                                            ),
                                          ),
                                          child: _CourseCard(
                                            index: i,
                                            current:
                                                courseCatalog[i].id ==
                                                current.id,
                                            progress: _progress(
                                              courseCatalog[i].id,
                                            ),
                                            started: _records.containsKey(
                                              courseCatalog[i].id,
                                            ),
                                            busy:
                                                _opening == courseCatalog[i].id,
                                            onTap: _opening == null
                                                ? () => _open(courseCatalog[i])
                                                : null,
                                          ),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(24, 4, 24, 32),
                child: Text(
                  '慢慢来，熟悉的表达会一点点变多。',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _muted, fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CourseCard extends StatefulWidget {
  const _CourseCard({
    required this.index,
    required this.current,
    required this.progress,
    required this.started,
    required this.busy,
    this.onTap,
  });
  final int index;
  final bool current, started, busy;
  final double progress;
  final VoidCallback? onTap;
  @override
  State<_CourseCard> createState() => _CourseCardState();
}

class _CourseCardState extends State<_CourseCard> {
  bool _hover = false, _pressed = false;
  @override
  Widget build(BuildContext context) {
    final i = widget.index;
    final course = courseCatalog[i];
    final reduced = MediaQuery.disableAnimationsOf(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: Duration(milliseconds: reduced ? 0 : 180),
        transform: Matrix4.translationValues(0, _hover ? -5 : 0, 0)
          ..scaleByDouble(_pressed ? .98 : 1, _pressed ? .98 : 1, 1, 1),
        transformAlignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: _ink.withValues(alpha: _hover ? .12 : .035),
              blurRadius: _hover ? 24 : 12,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: widget.current
                  ? const Color(0xFF6C8C73)
                  : const Color(0xFFE8E9E1),
              width: widget.current ? 1.5 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            onHighlightChanged: (value) => setState(() => _pressed = value),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 176,
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _covers[i],
                    borderRadius: BorderRadius.circular(18),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      Positioned(
                        right: -18,
                        bottom: -48,
                        child: Container(
                          width: 190,
                          height: 190,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: .28),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 16,
                        top: 12,
                        child: Text(
                          '${i + 1}'.padLeft(2, '0'),
                          style: TextStyle(
                            fontSize: 34,
                            height: 1,
                            fontWeight: FontWeight.w300,
                            color: _ink.withValues(alpha: .45),
                          ),
                        ),
                      ),
                      if (widget.current)
                        Positioned(
                          right: 12,
                          top: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: .8),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              '当前课程',
                              style: TextStyle(
                                color: _ink,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      Positioned.fill(
                        top: 25,
                        child: Center(
                          child: SizedBox(
                            width: 230,
                            height: 140,
                            child: Stack(
                              children: [
                                Positioned(
                                  left: 18,
                                  top: 0,
                                  child: Transform.rotate(
                                    angle: -.15,
                                    child: SvgPicture.asset(
                                      'assets/avatar/images/${_pictures[i].$1}.svg',
                                      width: 120,
                                      height: 120,
                                      excludeFromSemantics: true,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: 4,
                                  bottom: 0,
                                  child: Transform.rotate(
                                    angle: .15,
                                    child: SvgPicture.asset(
                                      'assets/avatar/images/${_pictures[i].$2}.svg',
                                      width: 105,
                                      height: 105,
                                      excludeFromSemantics: true,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _english[i],
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 9,
                          letterSpacing: 1.3,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        course.title.split(' · ').last,
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        course.goal,
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 12,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              i == 3 || i == 7 ? '综合复习 · 场景表达' : '单词 → 短语 → 句子',
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.north_east_rounded,
                            color: _ink,
                            size: 19,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: ExcludeSemantics(
                          child: LinearProgressIndicator(
                            value: widget.progress,
                            minHeight: 3,
                            backgroundColor: const Color(0xFFF0F1EB),
                            color: const Color(0xFF6C8C73),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.busy
                            ? '正在准备…'
                            : widget.started
                            ? '已有学习记录 · ${(widget.progress * 100).round()}% 教学进度'
                            : '准备好，就从这里开始',
                        style: const TextStyle(color: _muted, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
