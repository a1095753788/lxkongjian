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
  int _currentPage = 0;
  List<VideoItem> _favoriteVideos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _loadFavoriteVideos();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadFavoriteVideos() async {
    setState(() => _isLoading = true);
    try {
      _favoriteVideos = await context.read<VideoProvider>().getFavoriteVideos();
      // 随机打乱顺序
      _favoriteVideos.shuffle();
    } catch (e) {
      _favoriteVideos = [];
    }
    if (mounted) setState(() => _isLoading = false);
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
