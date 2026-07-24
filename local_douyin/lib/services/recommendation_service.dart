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
/// 2. **Engagement Score（互动分）**
///    - 点赞：+2
///    - 收藏：+10（用户明确喜爱）
///    - 评论：+3（深度互动）
///    - 播放次数：+0.5/次（多次播放 = 反复观看 = 喜欢）
///
/// 3. **Dwell Time Score（观看时长分）**
///    - 观看进度 < 0.2：-10（快速跳过，负分）
///    - 观看进度 0.2~0.5：+2（部分观看）
///    - 观看进度 0.5~0.9：+5（大部分观看）
///    - 观看进度 >= 0.9：+15（完整看完，高分）
///
/// 4. **Freshness（新鲜度）**
///    - 24小时内添加：+20（优先推新）
///    - 7天内添加：+10
///    - 30天内添加：+5
///    - 超过30天：+0（不再惩罚老视频）
///
/// 5. **Folder Affinity（文件夹亲和度）**
///    - 基于用户观看历史，计算每个文件夹的热度
///    - 同文件夹视频获得额外加成
///
/// 6. **Explore Bonus（探索奖励）**
///    - 从未播放过的视频：+10（鼓励发现新内容）
///    - ε-greedy：15%概率从长尾池探索
///
/// 7. **Diversity Constraint（多样性约束）**
///    - 同一文件夹连续不超过2条
///    - 避免信息茧房
///
/// **最终排序公式：**
/// `score = engagement + dwellTime + freshness + folderAffinity + exploreBonus + noise`
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

    // 划分 Exploit / Explore 池
    final cutIndex = (scored.length * 0.7).clamp(5, scored.length).toInt();
    final exploitPool = scored.take(cutIndex).toList();
    final explorePool = scored.skip(cutIndex).toList();

    // ε-greedy + 多样性约束的选择
    final result = <VideoItem>[];
    final usedIds = <String>{};
    String? lastFolder = lastFolderForDiversity;
    int consecutiveSameFolder = lastFolder == null ? 0 : 1;

    while (result.length < limit && usedIds.length < candidates.length) {
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
    // 收藏：+10（用户明确喜爱的强信号）
    score += video.isFavorited ? 10.0 : 0;
    // 播放次数：+0.5/次（多次播放 = 反复观看 = 喜欢）
    score += video.playCount * 0.5;

    // === 2. Dwell Time Score（观看时长分）===
    // 核心信号：用户看了多久决定了是否喜欢
    if (video.watchProgress < 0.2) {
      score -= 10.0; // 快速跳过，强烈负信号
    } else if (video.watchProgress >= 0.2 && video.watchProgress < 0.5) {
      score += 2.0; // 部分观看
    } else if (video.watchProgress >= 0.5 && video.watchProgress < 0.9) {
      score += 5.0; // 大部分观看
    } else if (video.watchProgress >= 0.9) {
      score += 15.0; // 完整看完，最强正信号
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
    // 从未播放过的视频给予加成，鼓励发现新内容
    if (video.playCount == 0) {
      score += 10.0;
    }

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
        .where((v) => !v.isNotInterested && v.playCount == 0)
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

class _FolderStat {
  int playCount;
  double totalWatchProgress;
  int videoCount;
  _FolderStat({required this.playCount, required this.totalWatchProgress, required this.videoCount});
}
