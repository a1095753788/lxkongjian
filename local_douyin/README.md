# 本地抖音 (local_douyin)

把手机里存着的视频，变成一个只属于你自己的抖音。

没有账号，没有网络请求，没有"推荐你关注的博主"。加几个文件夹进去，它就用上下滑的方式一条条放给你看，并根据你怎么刷来调整顺序。

- 纯本地播放，视频不出手机
- 软解码（libmpv），老机器上也不绿屏
- 推荐算法有明确的评分公式，参数全部可改
- 已带预构建 APK，装完就能用

---

## 它解决什么问题

手机里攒了几百个视频，想翻一个出来看，得在相册里一路划。相册是给你"找文件"用的，不是给你"看内容"用的。

这个 App 换了个思路：把选中的文件夹当成内容池，用抖音的交互方式消费它。你不需要记得文件名，滑就完了。

代价是它不做任何联网的事——所以也没有在线内容、没有社交、没有云端同步。它只是一个更好用的本地播放器。

---

## 功能

### 播放

| 能力 | 说明 |
|---|---|
| 竖滑切换 | 一条一屏，上下滑换视频，和抖音一致 |
| 软解码 | `media_kit` + libmpv/FFmpeg，走 CPU 解码。硬解码在某些设备和编码上会绿屏/黑屏，软解慢一点但稳定 |
| 格式支持 | `mp4` `avi` `mkv` `mov` `wmv` `flv` `webm` `3gp` `ts` `m4v` `mpeg` `mpg`（共 12 种，见 `AppConstants.supportedVideoExtensions`） |
| 倍速 | 0.5x ~ 2.0x |
| 自动播放/暂停 | 可见性检测，视频露出超过 50% 才开始播，划走自动暂停 |
| 播完自动切下一条 | 单条播完自动翻到下一个，不会原地循环同一条；接近末尾自动追加，全库放完回到第一条 |
| 断点续播 | 每 5 秒记录一次进度，下次打开从上次位置继续。进度 <2% 或 ≥95% 不恢复 |
| 播放计数 | 看满 3 秒或进度过 10% 才记一次播放。快速划过不计数，避免污染推荐 |
| 防息屏 | 播放期间保持屏幕常亮 |

### 交互

- **点赞** —— 影响推荐权重
- **收藏** —— 收藏的视频会从推荐流里移出，只在"收藏"tab 里出现（这是刻意设计，不是 bug）
- **不感兴趣** —— 标记后从推荐流永久排除，可在"我的"里一键重置
- **弹幕评论** —— 评论以弹幕形式飘过画面，也可以发普通评论
- **删除** —— 可以只移除记录，也可以连本地文件一起删（会二次确认）

### 页面结构

底部有 5 个位置，实际是 4 个页面加一个快捷按钮：

```
[首页]  [文件夹]  [＋]  [发现]  [我的]
```

- **首页** —— 顶部还有两个 tab：`推荐`（算法流）和 `收藏`（收藏视频随机播）
- **文件夹** —— 添加/管理视频文件夹，手动触发扫描
- **＋** —— 快捷跳到文件夹页添加
- **发现** —— 浏览已扫描的视频，按文件夹分组
- **我的** —— 统计（视频数/喜欢/收藏/总播放）、重新扫描、刷新推荐、重置不感兴趣

---

## 快速开始

### 方式一：直接装 APK

1. 下载 [`apk/local_douyin.apk`](apk/local_douyin.apk)（约 92 MB）
2. 传到手机安装。会提示"未知来源"，需要允许安装
3. 首次打开授予"所有文件访问权限"（Android 11+ 需要手动在设置里给）
4. 进入 **文件夹** → **添加文件夹** → 选一个视频目录
5. 回 **首页** 开始刷

> 这个 APK 是 **debug 构建**，体积偏大、启动比 release 慢，功能完全一样。介意的话用方式二自己打 release 包。
>
> 仓库里的 APK 可能落后于源码。想拿最新构建产物，去 [Actions](../../actions/workflows/build-apk.yml) 页面下载 `local_douyin-debug-apk`（每次推送到 `master` 且改动 `lib/`、`android/` 或 `pubspec` 时会自动构建）。

### 方式二：从源码构建

环境要求：

