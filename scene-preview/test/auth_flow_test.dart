import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snow_speaks/features/auth/auth_api.dart';
import 'package:snow_speaks/features/auth/auth_gate.dart';
import 'package:snow_speaks/features/auth/entry_design.dart';
import 'package:snow_speaks/features/auth/world_loading.dart';
import 'package:snow_speaks/features/lesson/presentation/lesson_page.dart';
import 'package:snow_speaks/features/lesson/application/lesson_controller.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null),
  );
  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(844, 390),
    const Size(1280, 900),
  ]) {
    testWidgets(
      'preview registration, incorrect code and returning login at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        Map<String, dynamic>? account;
        var sends = 0, registrations = 0;
        final api = AuthApi(
          origin: Uri.parse('https://example.test'),
          client: MockClient((req) async {
            final route = req.url.path.split('/').last;
            final input = req.body.isEmpty
                ? <String, dynamic>{}
                : jsonDecode(req.body) as Map;
            var status = 200;
            Map<String, dynamic> result = {};
            switch (route) {
              case 'status':
                result = {'smsReady': false, 'testMode': true};
              case 'me':
                result = {'user': null};
              case 'code':
                sends++;
                result = {
                  'challengeId': 'c$sends',
                  'retryAfter': 60,
                  'testMode': true,
                };
              case 'verify':
                if (input['code'] != '8888') {
                  status = 400;
                  result = {'error': '验证码不正确，请再试一次'};
                } else {
                  result = account == null
                      ? {'registrationToken': 'proof'}
                      : {'user': account};
                }
              case 'register':
                expect(input['registrationToken'], 'proof');
                registrations++;
                account = {
                  'id': 'preview-one',
                  'nickname': input['nickname'],
                  'phoneMasked': '138****8000',
                };
                result = {'user': account};
            }
            return http.Response(
              jsonEncode(result),
              status,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }),
        );
        Future<void> tap(String label) async {
          await tester.ensureVisible(find.text(label));
          await tester.tap(find.text(label));
          await tester.pumpAndSettle();
        }

        await tester.pumpWidget(
          MaterialApp(home: AuthGate(api: api, prepareScene: false)),
        );
        await tester.pumpAndSettle();
        expect(find.text('为每一次开口'), findsOneWidget);
        await tap('开始学习');
        expect(find.text('手机号'), findsOneWidget);
        await tester.enterText(find.byType(TextField), '123');
        await tap('获取验证码');
        expect(find.text('请输入正确的手机号'), findsOneWidget);
        expect(sends, 0);
        await tester.enterText(find.byType(TextField), '13800138000');
        await tap('获取验证码');
        expect(find.text('测试体验 · 验证码 8888'), findsOneWidget);
        await tester.enterText(find.byType(TextField), '0000');
        await tap('验证并继续');
        expect(find.text('验证码不正确，请再试一次'), findsOneWidget);
        await tester.enterText(find.byType(TextField), '8888');
        await tap('验证并继续');
        expect(find.text('怎么称呼你？'), findsOneWidget);
        await tap('完成注册');
        expect(find.text('告诉我怎么称呼你吧'), findsOneWidget);
        await tester.enterText(find.byType(TextField), '莉莉');
        await tap('完成注册');
        expect(find.byType(LessonPage), findsOneWidget);
        expect(
          tester.widget<LessonPage>(find.byType(LessonPage)).account?.nickname,
          '莉莉',
        );
        expect(registrations, 1);
        await tester.widget<LessonPage>(find.byType(LessonPage)).onLeave!();
        await tester.pumpAndSettle();
        await tap('开始学习');
        await tester.enterText(find.byType(TextField), '13800138000');
        await tap('获取验证码');
        await tester.enterText(find.byType(TextField), '8888');
        await tap('验证并继续');
        expect(find.byType(LessonPage), findsOneWidget);
        expect(
          tester.widget<LessonPage>(find.byType(LessonPage)).account?.nickname,
          '莉莉',
        );
        expect(registrations, 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        api.dispose();
      },
    );
  }
  testWidgets('SMS unavailable without preview mode stays truthful', (
    tester,
  ) async {
    final api = AuthApi(
      origin: Uri.parse('https://example.test'),
      client: MockClient(
        (req) async => http.Response(
          jsonEncode(
            req.url.path.endsWith('status')
                ? {'smsReady': false}
                : {'user': null},
          ),
          200,
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(home: AuthGate(api: api, prepareScene: false)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('开始学习'));
    await tester.pumpAndSettle();
    expect(find.text('短信登录暂未开放，可以先体验课程。'), findsOneWidget);
    expect(
      tester.widget<EntryButton>(find.byType(EntryButton)).onPressed,
      isNull,
    );
    expect(find.textContaining('8888'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    api.dispose();
  });
  testWidgets(
    'welcome is usable before resources and waiting transitions only after scene presentation',
    (tester) async {
      final api = AuthApi(
        origin: Uri.parse('https://example.test'),
        client: MockClient(
          (req) async => http.Response(
            jsonEncode(
              req.url.path.endsWith('status')
                  ? {'smsReady': false, 'testMode': true}
                  : {'user': null},
            ),
            200,
          ),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(home: AuthGate(api: api, prepareScene: false)),
      );
      await tester.pumpAndSettle();
      final dynamic state = tester.state(find.byType(AuthGate));
      final c = state.shared as LessonController;
      c.scenePresented = false;
      expect(find.text('开始学习'), findsOneWidget);
      await tester.ensureVisible(find.text('先体验课程'));
      await tester.tap(find.text('先体验课程'));
      await tester.pumpAndSettle();
      expect(find.byType(WorldLoading), findsOneWidget);
      await tester.tap(find.byTooltip('返回'));
      await tester.pumpAndSettle();
      expect(find.text('开始学习'), findsOneWidget);
      await tester.tap(find.text('先体验课程'));
      await tester.pumpAndSettle();
      c.handle({'event': 'ready'});
      await tester.pump();
      expect(find.byType(WorldLoading), findsOneWidget);
      c.handle({'event': 'scene-presented'});
      await tester.pumpAndSettle();
      expect(find.byType(WorldLoading), findsNothing);
      expect(c.accountId, isEmpty);
      expect(c.playing, false);
      await tester.pumpWidget(const SizedBox());
      api.dispose();
    },
  );
  testWidgets(
    'restored session enters directly without a welcome confirmation',
    (tester) async {
      final api = AuthApi(
        origin: Uri.parse('https://example.test'),
        client: MockClient(
          (req) async => http.Response(
            jsonEncode(
              req.url.path.endsWith('status')
                  ? {'smsReady': false, 'testMode': true}
                  : {
                      'user': {
                        'id': 'restored',
                        'nickname': '小禾',
                        'phoneMasked': '199****1032',
                      },
                    },
            ),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(home: AuthGate(api: api, prepareScene: false)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(LessonPage), findsOneWidget);
      expect(
        tester.widget<LessonPage>(find.byType(LessonPage)).account?.id,
        'restored',
      );
      expect(find.text('进入课堂'), findsNothing);
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
