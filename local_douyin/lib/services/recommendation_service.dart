import 'dart:math';
import '../models/video_item.dart';
import '../utils/constants.dart' as consts;
import 'database_service.dart';

/// 推荐算法服务
///
/// 综合使用以下开源算法：
///
/// 1. **Bayesian Average（贝叶斯平均，IMDb 评分算法）**
///    用于平滑评分，避免少量播放次数的视频被高估或低估。
///    公式：`weighted = (v/(v+m)) * R + (m/(v+m)) * C`
///    - R = 视频互动率（点赞+收藏加权）/ 播放次数
///    - v = 播放次数
///    - m = 最低票数阈值
///    - C = 全库平均互动率
///
/// 2. **Hacker News 排序公式**
///    `score / (ageHours + 2)^gravity`
///    温和时间衰减，避免老视频永远占榜首，但也不会快速消失。
///
/// 3. **ε-greedy 探索-利用平衡（多臂老虎机）**
///    ε 概率随机探索长尾视频，1-ε 概率利用高分视频。
///    避免信息茧房，让冷门视频有机会曝光。
///
/// 4. **MMR 多样性约束（简化版）**
///    同一文件夹连续推荐不超过 N 条，避免来源单一。
///
/// 5. **重看策略**
///    看过的视频适度降权（×0.6），收藏的视频不降权。
///    短视频天然适合重复消费，不应像旧算法那样几乎屏蔽。
class RecommendationService {
  final DatabaseService _dbService = DatabaseService();
  final _random = Random();

  // 会话内短期去重：避免短时间内同一视频被反复推荐
  final List<String> _recentlyShown = [];
  static const int _recentlyShownLimit = 30;

  Future<List<VideoItem>> getRecommendedVideos({
    int limit = 100,
    Set<String>? excludeIds,
    String? lastFolderForDiversity,
  }) async {
    final allVideos = await _dbService.getAllVideos();
    if (allVideos.isEmpty) return [];

    // 排除已经推荐过的视频（追加加载时使用）
    final exclude = excludeIds ?? <String>{};

    // 计算全库平均互动率（Bayesian Average 的先验 C）
    final globalStats = _computeGlobalStats(allVideos);
    final avgInteraction = globalStats['avgInteraction'] as double;

    // 1. 计算每条视频的综合分数
    final scored = allVideos
        .where((v) => !exclude.contains(v.id))
        .map((v) => _ScoredVideo(v, _computeScore(v, avgInteraction)))
        .toList();

    if (scored.isEmpty) return [];

    // 2. 按分数排序
    scored.sort((a, b) => b.score.compareTo(a.score));

    // 3. 划分 Exploit / Explore 池
    //    Exploit 池：前 70%（高分），Explore 池：后 30%（长尾）
    final cutIndex = (scored.length * 0.7).clamp(5, scored.length).toInt();
    final exploitPool = scored.take(cutIndex).toList();
    final explorePool = scored.skip(cutIndex).toList();

    // 4. ε-greedy + 多样性约束的选择
    final result = <VideoItem>[];
    final usedIds = <String>{};
    String? lastFolder = lastFolderForDiversity;
    int consecutiveSameFolder = lastFolder == null ? 0 : 1;

    while (result.length < limit && usedIds.length < scored.length) {
      // ε-greedy：15% 概率探索，85% 概率利用
      final isExplore =
          explorePool.isNotEmpty && _random.nextDouble() < consts.AppConstants.exploreEpsilon;
      final pool = isExplore ? explorePool : exploitPool;

      // 多样性约束：同文件夹连续不超过 maxConsecutivePerFolder 条
      VideoItem? picked = _pickFromPool(
        pool,
        usedIds,
        lastFolder,
        consecutiveSameFolder,
        maxConsecutive: consts.AppConstants.maxConsecutivePerFolder,
      );

      // 如果多样性约束太严格找不到，放宽限制
      if (picked == null) {
        picked = _pickFromPool(pool, usedIds, null, 999, maxConsecutive: 999);
      }

      // Exploit 池找不到时从 Explore 池找，反之亦然
      if (picked == null) {
        final otherPool = isExplore ? exploitPool : explorePool;
        picked = _pickFromPool(otherPool, usedIds, null, 999, maxConsecutive: 999);
      }

      if (picked == null) break;

      result.add(picked);
      usedIds.add(picked.id);

      // 更新文件夹连续计数
      if (picked.folderId == lastFolder) {
        consecutiveSameFolder++;
      } else {
        consecutiveSameFolder = 1;
        lastFolder = picked.folderId;
      }

      // 短期去重队列
      _recentlyShown.add(picked.id);
      if (_recentlyShown.length > _recentlyShownLimit) {
        _recentlyShown.removeAt(0);
      }
    }

    return result;
  }

  /// 追加生成更多推荐视频（不清空已有列表）
  /// 传入已推荐的 ID 列表，返回不重复的新视频
  Future<List<VideoItem>> getMoreRecommendedVideos({
    required int limit,
    required List<VideoItem> existing,
  }) async {
    final excludeIds = existing.map((v) => v.id).toSet();
    // 传入当前末尾视频的文件夹，用于多样性衔接
    final lastFolder = existing.isNotEmpty ? existing.last.folderId : null;
    return getRecommendedVideos(
      limit: limit,
      excludeIds: excludeIds,
      lastFolderForDiversity: lastFolder,
    );
  }

