# Snow Speaks 应用

这是当前唯一的 Flutter 应用工程。人物使用 Flutter GPU / flutter_scene 渲染，页面与过渡使用 Flutter 原生组件。

构建、测试与部署命令见 [项目说明](../README.md)。

- `lib/features/auth/`：登录与入口。
- `lib/features/lesson/`：课程、教学与学习同步。
- `lib/features/settings/`：我的页面、统计与画面设置。
- `lib/core/avatar/`：人物、动作与语音。
- `assets/`、`hook/`：应用资源、模型与材质构建。
- `test/`：当前应用回归测试。
- `vendor/flutter_scene/LOCAL_PATCHES.md`：渲染引擎补丁说明。

历史验收记录在 `../docs/flutter-scene/`，不代表当前版本已完成真机复测。
