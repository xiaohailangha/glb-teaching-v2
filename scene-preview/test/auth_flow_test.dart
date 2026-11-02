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
import 'package:snow_speaks/features/lesson/presentation/lesson_page.dart';
import 'package:snow_speaks/features/lesson/application/lesson_controller.dart';

Future<void> advance(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 900));
  await tester.pump(const Duration(milliseconds: 100));
}

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
      'guided native flow, reversible arrows, keyboard and returning login at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        Map<String, dynamic>? account;
        var sends = 0, registrations = 0;
        final api = AuthApi(
          origin: Uri.parse('https://example.test'),
          client: MockClient((req) async {
            final route = req.url.path.split('/').last,
                input = req.body.isEmpty
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
                  'expiresIn': 300,
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
        Future<void> next() async {
          await tester.tap(find.byKey(const ValueKey('guide-next')));
          await advance(tester);
        }

        Future<void> back() async {
          await tester.tap(find.byKey(const ValueKey('guide-back')));
          await advance(tester);
        }

        await tester.pumpWidget(
          MaterialApp(home: AuthGate(api: api, prepareScene: false)),
        );
        await advance(tester);
        expect(find.text('需要一个手机号'), findsOneWidget);
        expect(find.text('snow speaks'), findsNothing);
        expect(find.byType(SingleChildScrollView), findsNothing);
        expect(find.byKey(const ValueKey('guide-next')), findsNothing);
        expect(find.byKey(const ValueKey('idle-input-caret')), findsOneWidget);
        expect(
          tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
          false,
        );
        final identity = tester.state(find.byType(EntryIdentity));
        final before = tester
            .getSize(find.byKey(const ValueKey('voice-bar-0')))
            .height;
        await tester.pump(const Duration(milliseconds: 500));
        expect(
          tester.getSize(find.byKey(const ValueKey('voice-bar-0'))).height,
          isNot(closeTo(before, .01)),
        );
        await tester.enterText(find.byType(TextField), '123');
        await advance(tester);
        expect(find.byKey(const ValueKey('guide-next')), findsNothing);
        await tester.enterText(find.byType(TextField), '13800138000');
        await advance(tester);
        expect(
          tester.getCenter(find.byKey(const ValueKey('guide-next'))).dx,
          closeTo(size.width / 2, .5),
        );
        expect(
          tester
              .widget<TextField>(find.byType(TextField))
              .decoration!
              .enabledBorder,
          InputBorder.none,
        );
        expect(
          tester.getSize(find.byKey(const ValueKey('voice-bar-0'))).height,
          tester.getSize(find.byKey(const ValueKey('voice-bar-4'))).height,
        );
        expect(
          tester.getSize(find.byKey(const ValueKey('voice-bar-1'))).height,
          tester.getSize(find.byKey(const ValueKey('voice-bar-3'))).height,
        );
        final identityRect = tester.getRect(find.byType(EntryIdentity));
        expect(
          identityRect.top,
          closeTo(
            size.height -
                tester.getRect(find.byKey(const ValueKey('guide-next'))).bottom,
            1,
          ),
        );
        expect(tester.widget<Text>(find.text('为每一次开口')).style!.fontSize, 16);

        if (size.width < 500) {
          tester.view.viewInsets = const FakeViewPadding(bottom: 260);
          await advance(tester);
          expect(
            tester.getRect(find.byKey(const ValueKey('guide-next'))).bottom,
            lessThanOrEqualTo(size.height - 260),
          );
          expect(
            tester.getRect(find.byType(TextField)).top,
            greaterThanOrEqualTo(0),
          );
          expect(tester.getRect(find.byType(EntryIdentity)), identityRect);
          expect(tester.takeException(), isNull);
          tester.view.resetViewInsets();
          await advance(tester);
        }
        await next();
        expect(find.text('输入验证码'), findsOneWidget);
        expect(sends, 1);
        expect(tester.state(find.byType(EntryIdentity)), same(identity));
        await back();
        expect(find.text('需要一个手机号'), findsOneWidget);
        await next();
        expect(sends, 1);
        await tester.enterText(find.byType(TextField), '0000');
        await advance(tester);
        await next();
        expect(find.text('验证码不正确，请再试一次'), findsOneWidget);
        await tester.enterText(find.byType(TextField), '8888');
        await advance(tester);
        await next();
        expect(find.text('还需要一个昵称'), findsOneWidget);
        await back();
        await next();
        expect(find.text('还需要一个昵称'), findsOneWidget);
        await tester.enterText(find.byType(TextField), '莉莉');
        await tester.pump(const Duration(milliseconds: 180));
        await tester.enterText(find.byType(TextField), '');
        await advance(tester);
        expect(
          tester.widget<GuidedActions>(find.byType(GuidedActions)).merged,
          false,
        );
        expect(
          tester.getCenter(find.byKey(const ValueKey('guide-back'))).dx,
          lessThan(
            tester.getCenter(find.byKey(const ValueKey('guide-next'))).dx,
          ),
        );
        await tester.enterText(find.byType(TextField), '   ');
        await advance(tester);
        expect(
          tester.widget<GuidedActions>(find.byType(GuidedActions)).merged,
          false,
        );
        await tester.enterText(find.byType(TextField), '莉莉');
        await advance(tester);
        expect(
          tester.widget<GuidedActions>(find.byType(GuidedActions)).merged,
          true,
        );
        await tester.tap(find.byKey(const ValueKey('guide-explore')));
        for (
          var frame = 0;
          frame < 30 && find.byType(LessonPage).evaluate().isEmpty;
          frame++
        ) {
          await tester.pump(const Duration(milliseconds: 10));
        }
        await tester.pump(const Duration(milliseconds: 200));
        final incoming = tester
            .widget<FractionalTranslation>(
              find.byKey(const ValueKey('lesson-page-slide')),
            )
            .translation
            .dy;
        final outgoing = tester
            .widget<FractionalTranslation>(
              find.byKey(const ValueKey('entry-page-slide')),
            )
            .translation
            .dy;
        expect(incoming, greaterThan(0));
        expect(incoming, lessThan(1));
        expect(incoming - outgoing, closeTo(1, .001));
        expect(find.text('还需要一个昵称'), findsOneWidget);
        await advance(tester);
        await advance(tester);
        expect(find.byType(LessonPage), findsOneWidget);
        expect(registrations, 1);
        expect(
          tester.widget<LessonPage>(find.byType(LessonPage)).account?.nickname,
          '莉莉',
        );
        await tester.widget<LessonPage>(find.byType(LessonPage)).onLeave!();
        await advance(tester);
        expect(find.text('需要一个手机号'), findsOneWidget);
        await tester.enterText(find.byType(TextField), '13800138000');
        await advance(tester);
        await next();
        await tester.enterText(find.byType(TextField), '8888');
        await advance(tester);
        await next();
        await advance(tester);
        expect(find.byType(LessonPage), findsOneWidget);
        expect(registrations, 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        api.dispose();
      },
    );
  }
  testWidgets(
    'signed course loading does not block anonymous phone input',
    (tester) async {
      final c = LessonController();
      final api = AuthApi(origin: Uri.parse('https://example.test'), client: MockClient((req) async => http.Response(jsonEncode(req.url.path.endsWith('status') ? {'testMode':true} : {'user':null}),200)));
      await tester.pumpWidget(MaterialApp(home: AuthGate(api:api,prepareScene:false,controller:c)));
      await advance(tester);
      expect(find.text('需要一个手机号'), findsOneWidget);
      expect(find.byType(LessonPage), findsNothing);
      await tester.pumpWidget(const SizedBox());
      c.dispose(); api.dispose();
    },
  );
  testWidgets(
    'existing session skips all input but still waits for resources',
    (tester) async {
      final c = LessonController();
      final api = AuthApi(
        origin: Uri.parse('https://example.test'),
        client: MockClient(
          (req) async => http.Response(
            jsonEncode(
              req.url.path.endsWith('status')
                  ? {'testMode': true}
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
        MaterialApp(
          home: AuthGate(api: api, prepareScene: false, controller: c),
        ),
      );
      await advance(tester);
      expect(find.byType(LessonPage), findsNothing);
      c.handle({'event': 'ready'});
      c.handle({'event': 'scene-presented'});
      await advance(tester);
      await advance(tester);
      expect(find.byType(LessonPage), findsOneWidget);
      expect(
        tester.widget<LessonPage>(find.byType(LessonPage)).account?.id,
        'restored',
      );
      await tester.pumpWidget(const SizedBox());
      c.dispose();
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