| 项 | 版本 |
|---|---|
| Flutter | 3.38+（`pubspec.yaml` 要求 Dart SDK `>=3.12.0 <4.0.0`） |
| Android SDK | `compileSdk 36` |
| JDK | 17 |
| Gradle | 9.1.0（wrapper 已配置，从腾讯云镜像下载） |

```bash
cd local_douyin
flutter pub get
flutter build apk --release
# 产物：build/app/outputs/flutter-apk/app-release.apk
```

国内网络建议先设镜像，否则 `pub get` 大概率卡住：

```bash
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
```

⚠️ **打 release 包前必须改签名。** `android/app/build.gradle.kts` 里 `release` 用的是 `signingConfigs.getByName("debug")`，也就是拿 debug 密钥签 release 包。能装能用，但不能上架、不能覆盖安装不同签名的版本、部分机型会拦。正式分发请配 `key.properties` + keystore。

⚠️ 仓库里那几个 `build_apk*.ps1` / `build_apk.bat` 是作者本机专用脚本，里面硬编码了本机 Flutter 路径（`C:\Users\ZhuanZ\...`）和本地代理端口（`127.0.0.1:10808`），**换台机器直接跑会失败**。参考思路即可，别照抄。

---

## 推荐算法

不是黑盒。所有分数都是加出来的，公式在 `lib/services/recommendation_service.dart`。

### 第一步：过滤

进入打分前先筛掉四类：

1. 标记了"不感兴趣"的
2. **已收藏的**（收藏视频只在收藏 tab 出现）
3. 调用方显式排除的（翻页时排除已加载的）
4. 本次会话最近出现过的 30 条

### 第二步：打分

每条视频的分数 = 下面各项相加：

| 维度 | 条件 | 分值 |
|---|---|---|
| 点赞数 | `likeCount × 2.0` | 累加 |
| 播放次数 | `playCount × 0.5` | 累加 |
| 观看进度 | `< 20%`（快速划走） | **−10** |
| | `20% ~ 50%` | +2 |
| | `50% ~ 90%` | +5 |
| | `≥ 90%`（基本看完） | **+15** |
| 新鲜度 | 24 小时内加入 | +20 |
| | 7 天内加入 | +10 |
| | 30 天内加入 | +5 |
| | 超过 30 天 | 0（不惩罚老视频） |
| 文件夹亲和度 | 该文件夹的平均观看热度，归一化到 | 0 ~ 10 |
| 探索奖励 | 从没播过的视频 | +10 |
| 随机扰动 | 打散顺序，避免每次一模一样 | 0 ~ 2 |

**观看进度是权重最大的信号**——看完一条（+15）比点赞（+2）重要得多，这也符合真实推荐系统的逻辑：完播率比点赞难刷。

### 第三步：排序 + 打散

1. 按分数降序排
2. 前 70%（至少 5 条）作为 **利用池**，其余作为 **探索池**
3. 逐条挑：85% 概率从利用池拿，**15% 概率从探索池随机拿**（ε-greedy）
4. 同一文件夹不允许连续出现超过 **2 条**（多样性约束）
5. 约束太严找不到就放宽，再找不到就换池

第 3 步是为了防止"你越看某类，它越只给你这类"。15% 的探索概率意味着刷 20 条大概会遇到 3 条"算法没想到你会看"的。

### 想调参数？

**直接改 `lib/services/recommendation_service.dart` 里的 `_computeScore()`。**

⚠️ `lib/utils/constants.dart` 里有一组看起来很专业的参数（`bayesianMinVotes`、`hnGravity`、`likeCountWeight`、`completedPenalty`…），注释写着"综合 Bayesian Average + HN 衰减"。**这些是上一版算法的残留，当前代码一处都没引用**（全库 0 次调用）。改它们不会有任何效果。真正生效的只有 `exploreEpsilon`、`maxConsecutivePerFolder`、`supportedVideoExtensions`、`dbVersion` 这四个。

---

## 数据存在哪

| 内容 | 位置 |
|---|---|
| 数据库 | 应用私有目录 `local_douyin.db`（SQLite，schema 版本 4） |
| 缩略图 | `<应用文档目录>/thumbnails/<视频ID>.jpg`（480px 宽，JPEG 75） |
| 原视频 | **不复制、不移动**，只存路径 |

三张表：`folders`、`videos`、`comments`。

