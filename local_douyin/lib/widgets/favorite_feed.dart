import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/video_item.dart';
import '../providers/video_provider.dart';
import '../providers/player_provider.dart';
import '../providers/comment_provider.dart';
import 'video_player_item.dart';
import 'video_side_actions.dart';

class FavoriteFeed extends StatefulWidget {
  const FavoriteFeed({super.key});

  @override
  State<FavoriteFeed> createState() => _FavoriteFeedState();
}

class _FavoriteFeedState extends State<FavoriteFeed> {
  late PageController _pageController;
  late VideoProvider _videoProvider;
  int _currentPage = 0;
  List<VideoItem> _favoriteVideos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _videoProvider = context.read<VideoProvider>();
    // 收藏状态可能从任何地方改变（推荐流里点收藏、这里取消收藏），
    // 必须监听 provider，否则列表会停留在 initState 那一刻的快照。
    _videoProvider.addListener(_syncFavorites);
    _loadFavoriteVideos();
  }

  @override
  void dispose() {
    _videoProvider.removeListener(_syncFavorites);
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadFavoriteVideos() async {
    setState(() => _isLoading = true);
    try {
      _favoriteVideos = await context.read<VideoProvider>().getFavoriteVideos();
      // 随机打乱顺序（只在首次加载时打乱，后续同步保持已有序）
      _favoriteVideos.shuffle();
    } catch (e) {
      _favoriteVideos = [];
    }
    if (mounted) setState(() => _isLoading = false);
  }

  /// 增量同步收藏列表：移除已取消的、追加新收藏的，已有条目原地刷新。
  ///
  /// 不做整表重载 + 重新 shuffle —— 那样用户取消一个收藏，
  /// 整个列表顺序都会变，正在看的视频会跳位置。
  void _syncFavorites() {
    if (!mounted || _isLoading) return;

    final all = _videoProvider.videos;
    // provider 还没加载完时不要误清空列表
    if (all.isEmpty && _favoriteVideos.isNotEmpty) return;

    final favorited = all.where((v) => v.isFavorited).toList();
    final favoritedIds = favorited.map((v) => v.id).toSet();
    final shownIds = _favoriteVideos.map((v) => v.id).toSet();

    final hasRemoval = _favoriteVideos.any((v) => !favoritedIds.contains(v.id));
    final added = favorited.where((v) => !shownIds.contains(v.id)).toList();

    if (!hasRemoval && added.isEmpty) {
      // 集合没变，但条目内容可能变了（点赞数、播放次数），原地替换
      _replaceInPlace(favorited);
      return;
    }

    setState(() {
      _favoriteVideos =
          _favoriteVideos.where((v) => favoritedIds.contains(v.id)).toList();
      _favoriteVideos.addAll(added);
      // 用最新对象覆盖，保证界面上的计数同步
      for (var i = 0; i < _favoriteVideos.length; i++) {
        final latest = favorited.firstWhere(
          (v) => v.id == _favoriteVideos[i].id,
          orElse: () => _favoriteVideos[i],
        );
        _favoriteVideos[i] = latest;
      }
    });

    _clampCurrentPage();
  }

  void _replaceInPlace(List<VideoItem> favorited) {
    var changed = false;
    for (var i = 0; i < _favoriteVideos.length; i++) {
      final latest = favorited.firstWhere(
        (v) => v.id == _favoriteVideos[i].id,
        orElse: () => _favoriteVideos[i],
      );
      if (!identical(latest, _favoriteVideos[i])) {
        _favoriteVideos[i] = latest;
        changed = true;
      }
    }
    if (changed) setState(() {});
  }

  /// 取消收藏当前正在看的那条后，索引会越界，需要回退
  void _clampCurrentPage() {
    if (_favoriteVideos.isEmpty) {
      _currentPage = 0;
      return;
    }
    final maxIndex = _favoriteVideos.length - 1;
    if (_currentPage <= maxIndex) return;

    _currentPage = maxIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _pageController.hasClients) {
        _pageController.jumpToPage(maxIndex);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFFE2C55)));
    }

    if (_favoriteVideos.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.favorite_border, size: 60, color: Colors.white24),
            const SizedBox(height: 16),
            const Text('暂无收藏视频', style: TextStyle(color: Colors.white38, fontSize: 16)),
            const SizedBox(height: 8),
            const Text('在播放页点击星星图标收藏视频', style: TextStyle(color: Colors.white38, fontSize: 14)),
          ],
        ),
      );
    }

    return PageView.builder(
      controller: _pageController,
      scrollDirection: Axis.vertical,
      itemCount: _favoriteVideos.length,
      onPageChanged: (index) {
        _currentPage = index;
        // 切换视频时同步评论
        context.read<CommentProvider>().setCurrentVideo(_favoriteVideos[index].id);
      },
      itemBuilder: (context, index) {
        final video = _favoriteVideos[index];
        return Stack(
          fit: StackFit.expand,
          children: [
            VideoPlayerItem(video: video, index: index),
            Positioned(
              left: 12,
              bottom: 80,
              right: 70,
              child: _VideoInfo(video: video),
            ),
            VideoSideActions(video: video),
          ],
        );
      },
    );
  }
}

class _VideoInfo extends StatelessWidget {
  final VideoItem video;

  const _VideoInfo({required this.video});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          video.displayName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.play_circle_outline, color: Colors.white70, size: 14),
            const SizedBox(width: 4),
            Text(
              '${video.playCount}次播放',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.sd_card_outlined, color: Colors.white70, size: 14),
            const SizedBox(width: 4),
            Text(
              video.fileSizeFormatted,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      ],
    );
  }
}
