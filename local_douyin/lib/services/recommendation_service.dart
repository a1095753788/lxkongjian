import 'dart:math';
import '../models/video_item.dart';
import '../utils/constants.dart' as consts;
import 'database_service.dart';

/// 推荐算法服务
///
/// 基于抖音/YouTube推荐系统核心原理设计：
///
/// **核心算法模型：**
///
/// 1. **过滤层（Filtering Layer）**
///    - 完全排除 `isNotInterested` 标记的视频
///    - 排除 `isFavorited` 收藏视频（收藏视频只在"收藏"页展示）
///    - 会话内短期去重（最近30条）
///
/// 2. **未看过优先（Unseen First）—— 硬分层，不是加分**
///    - 候选先按 `isNeverWatched` 切成两层：没看过的 / 看过的
///    - 填推荐列表时先把没看过的填满，数量不够才动用看过的
///    - 全部看完后第一层为空，自动退回纯分数排序
///
///    为什么用分层而不是"没看过的 +N 分"：加分是可以被反超的。
///    一条你反复看过的视频，播放次数和完播分累加起来轻易超过任何常数加成，
///    于是没看过的还是排在后面。分层才真的做到"优先"。
///
/// 3. **Engagement Score（互动分）**
///    - 点赞：+2
///    - 播放次数：+0.5/次（多次播放 = 反复观看 = 喜欢）
///
/// 4. **Dwell Time Score（观看时长分）**
///    - **只对看过的视频生效**（`playCount > 0`）
///    - 观看进度 < 0.2：-10（看过但马上划走，负分）
///    - 观看进度 0.2~0.5：+2（部分观看）
///    - 观看进度 0.5~0.9：+5（大部分观看）
///    - 观看进度 >= 0.9：+15（完整看完，高分）
///
///    注意：没看过的视频 `watchProgress` 天然是 0.0，如果也算进 < 0.2 分支，
///    就会被当成"被划走"扣 10 分。这是旧版最大的偏差来源——它让没看过的视频
///    永远排在看完的视频后面，和"优先推新的"完全相反。
///
/// 5. **Freshness（新鲜度）**
///    - 24小时内添加：+20（优先推新）
///    - 7天内添加：+10
///    - 30天内添加：+5
///    - 超过30天：+0（不再惩罚老视频）
///
/// 6. **Folder Affinity（文件夹亲和度）**
///    - 基于用户观看历史，计算每个文件夹的热度，归一化到 0~10
///    - 效果：在"没看过"那一层里，**你爱看的文件夹里的新视频会排得更靠前**
///
/// 7. **Explore（探索）**
///    - ε-greedy：15% 概率从长尾池随机拿（在每一层内部生效）
///
/// 8. **Diversity Constraint（多样性约束）**
///    - 同一文件夹连续不超过2条
///    - 避免信息茧房
///
/// **最终排序：**
/// 先按"看过 / 没看过"分层，层内再按
/// `score = engagement + dwellTime + freshness + folderAffinity + noise` 降序。
///
/// **参考来源：**
/// - YouTube Watch Next 算法：Engagement + Dwell Time + Freshness
/// - TikTok 推荐系统：互动分 + 完播率 + 多样性打散
/// - Content-based Filtering：基于内容相似性推荐
class RecommendationService {
  final DatabaseService _dbService = DatabaseService();
  final _random = Random();

  final List<String> _recentlyShown = [];
  static const int _recentlyShownLimit = 30;

  Future<List<VideoItem>> getRecommendedVideos({
    int limit = 100,
    Set<String>? excludeIds,
    String? lastFolderForDiversity,
  }) async {
    final allVideos = await _dbService.getAllVideos();
    if (allVideos.isEmpty) return [];

    // 过滤层：排除不感兴趣、已收藏和已排除的视频
    final exclude = excludeIds ?? <String>{};
    final candidates = allVideos.where((v) {
      if (v.isNotInterested) return false;
      if (v.isFavorited) return false;
      if (exclude.contains(v.id)) return false;
      if (_recentlyShown.contains(v.id)) return false;
      return true;
    }).toList();

    if (candidates.isEmpty) return [];

    // 计算用户观看习惯（文件夹亲和度）
    final folderAffinity = _computeFolderAffinity(candidates);

    // 计算每条视频的综合分数
    final scored = candidates.map((v) {
      return _ScoredVideo(v, _computeScore(v, folderAffinity));
    }).toList();

    // 按分数排序
    scored.sort((a, b) => b.score.compareTo(a.score));

    // === 未看过优先 ===
    // 切成两层：没看过的 / 看过的。先填满第一层，不够再用第二层补。
    // 全部看完时 unseen 为空，行为自动退回原来的纯分数排序。
    final unseen = scored.where((s) => s.video.isNeverWatched).toList();
    final seen = scored.where((s) => !s.video.isNeverWatched).toList();

    final state = _SelectionState(lastFolder: lastFolderForDiversity);

    for (final tier in [unseen, seen]) {
      if (state.result.length >= limit) break;
      _fillFromTier(tier, limit, state);
    }

    return state.result;
  }

