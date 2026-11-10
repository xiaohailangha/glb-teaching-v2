import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snow_speaks/features/lesson/application/lesson_controller.dart';
import 'package:snow_speaks/features/lesson/domain/course_catalog.dart';
import 'package:snow_speaks/features/lesson/presentation/course_library_page.dart';

FormalDirectory directory({bool published = false}) {
  final plan = jsonDecode(
    File('test/fixtures/content/curriculum/formal-plan.json')
        .readAsStringSync(),
  ) as Map<String, dynamic>;
  return FormalDirectory({
    ...plan,
    'categories': [
      for (final name in plan['categories'] as List) {'name': name},
    ],
    'courses': [
      for (final course in plan['courses'] as List)
        {...course as Map, 'status': published ? 'published' : 'planned'},
    ],
  });
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    installCourseCatalog({
      'courses': [
        {
          'id': 'N26-U001-L01',
          'asset': 'N26-U001-L01',
          'title': '见面打招呼',
          'goal': '问候',
          'status': 'published',
          'category': '认识彼此',
        },
      ],
    });
  });
  tearDown(() {
    courseCatalog.clear();
    courseTypes.clear();
  });
  for (final size in [const Size(844, 390), const Size(1280, 900)]) {
    testWidgets(
      '555 course directory filters units and keeps unpublished lessons locked at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final plan = directory();
        expect(plan.courses.length, 555);
        final controller = LessonController();
        addTearDown(controller.dispose);
        final selected = <String>[];
        await tester.pumpWidget(
          MaterialApp(
            home: CourseLibraryPage(
              controller: controller,
              directory: plan,
              onAdditionalSelected: (id) async {
                selected.add(id);
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('正式课程'), findsOneWidget);
        final food = find.text('食物与饮品');
        await tester.ensureVisible(food);
        await tester.tap(food);
        await tester.pumpAndSettle();
        expect(find.text('认识水果并表达想要'), findsOneWidget);
        final active = find.byKey(const ValueKey('active-course-target'));
        expect(
          tester.widget<Semantics>(active).properties.label,
          contains('苹果与香蕉'),
        );
        await tester.tap(active);
        await tester.pump();
        expect(find.text('这节课正在制作，完成验收后开放学习'), findsOneWidget);
        expect(selected, isEmpty);
        expect(find.byType(CourseLibraryPage), findsOneWidget);
        final next = plan.units
            .where((unit) => unit['category'] == '食物与饮品')
            .skip(1)
            .first;
        final target = find.text(next['title'] as String);
        await tester.ensureVisible(target);
        await tester.tap(target);
        await tester.pumpAndSettle();
        expect(
          tester.widget<Semantics>(active).properties.label,
          contains(
            plan.courses
                .firstWhere((course) => course.unit == next['id'])
                .title,
          ),
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets(
    'published lesson uses the formal callback and closes the directory',
    (tester) async {
      final controller = LessonController();
      addTearDown(controller.dispose);
      final plan = directory(published: true);
      String? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showCourseLibrary(
                context,
                controller,
                directory: plan,
                onAdditionalSelected: (id) async {
                  selected = id;
                },
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final target = find.byKey(const ValueKey('active-course-target'));
      final label = tester.widget<Semantics>(target).properties.label!;
      await tester.tap(target);
      await tester.pumpAndSettle();
      expect(selected, isNotNull);
      expect(
        label,
        contains(
          plan.courses.firstWhere((course) => course.id == selected).title,
        ),
      );
      expect(find.byType(CourseLibraryPage), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('both current trial entries dispatch their own course ID', (
    tester,
  ) async {
    final controller = LessonController();
    addTearDown(controller.dispose);
    final selected = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showCourseLibrary(
              context,
              controller,
              directory: directory(),
              onTrialSelected: (id) async {
                selected.add(id);
              },
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    for (final entry in {
      '试教 · and / or': 'N26-U006-L04',
      '试教 · 承认不同，再说想法': 'N26-U084-L01',
    }.entries) {
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(entry.key));
      await tester.pumpAndSettle();
      expect(selected.last, entry.value);
      expect(find.byType(CourseLibraryPage), findsNothing);
    }
    expect(selected.length, 2);
    expect(tester.takeException(), isNull);
  });
}
