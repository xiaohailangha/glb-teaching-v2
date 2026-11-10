import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snow_speaks/features/lesson/domain/course_catalog.dart';
import 'package:snow_speaks/features/lesson/domain/course_lexicon.dart';
import 'package:snow_speaks/features/lesson/presentation/adult_course_panel.dart';
import 'package:snow_speaks/features/lesson/application/lesson_controller.dart';
import 'package:snow_speaks/features/lesson/application/curriculum_lesson_controller.dart';

import 'curriculum_page_test.dart' as fixture;

class ReviewController extends LessonController {
  final previews = <String>[];
  @override
  void previewWord(String word) => previews.add(word);
}

void main() {
  testWidgets(
    'summary includes repeated words; word and whole IPA are playable',
    (tester) async {
      for (final entry in {
        'NotoSansSC': 'assets/fonts/NotoSansSC-ui.ttf',
        'NotoSansIPA': 'assets/fonts/NotoSans-IPA.ttf',
      }.entries) {
        final loader = FontLoader(entry.key)
          ..addFont(rootBundle.load(entry.value));
        await loader.load();
      }
      final data = jsonDecode(
        File('../data/course-catalog.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      installCourseCatalog(data);
      installCourseLexicon(data);
      final c = ReviewController();
      c.courseId = 'food-01-v1';
      c.courseMode = true;
      c.courseStep = 'summary';
      c.courseChapter = '认识水果并表达想要';
      expect(
        c.courseReviewWords,
        containsAll(['apple', 'banana', 'a', 'an', 'this', 'is']),
      );
      expect(c.courseReviewWords, isNot(contains('orange')));
      final capture = GlobalKey();
      tester.view.physicalSize = const Size(960, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'NotoSansSC'),
          home: Scaffold(
            backgroundColor: const Color(0xFF555857),
            body: RepaintBoundary(
              key: capture,
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: AdultCoursePanel(controller: c),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('apple'));
      await tester.tap(find.text(c.reviewIpa('apple')));
      expect(c.previews, ['apple', 'apple']);
      final boundary =
          capture.currentContext!.findRenderObject() as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory('../work/guided-review').create(recursive: true);
        await File('../work/guided-review/summary.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );

  test(
    'B1.01 summary preview stays on summary and never restarts recording',
    () async {
      final api = fixture.CurriculumApi(fixture.fixture()),
          avatar = fixture.Avatar();
      final c = CurriculumLessonController(
        api: api,
        avatar: avatar,
        id: 'B1.01-L01',
        onSelect: (_) async {},
        readerFactory: (_) => fixture.Reader(),
        feedbackDelay: Duration.zero,
      );
      await c.initialize();
      c.courseMode = true;
      c.coursePosition = c.beats.length - 2;
      c.navigateCourse(1);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(c.courseStep, 'summary');
      expect(
        c.courseReviewWords,
        containsAll(['hello', 'hi', 'goodbye', 'bye', 'welcome']),
      );
      for (final word in c.courseReviewWords) {
        expect(c.reviewIpa(word), isNotEmpty);
      }
      c.previewWord('hello');
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(c.courseStep, 'summary');
      expect(c.reader.enabled, false);
      expect(api.submissions, isEmpty);
      c.dispose();
      avatar.dispose();
      api.dispose();
    },
  );
}