  /// 从一层候选里挑视频，直到填满 [limit] 或这层被抽干。
  ///
  /// 利用池 / 探索池、ε-greedy、文件夹多样性都只在这一层内部生效，
  /// 刻意不跨层——否则"看过"的视频可能被 ε-greedy 抽到"没看过"前面，
  /// 分层就失去意义了。
  void _fillFromTier(List<_ScoredVideo> tier, int limit, _SelectionState state) {
    if (tier.isEmpty) return;

    // 前 70% 当利用池，其余当探索池。
    // 这里不能用 `clamp(5, length)`：视频少于 5 条时下界会大于上界，
    // Dart 的 clamp 遇到这种情况直接抛 ArgumentError，整个推荐页会崩。
    // 用 min/max 夹住，长度多小都安全。
    final cut = min(max((tier.length * 0.7).round(), 1), tier.length);
    final exploitPool = tier.take(cut).toList();
    final explorePool = tier.skip(cut).toList();

    while (state.result.length < limit) {
      // ε-greedy：15% 概率探索，85% 概率利用
      final isExplore =
          explorePool.isNotEmpty && _random.nextDouble() < consts.AppConstants.exploreEpsilon;
      final pool = isExplore ? explorePool : exploitPool;

      // 多样性约束：同文件夹连续不超过 maxConsecutivePerFolder 条
      VideoItem? picked = _pickFromPool(
        pool,
        state.usedIds,
        state.lastFolder,
        state.consecutive,
        maxConsecutive: consts.AppConstants.maxConsecutivePerFolder,
      );

      // 如果多样性约束太严格找不到，放宽限制
      picked ??= _pickFromPool(pool, state.usedIds, null, 999, maxConsecutive: 999);

      // 这个池找不到时从另一个池找
      if (picked == null) {
        final otherPool = isExplore ? exploitPool : explorePool;
        picked = _pickFromPool(otherPool, state.usedIds, null, 999, maxConsecutive: 999);
      }

      // 整层都抽干了，交给下一层
      if (picked == null) return;

      _accept(state, picked);
    }
  }

  /// 把一条视频收进结果，并更新跨层共用的状态。
  void _accept(_SelectionState state, VideoItem picked) {
    state.result.add(picked);
    state.usedIds.add(picked.id);

    // 更新文件夹连续计数
    if (picked.folderId == state.lastFolder) {
      state.consecutive++;
    } else {
      state.consecutive = 1;
      state.lastFolder = picked.folderId;
    }

    // 短期去重队列
    _recentlyShown.add(picked.id);
    if (_recentlyShown.length > _recentlyShownLimit) {
      _recentlyShown.removeAt(0);
    }
  }

  VideoItem? _pickFromPool(
    List<_ScoredVideo> pool,
    Set<String> usedIds,
    String? lastFolder,
    int consecutiveSameFolder, {
    required int maxConsecutive,
  }) {
    for (final entry in pool) {
      if (usedIds.contains(entry.video.id)) continue;
      if (_recentlyShown.contains(entry.video.id)) continue;
      if (entry.video.folderId == lastFolder &&
          consecutiveSameFolder >= maxConsecutive) {
        continue;
      }
      return entry.video;
    }
    return null;
  }

  /// 综合评分
  double _computeScore(VideoItem video, Map<String, double> folderAffinity) {
    double score = 0.0;

    // === 1. Engagement Score（互动分）===
    // 点赞：+2
    score += video.likeCount * 2.0;
    // 播放次数：+0.5/次（多次播放 = 反复观看 = 喜欢）
    score += video.playCount * 0.5;
    // 注：这里原本还有一条"已收藏 +10"，但收藏视频在过滤层就被排除了，
    // 永远走不到这行，属于死代码，已删除。

    // === 2. Dwell Time Score（观看时长分）===
    // 核心信号：用户看了多久决定了是否喜欢。
    // 但"看了多久"只对**真的看过**的视频有意义，所以整段用 isNeverWatched 挡在外面。
    //
    // 旧版没有这道判断：没看过的视频 watchProgress 天然是 0.0，会掉进
    // <0.2 分支被扣 10 分，等于在惩罚"还没看过的视频"。
    if (!video.isNeverWatched) {
      if (video.watchProgress < 0.2) {
        score -= 10.0; // 看过但马上划走，强烈负信号
      } else if (video.watchProgress < 0.5) {
        score += 2.0; // 部分观看
      } else if (video.watchProgress < 0.9) {
        score += 5.0; // 大部分观看
      } else {
        score += 15.0; // 完整看完，最强正信号
      }
    }

    // === 3. Freshness（新鲜度）===
    // 新视频优先，但不惩罚老视频
    final hoursSinceAdded = DateTime.now().difference(video.addedAt).inHours;
    if (hoursSinceAdded <= 24) {
      score += 20.0; // 24小时内添加的新视频
    } else if (hoursSinceAdded <= 7 * 24) {
      score += 10.0; // 7天内添加
    } else if (hoursSinceAdded <= 30 * 24) {
      score += 5.0; // 30天内添加
    }
    // 超过30天：不加分也不减分，好内容永远有机会

    // === 4. Folder Affinity（文件夹亲和度）===
    // 如果用户经常看某个文件夹的视频，同文件夹视频加分
    final affinity = folderAffinity[video.folderId] ?? 0;
    score += affinity;

    // === 5. Explore Bonus（探索奖励）===
    // 这里原本是"playCount == 0 加 10 分"。改成按 isNeverWatched 分层之后，
    // 这一层里所有视频都是没看过的，加同一个常数等于没加（不改变层内顺序），
    // 而跨层排序由分层直接决定，不看分数。所以这个加成已经不起作用，删掉。

    // === 6. 小扰动（避免顺序一成不变）===
    score += _random.nextDouble() * 2.0;

    return score;
  }

