import 'dart:convert';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snow_speaks/features/lesson/application/lesson_controller.dart';
import 'package:snow_speaks/features/lesson/domain/course_catalog.dart';
import 'package:snow_speaks/features/lesson/presentation/course_library_page.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
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
        expect(find.byKey(const ValueKey('course-position')), findsNothing);
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
        expect(controller.playing, false);
        await tester.ensureVisible(find.text('描述事物'));
        await tester.tap(find.text('描述事物'));
        await tester.pumpAndSettle();
        expect(activeLabel(), contains('05 · 颜色'));
        await tester.tapAt(
          Offset(bounds.center.dx + card.width * .58, bounds.center.dy),
        );
        await tester.pumpAndSettle();
        expect(activeLabel(), contains('06 · 大小'));
        await tester.tapAt(bounds.center);
        await tester.pumpAndSettle();
        expect(controller.courseId, 'adult-sizes-v1');
        expect(controller.playing, false);
        expect(find.text('open'), findsOneWidget);
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(activeLabel(), contains('06 · 大小'));
        expect(find.byTooltip('全部类型'), findsNothing);
        expect(find.byType(TextField), findsNothing);
        await tester.ensureVisible(find.text('综合复习'));
        await tester.tap(find.text('综合复习'));
        await tester.pumpAndSettle();
        expect(activeLabel(), contains('08 · 按要求拿东西'));
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
              selected: null,
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