  /// 从池中按多样性约束挑选一条视频
  VideoItem? _pickFromPool(
    List<_ScoredVideo> pool,
    Set<String> usedIds,
    String? lastFolder,
    int consecutiveSameFolder, {
    required int maxConsecutive,
  }) {
    // 池内已按分数排序，选第一个满足约束的（贪心 + 多样性）
    for (final entry in pool) {
      if (usedIds.contains(entry.video.id)) continue;
      // 短期去重：跳过最近 30 条已推荐的
      if (_recentlyShown.contains(entry.video.id)) continue;
      // 同文件夹连续约束
      if (entry.video.folderId == lastFolder &&
          consecutiveSameFolder >= maxConsecutive) {
        continue;
      }
      return entry.video;
    }
    return null;
  }

  /// 综合评分：Bayesian Average × HN 时间衰减 × 重看策略
  double _computeScore(VideoItem video, double avgInteraction) {
    // === 1. Bayesian Average 评分 ===
    // R = 该视频的互动率（点赞 + 收藏加权）/ (playCount + 1)
    // v = playCount + 1（避免除零）
    // m = 最低票数阈值
    final positives = video.likeCount * 2 +
        (video.isLiked ? 3 : 0) +
        (video.isFavorited ? 5 : 0);
    final v = video.playCount + 1.0;
    final R = positives / v;

    final m = consts.AppConstants.bayesianMinVotes.toDouble();
    final C = avgInteraction;
    final bayesianScore = (v / (v + m)) * R + (m / (v + m)) * C;

    // === 2. 热度分（保留计数信息，避免完全被贝叶斯平滑掉）===
    final popularity = video.playCount * consts.AppConstants.playCountWeight +
        video.likeCount * consts.AppConstants.likeCountWeight +
        (video.isFavorited ? consts.AppConstants.isFavoritedWeight : 0) +
        (video.isLiked ? consts.AppConstants.isLikedWeight : 0);

    // 综合质量分（贝叶斯 + 热度）
    double score = bayesianScore * 20 + popularity * 0.5;

    // === 3. HN 风格时间衰减（基于 lastPlayedAt，温和版本）===
    // 公式：score / (ageDays + 2)^gravity
    // 注：基于"上次播放时间"而非"添加时间"，避免老视频永远被埋
    final ageDays = DateTime.now().difference(video.lastPlayedAt).inHours / 24.0;
    final gravity = consts.AppConstants.hnGravity;
    final timeDecay = 1.0 / pow(ageDays + 2, gravity);
    score *= timeDecay;

    // === 4. 重看策略 ===
    // 看过的适度降权（不消失），收藏的不降权（用户明确喜欢）
    if (video.watchProgress > 0.9 && !video.isFavorited) {
      score *= consts.AppConstants.completedPenalty; // 0.6
    } else if (video.watchProgress > 0.5 && !video.isFavorited) {
      score *= 0.85;
    }

    // 从未播放过的视频给一个小幅提升（鼓励发现新内容）
    if (video.playCount == 0) {
      score *= 1.2;
    }

    return score;
  }

  /// 计算全库平均互动率（Bayesian Average 的先验 C）
  Map<String, dynamic> _computeGlobalStats(List<VideoItem> videos) {
    if (videos.isEmpty) {
      return {'avgInteraction': 0.0};
    }
    double totalRate = 0;
    for (final v in videos) {
      final positives = v.likeCount * 2 +
          (v.isLiked ? 3 : 0) +
          (v.isFavorited ? 5 : 0);
      totalRate += positives / (v.playCount + 1.0);
    }
    return {'avgInteraction': totalRate / videos.length};
  }

  Future<List<VideoItem>> getFreshVideos({int limit = 20}) async {
    final allVideos = await _dbService.getAllVideos();
    final freshVideos = allVideos.where((v) => v.playCount == 0).toList();
    freshVideos.shuffle(_random);
    return freshVideos.take(limit).toList();
  }

  Future<List<VideoItem>> getLikedVideos() async {
    final allVideos = await _dbService.getAllVideos();
    return allVideos.where((v) => v.isLiked).toList();
  }

  Future<List<VideoItem>> getFavoriteVideos() async {
    final allVideos = await _dbService.getAllVideos();
    return allVideos.where((v) => v.isFavorited).toList();
  }

  Future<List<VideoItem>> getMostPlayedVideos({int limit = 20}) async {
    final allVideos = await _dbService.getAllVideos();
    allVideos.sort((a, b) => b.playCount.compareTo(a.playCount));
    return allVideos.take(limit).toList();
  }

  /// 清空会话内的"最近推荐"记录
  /// 在用户主动下拉刷新首页时调用
  void clearSessionMemory() {
    _recentlyShown.clear();
  }
}

/// 带分数的视频条目（内部使用）
class _ScoredVideo {
  final VideoItem video;
  final double score;
  _ScoredVideo(this.video, this.score);
}
