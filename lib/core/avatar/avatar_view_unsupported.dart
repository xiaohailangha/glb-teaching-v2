import 'package:flutter/material.dart';
import '../../features/lesson/application/lesson_controller.dart';

class AvatarView extends StatelessWidget {
  final LessonController controller;
  const AvatarView({super.key, required this.controller});
  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('请使用 Android、iOS 或 Web 预览'));
}
