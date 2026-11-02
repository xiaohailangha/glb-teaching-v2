import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snow_speaks/features/lesson/application/lesson_controller.dart';
import 'package:snow_speaks/features/lesson/domain/course_catalog.dart';
import 'package:snow_speaks/features/lesson/presentation/course_library_page.dart';

void main() {
  for (final size in [const Size(390, 844), const Size(844, 390), const Size(1440, 900)]) {
    testWidgets('96-course library reaches every category without legacy art indices at $size', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final oldCourses = [...courseCatalog], oldTypes = [...courseTypes];
      addTearDown(() {courseCatalog..clear()..addAll(oldCourses);courseTypes..clear()..addAll(oldTypes);});
      final plan = jsonDecode(File('../data/curriculum/plan.json').readAsStringSync()) as Map;
      installCourseCatalog({
        'courses': [for(final g in plan['categories']) for(final c in g['lessons']) {...c,'status':'published','goal':'学习目标','category':g['id'],'coverTitle':'Learn\n& grow.','example':'Can you help me, please?'}],
        'types': [for(final g in plan['categories']) {'id':g['id'],'title':g['title'],'courseIds':[for(final c in g['lessons']) c['id']]}],
      });
      expect(courseCatalog.length,96);
      expect(courseTypes.length,8);
      tester.view.physicalSize=size;
      tester.view.devicePixelRatio=1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for(final group in courseTypes){
        final controller=LessonController()..courseId=group.courseIds.last;
        await tester.pumpWidget(MaterialApp(home:CourseLibraryPage(key:ValueKey(group.id),controller:controller)));
        await tester.pumpAndSettle();
        expect(tester.takeException(),isNull,reason:group.id);
        expect(find.byType(Scrollbar),findsNothing);
        expect(find.text(courseCatalog.firstWhere((c)=>c.id==group.courseIds.last).title.split(' · ').last),findsWidgets);
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
      }
    });
  }
}
