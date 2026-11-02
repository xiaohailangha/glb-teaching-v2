import 'package:flutter/material.dart';
import 'package:snow_speaks/features/auth/auth_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snow_speaks/features/settings/application/app_settings.dart';
import 'package:snow_speaks/features/settings/presentation/settings_panel.dart';
import 'package:snow_speaks/features/lesson/application/lesson_controller.dart';

void main() {
  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(844, 390),
    const Size(1280, 900),
  ]) {
    testWidgets('settings layout and persisted controls at $size', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final settings = AppSettings();
      final lesson = LessonController();
      await tester.pumpWidget(
        MaterialApp(
          home: MyLearningPage(
            settings: settings,
            lesson: lesson,
            account: const LearnerAccount(
              id: 'test',
              nickname: '测试',
              phoneMasked: '199****1000',
            ),
            loadSummary: () async => {
              'chapters': 3,
              'courses': 2,
              'words': 12,
              'averageDailyHours': .25,
              'learningDays': 4,
              'completedCourses': 1,
              'learningMs': 3600000,
              'trend': [
                for (var i = 0; i < 7; i++)
                  {'date': '2026-11-0${i + 1}', 'learningMs': i * 60000},
              ],
            },
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.enterText(find.byType(TextField), '小山');
      await tester.tap(find.byTooltip('保存昵称'));
      await tester.pumpAndSettle();
      expect(lesson.nickname, '小山');
      expect(find.text('探索分类'), findsOneWidget);
      expect(find.text('0.25'), findsOneWidget);
      expect(find.text('均衡'), findsNothing);
      await tester.ensureVisible(find.text('画面设置'));
      await tester.tap(find.text('画面设置'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('均衡'));
      await tester.tap(find.text('均衡'));
      await tester.pumpAndSettle();
      expect(settings.preset, RenderPreset.medium);
      await tester.ensureVisible(find.byType(Switch));
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(settings.adaptive, false);
      final store = await SharedPreferences.getInstance();
      expect(store.getString('render.quality'), 'medium');
      expect(store.getBool('render.adaptive'), false);
      expect(find.textContaining('Flutter Scene'), findsNothing);
      expect(find.text('重新连接麦克风'), findsNothing);
      expect(find.text('学习'), findsNothing);
      expect(find.text('继续学习'), findsNothing);
      expect(find.text('重新开始'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      settings.dispose();
      lesson.dispose();
    });
  }
}