  /// 计算文件夹亲和度
  /// 返回 map: folderId -> affinityScore
  /// 基于视频播放次数和观看进度计算每个文件夹的热度
  Map<String, double> _computeFolderAffinity(List<VideoItem> candidates) {
    final folderStats = <String, _FolderStat>{};

    for (final video in candidates) {
      final stat = folderStats.putIfAbsent(
        video.folderId,
        () => _FolderStat(playCount: 0, totalWatchProgress: 0, videoCount: 0),
      );
      stat.playCount += video.playCount;
      stat.totalWatchProgress += video.watchProgress;
      stat.videoCount++;
    }

    // 归一化亲和度分数（0~10）
    final affinity = <String, double>{};
    double maxScore = 1;

    for (final entry in folderStats.entries) {
      final stat = entry.value;
      // 亲和度 = (播放次数权重 + 观看进度权重) / 视频数量
      final playScore = stat.playCount * 0.5;
      final watchScore = stat.totalWatchProgress * 2.0;
      final score = (playScore + watchScore) / max(stat.videoCount, 1);
      affinity[entry.key] = score;
      if (score > maxScore) maxScore = score;
    }

    // 归一化到 0~10 范围
    for (final key in affinity.keys) {
      affinity[key] = (affinity[key]! / maxScore) * 10;
    }

    return affinity;
  }

  Future<List<VideoItem>> getMoreRecommendedVideos({
    required int limit,
    required List<VideoItem> existing,
  }) async {
    final excludeIds = existing.map((v) => v.id).toSet();
    final lastFolder = existing.isNotEmpty ? existing.last.folderId : null;
    return getRecommendedVideos(
      limit: limit,
      excludeIds: excludeIds,
      lastFolderForDiversity: lastFolder,
    );
  }

  Future<List<VideoItem>> getFreshVideos({int limit = 20}) async {
    final allVideos = await _dbService.getAllVideos();
    final freshVideos = allVideos
        .where((v) => !v.isNotInterested && v.isNeverWatched)
        .toList();
    freshVideos.shuffle(_random);
    return freshVideos.take(limit).toList();
  }

  Future<List<VideoItem>> getLikedVideos() async {
    final allVideos = await _dbService.getAllVideos();
    return allVideos.where((v) => !v.isNotInterested && v.isLiked).toList();
  }

  Future<List<VideoItem>> getFavoriteVideos() async {
    final allVideos = await _dbService.getAllVideos();
    return allVideos.where((v) => !v.isNotInterested && v.isFavorited).toList();
  }

  Future<List<VideoItem>> getMostPlayedVideos({int limit = 20}) async {
    final allVideos = await _dbService.getAllVideos();
    final filtered = allVideos.where((v) => !v.isNotInterested).toList();
    filtered.sort((a, b) => b.playCount.compareTo(a.playCount));
    return filtered.take(limit).toList();
  }

  void clearSessionMemory() {
    _recentlyShown.clear();
  }
}

class _ScoredVideo {
  final VideoItem video;
  final double score;
  _ScoredVideo(this.video, this.score);
}

/// 挑选过程的游标。
///
/// 抽成独立对象是因为"没看过 / 看过"两层要共用同一套状态：
/// 第二层接着第一层的 usedIds 和文件夹连续计数往下挑，
/// 才能保证跨层也不会重复、不会出现三连同一文件夹。
class _SelectionState {
  final List<VideoItem> result = [];
  final Set<String> usedIds = {};
  String? lastFolder;
  int consecutive = 0;

  _SelectionState({this.lastFolder}) {
    // 上一批的最后一条如果是同一个文件夹，连续计数从 1 起算，
    // 这样跨批次的"同一文件夹不超 2 连"也能接上。
    if (lastFolder != null) consecutive = 1;
  }
}

class _FolderStat {
  int playCount;
  double totalWatchProgress;
  int videoCount;
  _FolderStat({required this.playCount, required this.totalWatchProgress, required this.videoCount});
}
