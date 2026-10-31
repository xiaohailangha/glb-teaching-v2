class CourseInfo {
  const CourseInfo(this.id, this.asset, this.title, this.goal);
  final String id, asset, title, goal;
}

const courseCatalog = [
  CourseInfo('adult-fruit-v2', 'adult-fruit', '01 · 苹果和香蕉', '从一个苹果开始'),
  CourseInfo('adult-drinks-v1', 'adult-drinks', '02 · 水和饮料', '说说你想要什么饮品'),
  CourseInfo('adult-polite-v1', 'adult-polite', '03 · 礼貌请求', '让请求多一点礼貌'),
  CourseInfo('adult-shop-v1', 'adult-shop', '04 · 水果饮品店', '用熟悉的短句点东西'),
  CourseInfo('adult-colors-v1', 'adult-colors', '05 · 颜色', '说清你想要哪种颜色'),
  CourseInfo('adult-sizes-v1', 'adult-sizes', '06 · 大小', '说清水果的大小'),
  CourseInfo('adult-numbers-v1', 'adult-numbers', '07 · 数量', '从一个练到多个'),
  CourseInfo(
    'adult-describe-review-v1',
    'adult-describe-review',
    '08 · 按要求拿东西',
    '一起复习颜色、大小和数量',
  ),
];
