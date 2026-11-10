import 'dart:convert';
import 'dart:io';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snow_speaks/features/lesson/application/lesson_controller.dart';
import 'package:snow_speaks/features/lesson/domain/course_catalog.dart';
import 'package:snow_speaks/features/lesson/presentation/course_library_page.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final size in [const Size(320, 568), const Size(844, 390), const Size(1280, 900)]) {
    testWidgets('555 directory filters category then unit and blocks unfinished lesson at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final plan = jsonDecode(File('../data/curriculum/formal-plan.json').readAsStringSync()) as Map<String, dynamic>;
      final directory = FormalDirectory({
        ...plan,
        'categories': [for (final c in plan['categories'] as List) {'name': c}],
        'courses': [for (final c in plan['courses'] as List) {...c as Map, 'status': 'planned'}],
      });
      final controller = LessonController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(MaterialApp(home: CourseLibraryPage(controller: controller, directory: directory)));
      await tester.pumpAndSettle();
      expect(find.text('新体系 · 555课'), findsOneWidget);
      expect(find.textContaining('B1.01'), findsNothing);
      expect(find.textContaining('体验测试'), findsNothing);
      final food = find.text('食物与饮品');
      await tester.ensureVisible(food);await tester.tap(food);await tester.pumpAndSettle();
      expect(find.text('认识水果并表达想要'), findsOneWidget);
      final active = find.byKey(const ValueKey('active-course-target'));
      expect(tester.widget<Semantics>(active).properties.label, contains('苹果与香蕉'));
      expect(tester.widget<Semantics>(active).properties.label, isNot(contains('第')));
      await tester.tap(active);await tester.pump();
      expect(find.text('这节课正在制作，完成验收后开放学习'), findsOneWidget);
      expect(controller.courseId, courseCatalog.first.id);
      expect(find.byType(CourseLibraryPage), findsOneWidget);
      // Exercise a non-initial unit using the approved title rather than a guessed label.
      final next = directory.units.where((u) => u['category'] == '食物与饮品').skip(1).first;
      final target = find.text(next['title'] as String);
      await tester.ensureVisible(target);await tester.tap(target);await tester.pumpAndSettle();
      expect(tester.widget<Semantics>(active).properties.label, contains(directory.courses.firstWhere((c) => c.unit == next['id']).title));
      await tester.tap(find.text('原正式课'));await tester.pumpAndSettle();
      expect(find.textContaining('B1.01'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('pilot courses extend the existing deck without replacing old categories', (tester) async {
    final controller = LessonController();
    addTearDown(controller.dispose);
    String? selected;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) => Scaffold(body: TextButton(onPressed: () => showCourseLibrary(context, controller,
      additions: const [CourseInfo('B1.01-L01', 'b101-1', '01 · 见面与告别', '打招呼', coverTitle: 'Hello')],
      onAdditionalSelected: (id) async { selected = id; },
    ), child: const Text('open'))))));
    await tester.tap(find.text('open'));await tester.pumpAndSettle();
    expect(find.text(courseTypes.first.title),findsOneWidget);
    final type=find.text('体验测试 · B1.01');
    await tester.ensureVisible(type);await tester.tap(type);await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('course-deck')),findsOneWidget);
    expect(find.byType(BackdropFilter),findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('active-course-target')));await tester.pumpAndSettle();
    expect(selected,'B1.01-L01');expect(controller.courseId,courseCatalog.first.id);
    expect(tester.takeException(),isNull);
  });
  test('course library reads only the current learner and tolerates a corrupt record', () async {
    final id = courseCatalog.first.id;
    SharedPreferences.setMockInitialValues({
      id: jsonEncode({'version': 1, 'courseId': id, 'index': 2}),
      'account:alice:$id': jsonEncode({
        'version': 1,
        'courseId': id,
        'index': 9,
      }),
      'account:alice:${courseCatalog[1].id}': '{broken',
      'account:alice:${courseCatalog[2].id}': jsonEncode({
        'version': 1,
        'courseId': 'wrong',
        'index': 9,
      }),
    });
    final controller = LessonController(accountId: 'alice');
    final records = await controller.readCourseCheckpoints();
    expect(records.length, 1);
    expect(records[id]?['index'], 9);
    controller.dispose();
  });
  test('every lesson belongs to exactly one valid type', () {
    final ids = courseTypes.expand((type) => type.courseIds).toList();
    expect(ids.toSet().length, ids.length);
    expect(ids.toSet(), courseCatalog.map((course) => course.id).toSet());
  });
  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(844, 390),
    const Size(1280, 900),
  ]) {
    testWidgets(
      'immersive deck wraps, swipes and opens the right lesson at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final semantics = tester.ensureSemantics();
        final controller = LessonController();
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(disableAnimations: size.width == 320),
              child: child!,
            ),
            home: Builder(
              builder: (context) => Scaffold(
                key: const ValueKey('teaching-background'),
                backgroundColor: Colors.blue,
                body: TextButton(
                  onPressed: () => showCourseLibrary(context, controller),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(BackdropFilter), findsOneWidget);
        expect(
          find.byKey(const ValueKey('teaching-background')),
          findsOneWidget,
        );
        expect(
          ModalRoute.of(tester.element(find.byType(CourseLibraryPage)))!.opaque,
          false,
        );
        String activeLabel() => tester
            .widget<Semantics>(
              find.byKey(const ValueKey('active-course-target')),
            )
            .properties
            .label!;
        expect(activeLabel(), contains('01 · 苹果和香蕉'));
        expect(find.byTooltip('下一课'), findsNothing);
        expect(find.text('全部'), findsNothing);
        expect(find.text('01 / 03'), findsOneWidget);
        final deck = find.byKey(const ValueKey('course-deck'));
        final bounds = tester.getRect(deck);
        expect(bounds.width, size.width);
        final card = tester.getRect(
          find.byKey(const ValueKey('active-course-target')),
        );
        expect(
          tester
              .getSemantics(find.byKey(const ValueKey('active-course-target')))
              .rect
              .width,
          lessThan(bounds.width),
        );
        // Exposed side cards move to the center without entering a lesson.
        await tester.tapAt(
          Offset(bounds.center.dx + card.width * .58, bounds.center.dy),
        );
        await tester.pumpAndSettle();
        expect(activeLabel(), contains('02 · 水和饮料'));
        expect(find.text('02 / 03'), findsOneWidget);
        expect(controller.courseId, 'adult-fruit-v2');
        await tester.tapAt(
          Offset(bounds.center.dx - card.width * .58, bounds.center.dy),
        );
        await tester.pumpAndSettle();
        expect(activeLabel(), contains('01 · 苹果和香蕉'));
        await tester.dragFrom(
          bounds.center,
          Offset(-card.width * .6, 0),
          kind: size.width >= 650
              ? PointerDeviceKind.mouse
              : PointerDeviceKind.touch,
        );
        await tester.pumpAndSettle();
        expect(activeLabel(), contains('02 · 水和饮料'));
        expect(find.text('02 / 03'), findsOneWidget);
        expect(controller.playing, false);
        await tester.ensureVisible(find.text('描述事物'));
        await tester.tap(find.text('描述事物'));
        await tester.pumpAndSettle();
        expect(activeLabel(), contains('05 · 颜色'));
        expect(find.text('01 / 03'), findsOneWidget);
        await tester.tapAt(
          Offset(bounds.center.dx + card.width * .58, bounds.center.dy),
        );
        await tester.pumpAndSettle();
        expect(activeLabel(), contains('06 · 大小'));
        expect(find.text('02 / 03'), findsOneWidget);
        await tester.tapAt(bounds.center);
        await tester.pumpAndSettle();
        expect(controller.courseId, 'adult-sizes-v1');
        expect(controller.playing, false);
        expect(find.text('open'), findsOneWidget);
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(activeLabel(), contains('06 · 大小'));
        expect(find.text('02 / 03'), findsOneWidget);
        expect(find.byTooltip('全部类型'), findsNothing);
        expect(find.byType(TextField), findsNothing);
        await tester.ensureVisible(find.text('综合复习'));
        await tester.tap(find.text('综合复习'));
        await tester.pumpAndSettle();
        expect(activeLabel(), contains('08 · 按要求拿东西'));
        expect(find.text('01 / 01'), findsOneWidget);
        await tester.tapAt(
          Offset(bounds.center.dx + card.width * .58, bounds.center.dy),
        );
        await tester.pumpAndSettle();
        expect(find.byType(CourseLibraryPage), findsOneWidget);
        await tester.tap(find.byTooltip('关闭课程'));
        await tester.pumpAndSettle();
        expect(controller.courseId, 'adult-sizes-v1');
        expect(find.byType(CourseLibraryPage), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        semantics.dispose();
        controller.dispose();
      },
    );
  }
  testWidgets('dozens of types can be swiped without search or a menu', (
    tester,
  ) async {
    CourseType? chosen;
    final types = List.generate(
      48,
      (i) => CourseType('type${i + 1}', '类型${i + 1}', const []),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: CourseTypeStrip(
              types: types,
              selected: 'type1',
              onSelected: (type) => chosen = type,
            ),
          ),
        ),
      ),
    );
    expect(find.byType(TextField), findsNothing);
    expect(find.byTooltip('全部类型'), findsNothing);
    await tester.drag(
      find.byKey(const ValueKey('course-type-strip')),
      const Offset(-260, 0),
    );
    await tester.pumpAndSettle();
    expect(
      Scrollable.of(tester.element(find.text('类型1'))).position.pixels,
      greaterThan(0),
    );
    await tester.ensureVisible(find.text('类型48'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('类型48'));
    expect(chosen?.id, 'type48');
    expect(tester.takeException(), isNull);
  });
}