**重要：所有数据都在应用私有目录里，卸载 App 就全没了。** 重装后要重新添加文件夹、重新扫描，点赞/收藏/观看进度全部丢失。原视频文件不受影响（除非你手动用了"删除文件"）。

---

## 项目结构

```
local_douyin/
├── lib/
│   ├── main.dart                    media_kit 初始化
│   ├── app.dart                     底部导航 + Provider 注册
│   ├── models/                      数据模型（VideoItem / FolderItem / CommentItem）
│   ├── providers/                   状态管理，4 个 ChangeNotifier
│   ├── screens/                     5 个页面
│   ├── services/
│   │   ├── database_service.dart    SQLite CRUD
│   │   ├── video_scan_service.dart  递归扫目录、生成缩略图、删文件
│   │   └── recommendation_service.dart  推荐算法（核心）
│   ├── widgets/                     视频流、播放器、弹幕、侧边按钮
│   ├── theme/                       深色主题
│   └── utils/constants.dart         常量（注意上面的死代码提醒）
├── android/                         原生配置
├── apk/local_douyin.apk             预构建 APK
└── pubspec.yaml                     依赖
```

技术栈：Flutter · media_kit（libmpv/FFmpeg）· Provider · sqflite · video_thumbnail · file_picker

---

## 已知限制

### 必须知道的

- **只能安卓。** iOS 目录没配，`AVFoundation` 相关代码虽然写了对 iOS 的注释，但工程跑不起来。
- **不能上 Google Play。** 申请了 `MANAGE_EXTERNAL_STORAGE`（所有文件访问），这个权限 Google 只批给文件管理器和杀毒软件。只能侧载分发。
- **存储权限得手动给。** Android 11+ 上 `MANAGE_EXTERNAL_STORAGE` 不会弹窗，得自己进系统设置开。不给的话扫描会报"无法读取文件夹内容"。
- **`AndroidManifest.xml` 里声明了 `INTERNET` 权限**，但代码没有任何网络请求。这是 `cached_network_image` 等依赖带进来的，删依赖时记得一起清掉，否则"纯本地"这个卖点会被应用商店和用户质疑。

### 数据库的坑（新装用户会遇到）

`database_service.dart` 的 `_onCreate()` 建 `videos` 表时**漏了 `isNotInterested` 列**，而这一列只在 `onUpgrade` 的 `oldVersion < 4` 分支里加。

结果：**全新安装的 App，点"不感兴趣"会抛 `no such column: isNotInterested`。** 从旧版本升级上来的反而没事。

修法：在 `_onCreate` 的 `CREATE TABLE videos` 里补上 `isNotInterested INTEGER DEFAULT 0`。

### 性能

- 扫描是**一次性全量递归**，没有分批、没有进度条细分、没有后台 isolate。5000+ 视频的目录会让界面卡住一段时间（缩略图是逐个生成的，最慢的一环）。
- 想快一点只能自己拆：把大目录拆成几个子目录分别添加。
- 推荐计算每次都 `getAllVideos()` 全表读出，视频量上万后每次刷新会明显变慢。

### 其他

- **`video_thumbnail 0.5.6` 与 Gradle 9 不兼容。** 这个包已停更（pub 上最新版就是 0.5.6，2025-05 之后没再发版），它的 `android/build.gradle` 里还在调用 `jcenter()`，而 jcenter 在 Gradle 8 废弃、Gradle 9 已被移除。构建会报 `Could not find method jcenter()`，并连带出现 `'kotlin-android' plugin requires one of the Android Gradle plugins`。

  修法是把 `jcenter()` **替换成** `mavenCentral()`，**不要直接删**——它的 `buildscript` 只声明了 `google()`，而 asm、protobuf、proguard 这些老依赖不在 Google 仓库，删掉会换成 `Could not resolve all artifacts for configuration 'classpath'`。

  ```bash
  F=$(find ~/.pub-cache -path "*video_thumbnail*/android/build.gradle")
  sed -i 's|jcenter()|mavenCentral()|g' $F
  ```

  CI 里已自动执行（见 `.github/workflows/build-apk.yml`）。
- `video_player` / `chewie` 还在 `pubspec.yaml` 里，但代码已完全迁移到 `media_kit`，这两个是残留依赖，可以删
- 没有单元测试
- 没有截图（欢迎 PR 补）

---

## 许可

MIT
