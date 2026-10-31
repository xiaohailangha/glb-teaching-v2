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
      'course cards fit $size and unit filter selects a real course',
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
        await tester.runAsync(() async {
          await tester.pump();
          await Future<void>.delayed(const Duration(milliseconds: 200));
        });
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        for (
          var attempt = 0;
          attempt < 12 &&
              find.text('单元二 · 描述事物').hitTestable().evaluate().isEmpty;
          attempt++
        ) {
          await tester.drag(
            find.byType(CustomScrollView),
            const Offset(0, -100),
          );
          await tester.pumpAndSettle();
        }
        await tester.tap(find.text('单元二 · 描述事物'));
        await tester.pumpAndSettle();
        expect(find.text('苹果和香蕉'), findsNothing);
        for (
          var attempt = 0;
          attempt < 12 && find.text('颜色').hitTestable().evaluate().isEmpty;
          attempt++
        ) {
          await tester.drag(
            find.byType(CustomScrollView),
            const Offset(0, -140),
          );
          await tester.pumpAndSettle();
        }
        // Horizontal browsing is independent of entering a lesson.
        await tester.dragFrom(
          tester.getCenter(find.text('颜色')),
          Offset(size.width >= 650 ? -340 : -230, 0),
          kind: size.width >= 650
              ? PointerDeviceKind.mouse
              : PointerDeviceKind.touch,
        );
        await tester.pumpAndSettle();
        expect(find.text('2 / 4'), findsOneWidget);
        expect(controller.courseId, 'adult-fruit-v2');
        expect(controller.playing, false);
        await tester.dragFrom(
          tester.getCenter(find.text('大小')),
          Offset(size.width >= 650 ? 340 : 230, 0),
          kind: size.width >= 650
              ? PointerDeviceKind.mouse
              : PointerDeviceKind.touch,
        );
        await tester.pumpAndSettle();
        expect(find.text('1 / 4'), findsOneWidget);
        await tester.tap(find.text('颜色'));
        await tester.pumpAndSettle();
        expect(controller.courseId, 'adult-colors-v1');
        expect(controller.playing, false);
        expect(find.text('open'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
      },
    );
  }
}
