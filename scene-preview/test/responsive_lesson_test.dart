import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_scene/src/widgets/scene_tick_clock.dart';
import 'package:snow_speaks/features/lesson/application/lesson_controller.dart';
import 'package:snow_speaks/features/lesson/domain/course_catalog.dart';
import 'package:snow_speaks/features/lesson/presentation/adult_course_panel.dart';
import 'package:snow_speaks/features/lesson/presentation/learning_text.dart';
import 'package:snow_speaks/features/lesson/presentation/ipa_text.dart';
import 'package:snow_speaks/features/lesson/presentation/lesson_layout.dart';
import 'package:snow_speaks/features/lesson/presentation/lesson_navigation.dart';

class LayoutController extends LessonController {
  final sounds = <String>[];
  @override
  void previewIpa(String symbol) => sounds.add(symbol);
  @override
  String reviewIpa(String word) => word == 'apple' ? '/ˈæp.əl/' : '';
}

void main() {
  test('resumed scene renders immediately after several minutes and repeated ticker restarts', () {
    final clock = SceneTickClock();
    var elapsed = clock.normalize(const Duration(minutes: 5));
    expect(clock.isDue(elapsed, 60), true);
    expect(clock.isDue(elapsed, 60), false);
    clock.restart(); // autoTick off on leaving the page.
    clock.restart(); // autoTick on on returning.
    elapsed = clock.normalize(Duration.zero);
    expect(elapsed, const Duration(minutes: 5));
    expect(clock.isDue(elapsed, 60), true);
    elapsed = clock.normalize(const Duration(milliseconds: 17));
    expect(clock.isDue(elapsed, 60), true);
    clock.restart();
    expect(clock.isDue(clock.normalize(Duration.zero), 30), true);
    expect(
      clock.normalize(const Duration(seconds: 1)),
      greaterThan(const Duration(minutes: 5)),
    );
  });
  test(
    'unexpected raw ticker rollback also clears the old pacing deadline',
    () {
      final clock = SceneTickClock();
      clock.isDue(clock.normalize(const Duration(minutes: 2)), 60);
      expect(clock.isDue(clock.normalize(Duration.zero), 60), true);
    },
  );
  testWidgets(
    'desktop, portrait and landscape layouts keep readable type and equal outside margins',
    (tester) async {
      for (final font in {
        'NotoSansSC': 'assets/fonts/NotoSansSC-ui.ttf',
        'NotoSansIPA': 'assets/fonts/NotoSans-IPA.ttf',
      }.entries) {
        await (FontLoader(
          font.key,
        )..addFont(rootBundle.load(font.value))).load();
      }
      final c = LayoutController()
        ..ready = true
        ..courseMode = true
        ..courseStep = 'word'
        ..lessonPhase = 'listen'
        ..courseChapter = '认识水果并表达想要'
        ..courseTotal = 29
        ..coursePosition = 4;
      addTearDown(c.dispose);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1;
      courseCatalog.clear();
      final sizes = [
        const Size(320, 568),
        const Size(390, 844),
        const Size(430, 932),
        const Size(844, 390),
        const Size(1280, 720),
        const Size(1366, 768),
        const Size(1920, 1080),
        const Size(2560, 1440),
        const Size(3840, 2160),
      ];
      final fontSizes = <double>[];
      for (final scale in [1.0, 1.6]) {
        for (final size in sizes) {
          tester.view.physicalSize = size;
          final layout = LessonLayout(size);
          expect(
            layout.avatar.left,
            closeTo(size.width - layout.reading.right, .001),
          );
          if (layout.stacked)
            expect(layout.avatar.bottom, lessThan(layout.reading.top));
          else
            expect(layout.avatar.right, lessThan(layout.reading.left));
          for (final text in [
            'apple',
            'Could you tell me where the nearest railway station is?',
            'pneumonoultramicroscopicsilicovolcanoconiosis',
          ]) {
            c.courseDisplay = text;
            c.courseText = '苹果。先听清楚，再跟着说。';
            await tester.pumpWidget(
              MaterialApp(
                theme: ThemeData(fontFamily: 'NotoSansSC'),
                home: MediaQuery(
                  data: MediaQueryData(
                    size: size,
                    textScaler: TextScaler.linear(scale),
                  ),
                  child: Scaffold(
                    body: Stack(
                      children: [
                        Positioned.fromRect(
                          rect: layout.reading,
                          child: AdultCoursePanel(controller: c),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: '$size, scale=$scale, $text',
            );
            final word = find
                .descendant(
                  of: find.byType(LearningText),
                  matching: find.byType(Text),
                )
                .first;
            final rect = tester.getRect(word);
            expect(rect.left, greaterThanOrEqualTo(layout.reading.left - .1));
            expect(rect.right, lessThanOrEqualTo(layout.reading.right + .1));
            expect(find.byType(Scrollable), findsNothing);
            expect(find.byType(Scrollbar), findsNothing);
            if (scale == 1 && text == 'apple')
              fontSizes.add(tester.widget<Text>(word).style!.fontSize!);
          }
        }
      }
      expect(fontSizes[6], greaterThan(fontSizes[1] * 2));
    },
  );
  testWidgets(
    'IPA colors separate whole diphthongs and each playable target is at least 44 pixels',
    (tester) async {
      final c = LayoutController();
      addTearDown(c.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IpaText(
              '/aɪ/ /eɪ/ /oʊ/ /tʃ/',
              controller: c,
              style: const TextStyle(fontSize: 24),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final symbol in ['aɪ', 'eɪ', 'oʊ']) {
        await tester.tap(find.text(symbol));
        expect(c.sounds.last, symbol);
        expect(
          tester
              .getSize(
                find
                    .ancestor(
                      of: find.text(symbol),
                      matching: find.byType(InkWell),
                    )
                    .first,
              )
              .height,
          greaterThanOrEqualTo(44),
        );
      }
      expect(find.text('a'), findsNothing);
      expect(find.text('ɪ'), findsNothing);
      expect(find.text('tʃ'), findsOneWidget);
      expect(find.text('ʃ'), findsNothing);
    },
  );
  testWidgets(
    'navigation targets grow with the viewport and stay clear of the text',
    (tester) async {
      final c = LayoutController()..coursePosition = 4;
      addTearDown(c.dispose);
      for (final size in [const Size(390, 844), const Size(1920, 1080)]) {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(size: size),
              child: Scaffold(
                body: Align(
                  alignment: Alignment.bottomRight,
                  child: LessonNavigation(controller: c),
                ),
              ),
            ),
          ),
        );
        final control = find.byTooltip('跳过当前小段');
        final actual = tester.getSize(control);
        expect(actual.width, greaterThanOrEqualTo(56));
        expect(actual.height, greaterThanOrEqualTo(56));
        expect(actual.width, LessonLayout.controlSize(size));
        final layout = LessonLayout(size);
        expect(
          size.height - layout.reading.bottom,
          greaterThanOrEqualTo(actual.height + 16),
        );
      }
    },
  );
}
