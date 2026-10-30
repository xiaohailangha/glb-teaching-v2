import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snow_speaks/features/settings/application/app_settings.dart';
import 'package:snow_speaks/features/settings/presentation/settings_panel.dart';
import 'package:snow_speaks/features/lesson/application/lesson_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('render preferences persist and reach a newly ready avatar', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = AppSettings();
    await settings.update(quality: RenderPreset.low, automatic: false);
    final restored = AppSettings();
    await restored.load();
    expect(restored.preset, RenderPreset.low);
    expect(restored.adaptive, false);
    final lesson = LessonController(), commands = <Map<String, Object?>>[];
    lesson.attach(commands.add);
    lesson.setRenderSettings(restored.command);
    lesson.handle({'event': 'ready'});
    expect(commands.last, {
      'type': 'render-settings',
      'quality': 'low',
      'adaptive': false,
    });
    lesson.dispose();
    settings.dispose();
    restored.dispose();
  });
  testWidgets(
    'settings stay scrollable on a small phone and change both preferences',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final settings = AppSettings(), lesson = LessonController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsPanel(settings: settings, lesson: lesson),
          ),
        ),
      );
      await tester.tap(find.text('低'));
      await tester.pumpAndSettle();
      expect(settings.preset, RenderPreset.low);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(settings.adaptive, false);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      settings.dispose();
      lesson.dispose();
    },
  );
}
