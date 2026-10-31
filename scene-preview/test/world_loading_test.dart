import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snow_speaks/features/auth/world_loading.dart';
import 'package:snow_speaks/features/lesson/application/lesson_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('download completion is not a rendered classroom and profile binding keeps the warmed scene', () async {
    SharedPreferences.setMockInitialValues({});
    final c = LessonController();
    c.handle({'event': 'resource-progress', 'value': .98, 'label': '点亮学习世界'});
    c.handle({'event': 'ready'});
    expect(c.ready, isTrue);
    expect(c.scenePresented, isFalse);
    expect(c.vocabulary.seen, isEmpty);
    c.handle({'event': 'scene-presented'});
    await c.bindAccount(id: 'learner-one', name: '莉莉');
    expect(c.scenePresented, isTrue);
    expect(c.ready, isTrue);
    expect(c.resourceProgress, 1);
    expect(c.nickname, '莉莉');
    c.resetResources();
    expect(c.scenePresented, isFalse);
    expect(c.ready, isFalse);
    c.dispose();
  });
  testWidgets('loading shows real progress and offers retry instead of entering on failure', (tester) async {
    final c = LessonController(); var retries = 0;
    await tester.pumpWidget(MaterialApp(home: WorldLoading(controller: c, retry: () => retries++)));
    c.handle({'event': 'resource-progress', 'value': .73, 'label': '布置人物与场景'});
    await tester.pump();
    expect(find.text('73%'), findsOneWidget);
    expect(find.text('布置人物与场景'), findsOneWidget);
    expect(find.text('进入课堂'), findsNothing);
    c.handle({'event': 'error', 'message': 'test failure'});
    await tester.pump();
    await tester.tap(find.text('重新准备'));
    expect(retries, 1);
    expect(find.text('test failure'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
}
