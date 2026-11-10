import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snow_speaks/features/lesson/presentation/adult_course_panel.dart';
import 'package:snow_speaks/features/lesson/presentation/lesson_layout.dart';
import 'package:snow_speaks/features/lesson/presentation/ipa_text.dart';
import 'package:snow_speaks/features/lesson/presentation/learning_text.dart';

import 'teaching_trial_test.dart' show TrialFixture;

Future<void> loadTrialFonts() async {
  for (final f in {
    'NotoSansSC': 'assets/fonts/NotoSansSC-ui.ttf',
    'NotoSansIPA': 'assets/fonts/NotoSans-IPA.ttf',
  }.entries) {
    await (FontLoader(f.key)..addFont(rootBundle.load(f.value))).load();
  }
}

Widget trialFrame(
  TrialFixture f,
  Size size, {
  EdgeInsets safe = EdgeInsets.zero,
}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(size: size, padding: safe),
    child: Scaffold(
      backgroundColor: const Color(0xFF55595B),
      body: Stack(
        children: [
          Positioned.fromRect(
            rect: LessonLayout(size, safe: safe).reading,
            child: AnimatedBuilder(
              animation: f.c,
              builder: (context, _) => AdultCoursePanel(controller: f.c),
            ),
          ),
        ],
      ),
    ),
  ),
);
void main() {
  testWidgets(
    'all authored boards and after examples fit real landscape fonts with no reading scrollbar',
    (tester) async {
      await loadTrialFonts();
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final failures = <String>[];
      for (final id in ['N26-U006-L04', 'N26-U084-L01']) {
        final f = TrialFixture(id);
        await f.c.initialize();
        f.c.courseMode = true;
        for (final size in [
          const Size(844, 390),
          const Size(1180, 820),
          const Size(1920, 1080),
        ]) {
          tester.view.physicalSize = size;
          for (var i = 0; i < f.c.steps.length; i++) {
            f.c.coursePosition = i;
            f.c.prepareStage();
            for (final after in [
              false,
              if (f.c.currentCard['afterBoard'] != null) true,
            ]) {
              if (after) f.c.board = List.of(f.c.currentCard['afterBoard']);
              await tester.pumpWidget(
                trialFrame(
                  f,
                  size,
                  safe: size.width == 844
                      ? const EdgeInsets.fromLTRB(47, 0, 47, 21)
                      : EdgeInsets.zero,
                ),
              );
              await tester.pump();
              final error = tester.takeException();
              if (error != null)
                failures.add(
                  '$id ${f.c.currentCard['id']} $size after=$after: $error',
                );
              expect(find.byType(Scrollable), findsNothing);
              expect(find.byType(FittedBox), findsNothing);
              if (f.c.currentCard['summary'] != true) {
                final header = tester.getRect(
                  find.byKey(const ValueKey('trial-course-header')),
                );
                final original = jsonEncode(f.c.teachingCard!['board']);
                f.c.playing = true;
                f.c.activeAudioLanguage = 'en';
                f.c.activeAudioText = 'another clip';
                f.c.notifyListeners();
                await tester.pump();
                expect(
                  tester.getRect(
                    find.byKey(const ValueKey('trial-course-header')),
                  ),
                  header,
                );
                expect(jsonEncode(f.c.teachingCard!['board']), original);
                f.c.playing = false;
              }
            }
          }
        }
        await tester.pumpWidget(const SizedBox());
        f.close();
      }
      expect(failures, isEmpty, reason: failures.join('\n'));
    },
  );
  testWidgets(
    'word and IPA are always vertically separated, including focus and the complete vocabulary',
    (tester) async {
      await loadTrialFonts();
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(844, 390);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final f = TrialFixture('N26-U006-L04');
      await f.c.initialize();
      f.c.courseMode = true;
      for (final id in ['A01', 'A02', 'A03', 'A08']) {
        f.c.coursePosition = f.c.steps.indexWhere((s) => s['id'] == id);
        f.c.prepareStage();
        await tester.pumpWidget(trialFrame(f, const Size(844, 390)));
        await tester.pump();
        for (final element in find.byType(IpaText).evaluate()) {
          final widget = element.widget as IpaText,
              ipaRect = tester.getRect(find.byWidget(widget));
          expect(ipaRect.height, greaterThanOrEqualTo(43.99));
          final word = f.c.courseReviewWords
              .where((w) => f.c.reviewIpa(w) == widget.text)
              .firstOrNull;
          if (word == null) continue;
          final labels = <Rect>[];
          for (final e in find.byType(LearningText).evaluate()) {
            final w = e.widget as LearningText;
            if (w.text == word) labels.add(tester.getRect(find.byWidget(w)));
          }
          for (final e in find.text(word).evaluate()) {
            labels.add(tester.getRect(find.byWidget(e.widget)));
          }
          expect(
            labels.any((r) => r.bottom <= ipaRect.top + .5),
            true,
            reason: '$id $word must be above its pronunciation',
          );
        }
      }
      await tester.pumpWidget(const SizedBox());
      f.close();
    },
  );
  test(
    'trial landscape grid keeps equal outside margins and a readable text lane',
    () {
      for (final size in [const Size(844, 390), const Size(1920, 1080)]) {
        final l = LessonLayout(size);
        expect(l.avatar.left, closeTo(size.width - l.reading.right, .01));
        expect(l.reading.left, greaterThan(l.avatar.right));
        expect(l.reading.width, greaterThan(330));
        expect(
          l.reading.bottom,
          lessThan(size.height - LessonLayout.controlSize(size)),
        );
      }
    },
  );
}
