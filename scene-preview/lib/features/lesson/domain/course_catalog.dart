class CourseInfo {
  const CourseInfo(
    this.id,
    this.asset,
    this.title,
    this.goal, {
    this.category = '',
    this.coverTitle = '',
    this.example = '',
    this.reviewWords = const [],
    this.unit = '',
    this.number = '',
    this.status = 'published',
  });
  final String id, asset, title, goal, category, coverTitle, example;
  final List<String> reviewWords;
  final String unit, number, status;
}

/// Approved planning catalogue; availability is separate from directory data.
class FormalDirectory {
  FormalDirectory(Map<String, dynamic> data)
    : categories = (data['categories'] as List)
          .map((c) => c['name'] as String)
          .toList(),
      units = (data['units'] as List)
          .map((u) => Map<String, dynamic>.from(u as Map))
          .toList(),
      courses = (data['courses'] as List)
          .map(
            (c) => CourseInfo(
              c['id'] as String,
              '',
              c['title'] as String,
              c['goal'] as String,
              category: c['category'] as String,
              unit: c['unit'] as String,
              number: (c['order'] as int).toString().padLeft(3, '0'),
              status: c['status'] as String,
              coverTitle: c['title'] as String,
              example: c['status'] == 'published' ? '开始学习' : '课程制作中',
            ),
          )
          .toList();
  final List<String> categories;
  final List<Map<String, dynamic>> units;
  final List<CourseInfo> courses;
}

final List<CourseInfo> courseCatalog = [];

/// Types group lessons directly; there is no chapter level in the picker.
class CourseType {
  const CourseType(this.id, this.title, this.courseIds);
  final String id, title;
  final List<String> courseIds;
}

final List<CourseType> courseTypes = [];

void installCourseCatalog(Map<String, dynamic> catalog) {
  final rows = (catalog['courses'] as List)
      .where((c) => c['status'] == 'published')
      .toList();
  final next = rows
      .map(
        (c) => CourseInfo(
          c['id'] as String,
          c['asset'] as String,
          c['title'] as String,
          c['goal'] as String,
          reviewWords: (c['stages'] as List? ?? [])
              .expand(
                (s) => RegExp(r"[A-Za-z]+(?:'[A-Za-z]+)?")
                    .allMatches(
                      (s['speechText'] ?? s['display'] ?? '') as String,
                    )
                    .map((m) => m[0]!.toLowerCase()),
              )
              .toSet()
              .toList(),
          category: c['category'] as String? ?? '',
          coverTitle: c['coverTitle'] as String? ?? '',
          example: c['example'] as String? ?? '',
        ),
      )
      .toList();
  if (next.isEmpty || next.map((c) => c.id).toSet().length != next.length) {
    throw const FormatException('课程目录无效');
  }
  final ids = next.map((c) => c.id).toSet();
  final types = (catalog['types'] as List? ?? [])
      .map(
        (t) => CourseType(
          t['id'] as String,
          t['title'] as String,
          (t['courseIds'] as List).cast<String>().where(ids.contains).toList(),
        ),
      )
      .where((t) => t.courseIds.isNotEmpty)
      .toList();
  final grouped = types.expand((t) => t.courseIds).toSet();
  final remaining = ids.difference(grouped).toList();
  if (remaining.isNotEmpty) types.add(CourseType('more', '更多课程', remaining));
  courseCatalog
    ..clear()
    ..addAll(next);
  courseTypes
    ..clear()
    ..addAll(types);
}
