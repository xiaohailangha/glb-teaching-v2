import 'package:web/web.dart' as web;

void hideBootSplash() => web.document.getElementById('boot-world')?.remove();
void setLessonMode(bool value) => web.document.documentElement?.setAttribute(
  'data-course',
  value ? 'true' : 'false',
);
