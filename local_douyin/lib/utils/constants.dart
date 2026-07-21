class AppConstants {
  static const String appName = '本地抖音';
  static const String dbName = 'local_douyin.db';
  static const int dbVersion = 4;

  // 支持的视频格式
  static const List<String> supportedVideoExtensions = [
    '.mp4', '.avi', '.mkv', '.mov', '.wmv', '.flv', '.webm',
    '.3gp', '.ts', '.m4v', '.mpeg', '.mpg',
  ];

  // === 推荐算法参数（综合 Bayesian Average + HN 衰减 + ε-greedy + MMR 多样性）===

  // 基础热度权重
  static const double playCountWeight = 0.5;
  static const double likeCountWeight = 2.0;
  static const double isLikedWeight = 2.0;
  static const double isFavoritedWeight = 5.0;

  // Bayesian Average 参数
  // m = 最低票数阈值，越大越保守；新视频 playCount < m 时分数被平滑向全库均值靠拢
  static const int bayesianMinVotes = 3;

  // Hacker News 时间衰减参数
  // 公式：score / (ageDays + 2)^gravity
  // gravity 越大衰减越快；1.0 为温和，1.5 为标准 HN，2.0 较激进
  static const double hnGravity = 1.0;

  // ε-greedy 探索率（0.0~1.0）
  // ε=0.15 表示 15% 概率从长尾池随机探索，85% 概率从高分池利用
  static const double exploreEpsilon = 0.15;

  // MMR 多样性约束：同一文件夹连续推荐最多多少条
  static const int maxConsecutivePerFolder = 2;

  // 重看策略
  // 看完的视频适度降权（×0.6），不再像旧算法那样几乎屏蔽（×0.3）
  static const double completedPenalty = 0.6;

  // 转码配置
  static const String transcodeOutputFormat = 'mp4';
  static const String transcodeVideoCodec = 'libx264';
  static const String transcodeAudioCodec = 'aac';
  static const int transcodeCrf = 23;
}
