import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snow_speaks/app.dart';
import 'package:snow_speaks/features/lesson/presentation/lesson_page.dart';

void main() {
  for (final size in [
    const Size(1678, 856),
    const Size(844, 390),
    const Size(390, 844),
    const Size(320, 568),
  ]) {
    testWidgets('lesson and controls fit ${size.width} x ${size.height}', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const SnowSpeaksApp());
      await tester.pump();
      expect(find.text('APPLE'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(find.text('演示库'), findsOneWidget);
      expect(find.text('情绪演示'), findsNothing);
      await tester.tapAt(const Offset(10, 20));
      await tester.pumpAndSettle();
      expect(find.byTooltip('下一个'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text(size.width > size.height ? '正常' : '1×'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final dynamic page = tester.state(find.byType(LessonPage));
      page.controller.handle({'event': 'ready'});
      page.controller.play();
      page.controller.handle({
        'event': 'lesson-phase',
        'session': page.controller.session,
        'phase': 'listen',
      });
      await tester.pumpAndSettle();
      expect(find.text('我读好了'), findsOneWidget);
      expect(find.text('YOUR TURN'), findsNothing);
      expect(find.text('LISTEN & REPEAT'), findsNothing);
      expect(find.text('苹果'), findsOneWidget);
      await tester.tap(find.text('æ'));
      await tester.pumpAndSettle();
      expect(page.controller.lessonPhase, 'phoneme');
      expect(page.controller.activeSound, 'æ');
      expect(find.text('ə'), findsNothing);
      expect(find.text('l'), findsNothing);
      await tester.tap(find.text('əl'));
      await tester.pumpAndSettle();
      expect(page.controller.activeSound, 'əl');
      await tester.tap(find.text('苹果'));
      await tester.pumpAndSettle();
      expect(page.controller.lessonPhase, 'meaning');
      expect(tester.takeException(), isNull);
      page.controller.playCourse();
      page.controller.handle({
        'event': 'lesson-phase',
        'session': page.controller.session,
        'phase': 'choice',
        'hideAnswer': true,
        'text': '刚才听到的是什么？',
        'options': [
          {'id': 'apple', 'label': '苹果'},
          {'id': 'banana', 'label': '香蕉'},
          {'id': 'help', 'label': '再听一次'},
        ],
      });
      await tester.pumpAndSettle();
      expect(find.text('APPLE'), findsNothing);
      expect(find.text('æ'), findsNothing);
      expect(find.text('苹果'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('苹果'));
      await tester.pumpAndSettle();
      expect(page.controller.courseOptions, isEmpty);
      page.controller.showEmotions();
      await tester.pumpAndSettle();
      expect(find.text('HAPPY'), findsOneWidget);
      expect(find.text('全部连播'), findsOneWidget);
      expect(tester.takeException(), isNull);
      page.controller.playEmotion(2);
      await tester.pumpAndSettle();
      expect(find.text('FRUSTRATED'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
