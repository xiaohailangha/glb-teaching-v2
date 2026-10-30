import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snow_speaks/features/lesson/presentation/adult_course_panel.dart';

void main() {
  testWidgets('live text accepts ASR corrections and stops at received text', (
    tester,
  ) async {
    Widget view(String text) =>
        MaterialApp(home: LiveTypingText(text: text, listening: true));
    await tester.pumpWidget(view('I want'));
    await tester.pump(const Duration(milliseconds: 160));
    expect(find.text('I want ▍'), findsOneWidget);
    await tester.pumpWidget(view('I went'));
    await tester.pump(const Duration(milliseconds: 160));
    expect(find.text('I went ▍'), findsOneWidget);
    expect(find.text('I want ▍'), findsNothing);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('I went ▍'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
}
