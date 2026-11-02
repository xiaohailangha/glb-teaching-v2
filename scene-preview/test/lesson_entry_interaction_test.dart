import 'package:flutter/material.dart';
import 'package:snow_speaks/features/lesson/presentation/learning_text.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snow_speaks/features/lesson/application/lesson_controller.dart';
import 'package:snow_speaks/features/lesson/presentation/lesson_page.dart';
import 'package:snow_speaks/features/lesson/presentation/lesson_content_frame.dart';

void main() {
  testWidgets(
    'welcome and each selected course start from text or empty space',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = LessonController()..ready = true;
      final commands = <Map<String, Object?>>[];
      c.attach(commands.add);
      await tester.pumpWidget(
        MaterialApp(home: LessonPage(sharedController: c)),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(Scrollable), findsNothing);
      final frame = tester.getRect(find.byType(LessonContentFrame));
      final mainTop = tester
          .getTopLeft(find.byKey(const ValueKey('welcome-main-text')))
          .dy;
      final prompt = tester.getRect(find.text('轻触任意位置，开始学习'));
      expect(prompt.left, closeTo(frame.left, 1));
      await tester.tap(find.text('轻触任意位置，开始学习'));
      await tester.pump();
      expect(commands.where((v) => v['type'] == 'course').length, 1);
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.getRect(find.byType(LessonContentFrame)), frame);
      c.courseDisplay = 'apple';
      c.notifyListeners();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        tester.getTopLeft(find.byType(LearningText)).dy,
        closeTo(mainTop, .01),
      );
      c.courseDisplay = 'I would like two green apples please';
      c.coursePicture = 'apple';
      c.courseText = '一段更长的中文说明，用来验证内容变高后主要文字仍然保持原来的位置';
      c.notifyListeners();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 160));
      expect(
        tester.getTopLeft(find.byKey(ValueKey(c.courseDisplay))).dy,
        closeTo(mainTop, .01),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        tester.getTopLeft(find.byType(LearningText)).dy,
        closeTo(mainTop, .01),
      );
      expect(find.byType(Scrollable), findsNothing);
      await c.selectCourse('adult-numbers-v1');
      await tester.pump();
      commands.clear();
      await tester.tapAt(const Offset(800, 350));
      await tester.pump();
      expect(
        commands.where((v) => v['type'] == 'course').single['courseId'],
        'adult-numbers-v1',
      );
      await c.selectCourse('adult-colors-v1');
      await tester.pump();
      commands.clear();
      await tester.tap(find.byTooltip('我的'));
      await tester.pumpAndSettle();
      expect(commands.where((v) => v['type'] == 'course'), isEmpty);
      await tester.tap(find.byTooltip('关闭我的'));
      await tester.pumpAndSettle();
      expect(commands.where((v) => v['type'] == 'course'), isEmpty);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      c.playCourse();
      await tester.pump();
      await tester.tap(find.byTooltip('我的'));
      await tester.pumpAndSettle();
      expect(c.coursePaused, true);
      commands.clear();
      await tester.tap(find.byTooltip('关闭我的'));
      await tester.pumpAndSettle();
      expect(c.coursePaused, false);
      expect(commands.where((v) => v['type'] == 'course').length, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );
}
