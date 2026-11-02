import 'dart:convert';

import 'package:snow_speaks/features/lesson/application/app_session_clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snow_speaks/features/auth/auth_api.dart';
import 'package:snow_speaks/features/lesson/application/lesson_controller.dart';
import 'package:snow_speaks/features/lesson/application/learning_sync.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('learning upload binds server identity, retains offline queue and removes acknowledged events', () async {
    SharedPreferences.setMockInitialValues({});
    var owner = 'learner-a', offline = true;
    final uploads = <Map>[];
    final api = AuthApi(
      origin: Uri.parse('https://example.test'),
      client: MockClient((request) async {
        if (request.url.path.endsWith('/me')) {
          return http.Response(
            jsonEncode({
              'user': {
                'id': owner,
                'nickname': 'test',
                'phoneMasked': '138****0000',
              },
            }),
            200,
          );
        }
        if (offline) throw Exception('offline');
        uploads.add(jsonDecode(request.body) as Map);
        return http.Response('{"accepted":1}', 200);
      }),
    );
    final controller = LessonController(accountId: 'learner-a');
    final sync = LearningSync(controller, api: api);
    await sync.start();
    while (sync.sending) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    sync.event('start');
    await sync.flush();
    expect(sync.events.length, 1);
    offline = false;
    owner = 'learner-b';
    await sync.flush();
    expect(uploads, isEmpty);
    expect(sync.events.length, 1);
    owner = 'learner-a';
    await sync.flush();
    expect(uploads.length, 1);
    expect((uploads.single['events'] as List).single['type'], 'start');
    expect(sync.events, isEmpty);
    sync.dispose();
    while (sync.sending) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    api.dispose();
    controller.dispose();
  });
  test('guest never uploads an account record', () async {
    SharedPreferences.setMockInitialValues({});
    var requests = 0;
    final api = AuthApi(
      client: MockClient((_) async {
        requests++;
        return http.Response('{}', 200);
      }),
    );
    final controller = LessonController(),
        sync = LearningSync(LessonController(), api: api);
    await sync.start();
    sync.event('start');
    await sync.flush();
    expect(requests, 0);
    sync.dispose();
    api.dispose();
    controller.dispose();
  });
  test(
    'logged-in app usage includes preparation, idle and paused pages',
    () async {
      SharedPreferences.setMockInitialValues({});
      AppSessionClock.end();
      expect(AppSessionClock.elapsed, Duration.zero);
      AppSessionClock.begin('usage-user');
      AppSessionClock.startedAt = DateTime.now().subtract(
        const Duration(seconds: 45),
      );
      final api = AuthApi(
        client: MockClient((_) async => throw Exception('offline')),
      );
      final c = LessonController(accountId: 'usage-user');
      final sync = LearningSync(c, api: api);
      await sync.start();
      while (sync.sending) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
      expect(sync.intervals.length, greaterThanOrEqualTo(3));
      expect(
        sync.intervals.every(
          (r) =>
              r['active'] == true &&
              (r['end'] as int) - (r['start'] as int) <= 20000,
        ),
        true,
      );
      expect(
        sync.intervals.fold<int>(
          0,
          (n, r) => n + (r['end'] as int) - (r['start'] as int),
        ),
        greaterThanOrEqualTo(45000),
      );
      c.coursePaused = true;
      sync.lastWall = DateTime.now().millisecondsSinceEpoch - 5000;
      final count = sync.intervals.length;
      sync.tick();
      expect(sync.intervals.length, greaterThan(count));
      sync.dispose();
      while (sync.sending) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
      api.dispose();
      c.dispose();
      AppSessionClock.end();
      expect(AppSessionClock.elapsed, Duration.zero);
    },
  );
}
