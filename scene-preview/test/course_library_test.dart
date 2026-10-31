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
                body: TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => CourseLibraryPage(controller: controller),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('01  /  08'), findsOneWidget);
        await tester.tap(find.byTooltip('上一课'));
        await tester.pumpAndSettle();
        expect(find.text('08  /  08'), findsOneWidget);
        await tester.tap(find.byTooltip('下一课'));
        await tester.pumpAndSettle();
        expect(find.text('01  /  08'), findsOneWidget);
        final deck = find.byKey(const ValueKey('course-deck'));
        final bounds = tester.getRect(deck);
        if (size.width < 650) expect(bounds.width, size.width);
        final width = [
          370.0,
          bounds.width * .77,
          bounds.height * .91 * .70,
        ].reduce((a, b) => a < b ? a : b);
        await tester.dragFrom(
          bounds.center,
          Offset(-width * .6, 0),
          kind: size.width >= 650
              ? PointerDeviceKind.mouse
              : PointerDeviceKind.touch,
        );
        await tester.pumpAndSettle();
        expect(find.text('02  /  08'), findsOneWidget);
        expect(controller.courseId, 'adult-fruit-v2');
        expect(controller.playing, false);
        await tester.tap(find.text('开始这一课'));
        await tester.pumpAndSettle();
        expect(controller.courseId, 'adult-drinks-v1');
        expect(controller.playing, false);
        expect(find.text('open'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
      },
    );
  }
}
