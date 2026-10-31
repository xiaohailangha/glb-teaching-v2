class CourseInfo {
  const CourseInfo(this.id, this.asset, this.title, this.goal);
  final String id, asset, title, goal;
}

const courseCatalog = [
  CourseInfo('adult-fruit-v2', 'adult-fruit', '01 · 苹果和香蕉', '从一个苹果开始'),
  CourseInfo('adult-drinks-v1', 'adult-drinks', '02 · 水和饮料', '说说你想要什么饮品'),
  CourseInfo('adult-polite-v1', 'adult-polite', '03 · 礼貌请求', '让请求多一点礼貌'),
  CourseInfo('adult-shop-v1', 'adult-shop', '04 · 水果饮品店', '用熟悉的短句点东西'),
];
