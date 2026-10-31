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
        expect(find.text('01 / 08  ·  点击卡片进入'), findsOneWidget);
        await tester.tap(find.byTooltip('上一课'));
        await tester.pumpAndSettle();
        expect(find.text('08 / 08  ·  点击卡片进入'), findsOneWidget);
        await tester.tap(find.byTooltip('下一课'));
        await tester.pumpAndSettle();
        final deck = find.byKey(const ValueKey('course-deck'));
        final bounds = tester.getRect(deck);
        expect(bounds.width, size.width);
        expect(
          tester
              .getRect(find.byKey(const ValueKey('active-course-target')))
              .width,
          lessThan(bounds.width),
        );
        // Side/background taps must not open the centered lesson.
        await tester.tapAt(Offset(bounds.left + 2, bounds.center.dy));
        await tester.pumpAndSettle();
        expect(find.byType(CourseLibraryPage), findsOneWidget);
        await tester.ensureVisible(find.text('描述事物'));
        await tester.tap(find.text('描述事物'));
        await tester.pumpAndSettle();
        expect(find.text('01 / 03  ·  点击卡片进入'), findsOneWidget);
        final cardHeight = (bounds.height * .93).clamp(
          0,
          bounds.height > bounds.width ? 720 : 570,
        );
        final widthLimit = bounds.height > bounds.width
            ? bounds.width * .80
            : 410.0;
        final width = widthLimit < cardHeight * .70
            ? widthLimit
            : cardHeight * .70;
        await tester.dragFrom(
          bounds.center,
          Offset(-width * .6, 0),
          kind: size.width >= 650
              ? PointerDeviceKind.mouse
              : PointerDeviceKind.touch,
        );
        await tester.pumpAndSettle();
        expect(find.text('02 / 03  ·  点击卡片进入'), findsOneWidget);
        expect(controller.courseId, 'adult-fruit-v2');
        expect(controller.playing, false);
        await tester.tapAt(bounds.center);
        await tester.pumpAndSettle();
        expect(controller.courseId, 'adult-sizes-v1');
        expect(controller.playing, false);
        expect(find.text('open'), findsOneWidget);
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(find.text('06 / 08  ·  点击卡片进入'), findsOneWidget);
        await tester.ensureVisible(find.text('综合复习'));
        await tester.tap(find.text('综合复习'));
        await tester.pumpAndSettle();
        expect(find.text('01 / 01  ·  点击卡片进入'), findsOneWidget);
        expect(
          tester
              .widget<IconButton>(
                find.widgetWithIcon(IconButton, Icons.chevron_right_rounded),
              )
              .onPressed,
          isNull,
        );
        await tester.tap(find.byTooltip('关闭课程'));
        await tester.pumpAndSettle();
        expect(controller.courseId, 'adult-sizes-v1');
        expect(find.byType(CourseLibraryPage), findsNothing);

        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
      },
    );
  }
}
