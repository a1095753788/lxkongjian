# 本地抖音 (local_douyin)

本地版抖音 - 播放本地视频的抖音风格应用

## 快速开始

### 直接安装 APK

1. 下载 [apk/local_douyin.apk](apk/local_douyin.apk)
2. 在 Android 手机上安装
3. 打开应用，授权存储权限
4. 点击"发现" → 添加文件夹 → 选择视频所在文件夹
5. 回到"首页"开始播放推荐视频

### 从源码构建

```bash
# 环境要求
# Flutter SDK 3.44.2
# Android SDK compileSdk 36
# JDK 17+

cd local_douyin
flutter pub get
flutter build apk --release
# APK 输出: build/app/outputs/flutter-apk/app-release.apk
```

## 功能特性

### 视频播放
- 垂直滑动切换视频（抖音风格）
- 软解码播放（修复硬解码绿屏问题）
- 支持 MP4、AVI、MKV、MOV、WMV、FLV、WEBM 等格式
- 倍速播放（0.5x ~ 2.0x）
- 自动播放/暂停（可见性检测）

### 交互功能
- **点赞**：点赞按钮，记录喜欢
- **收藏**：收藏视频，推荐权重更高
- **删除**：从本地文件系统删除视频
- **不感兴趣**：标记后从推荐流中移除
- **弹幕评论**：评论以弹幕形式飘过视频画面
- **视频转码**：压缩视频体积，支持多种分辨率

### 页面导航
- **首页**：推荐视频流，基于算法推荐
- **收藏**：随机播放收藏的视频
- **发现**：文件夹管理，视频浏览
- **我的**：统计信息、设置、功能管理

## 推荐算法

参考抖音/YouTube推荐系统核心原理设计：

1. **过滤层**：排除"不感兴趣"标记的视频，短期去重
2. **Engagement Score（互动分）**：点赞、收藏、播放次数加权
3. **Dwell Time Score（观看时长分）**：完播率核心指标
4. **Freshness（新鲜度）**：新视频优先推荐
5. **Folder Affinity（文件夹亲和度）**：基于观看习惯的个性化推荐
6. **Explore Bonus（探索奖励）**：ε-greedy 15% 概率探索长尾
7. **Diversity Constraint（多样性约束）**：同文件夹连续不超过 2 条

## 技术栈

- **框架**：Flutter 3.44.2
- **播放器**：media_kit (libmpv/ffmpeg，软解码)
- **状态管理**：Provider
- **数据库**：SQLite (sqflite)
- **视频转码**：video_compress (MediaCodec/AVFoundation)
- **缩略图**：video_thumbnail
- **文件选择**：file_picker

## 目录结构

```
local_douyin/
├── lib/
│   ├── models/          # 数据模型
│   ├── providers/       # 状态管理
│   ├── screens/         # 页面
│   ├── services/        # 业务服务
│   ├── theme/           # 主题
│   ├── utils/           # 工具
│   ├── widgets/         # 组件
│   ├── app.dart         # 应用入口
│   └── main.dart        # main 函数
├── android/             # Android 原生配置
├── apk/                 # 预构建 APK
└── pubspec.yaml         # 依赖配置
```

## 已知限制

- 仅支持 Android（iOS 未配置）
- 需要 Android 13+ 的存储权限（所有文件访问）
- 5000+ 视频量建议分批扫描

## License

MIT
