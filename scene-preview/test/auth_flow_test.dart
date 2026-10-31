import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snow_speaks/features/auth/auth_api.dart';
import 'package:snow_speaks/features/auth/auth_gate.dart';
import 'package:snow_speaks/features/lesson/application/lesson_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('unconfigured SMS is explicit and never claims a code was sent', (
    tester,
  ) async {
    var sends = 0;
    final api = AuthApi(
      origin: Uri.parse('https://example.test'),
      client: MockClient((req) async {
        if (req.url.path.endsWith('code')) sends++;
        return http.Response(
          jsonEncode(
            req.url.path.endsWith('status')
                ? {'smsReady': false}
                : {'user': null},
          ),
          200,
        );
      }),
    );
    await tester.pumpWidget(
      MaterialApp(home: AuthGate(api: api, prepareScene: false)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('开始我的学习'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '莉莉');
    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();
    expect(find.text('莉莉，你好'), findsOneWidget);
    expect(find.text('短信登录即将开放，你可以先体验课程。'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(sends, 0);
    await tester.pumpWidget(const SizedBox());
    api.dispose();
  });
  testWidgets(
    'verified registration carries nickname and cooldown, returning login retains server profile',
    (tester) async {
      final requests = <String>[];
      final api = AuthApi(
        origin: Uri.parse('https://example.test'),
        client: MockClient((req) async {
          requests.add(req.url.path);
          final route = req.url.path.split('/').last;
          final response = switch (route) {
            'status' => {'smsReady': true},
            'me' => {'user': null},
            'code' => {'challengeId': 'challenge', 'retryAfter': 60},
            'verify' => {'registrationToken': 'proof'},
            'register' => {
              'user': {
                'id': 'one',
                'nickname': '莉莉',
                'phoneMasked': '138****8000',
              },
            },
            _ => <String, dynamic>{},
          };
          if (route == 'register') {
            expect(jsonDecode(req.body)['nickname'], '莉莉');
          }
          return http.Response(
            jsonEncode(response),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      await tester.pumpWidget(
        MaterialApp(home: AuthGate(api: api, prepareScene: false)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('开始我的学习'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '莉莉');
      await tester.tap(find.text('下一步'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '13800138000');
      await tester.tap(find.text('获取验证码'));
      await tester.pumpAndSettle();
      expect(find.text('输入验证码'), findsOneWidget);
      expect(find.textContaining('后重新获取'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '123456');
      await tester.tap(find.text('验证并继续'));
      await tester.pumpAndSettle();
      expect(find.text('进入课堂'), findsOneWidget);
      expect(requests.where((p) => p.endsWith('/code')).length, 1);
      await tester.pumpWidget(const SizedBox());
      api.dispose();
    },
  );
  test('account progress and nicknames do not read another learner or guest storage', () async {
    SharedPreferences.setMockInitialValues({
      'learner-nickname-v1': 'Guest',
      'vocabulary-exposure-v1': jsonEncode({
        'seen': ['apple'],
        'new': [],
        'inCourse': false,
      }),
    });
    final account = LessonController(accountId: 'a', accountNickname: '莉莉');
    await account.loadCourseProgress();
    expect(account.nickname, '莉莉');
    expect(account.vocabulary.seen, isEmpty);
    final guest = LessonController();
    await guest.loadCourseProgress();
    expect(guest.nickname, 'Guest');
    expect(guest.vocabulary.seen, {'apple'});
    account.dispose();
    guest.dispose();
  });
}
