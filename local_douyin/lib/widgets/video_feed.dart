import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/video_item.dart';
import '../providers/video_provider.dart';
import 'video_player_item.dart';
import 'video_side_actions.dart';

class VideoFeed extends StatefulWidget {
  const VideoFeed({super.key});

  @override
  State<VideoFeed> createState() => _VideoFeedState();
}

class _VideoFeedState extends State<VideoFeed> {
  late PageController _pageController;
  int _currentPage = 0;
  // 防止追加加载重复触发
  bool _isLoadingMore = false;
  // 全库已全部加载完，不再尝试追加
  bool _noMore = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    // 用户主动刷新：清空会话记忆并重新生成推荐
    _noMore = false;
    final vp = context.read<VideoProvider>();
    vp.clearRecommendationMemory();
    await vp.loadRecommendedVideos();
  }

  Future<void> _maybeLoadMore(int currentIndex, int total) async {
    if (_isLoadingMore || _noMore) return;
    // 接近末尾 10 条时追加
    if (currentIndex >= total - 10) {
      _isLoadingMore = true;
      try {
        final vp = context.read<VideoProvider>();
        final added = await vp.appendRecommendedVideos(count: 100);
        if (added == 0) {
          _noMore = true; // 全库已加载完
        }
      } finally {
        _isLoadingMore = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<VideoProvider>(
      builder: (context, videoProvider, child) {
        final videos = videoProvider.recommendedVideos;

        if (videoProvider.isLoading && videos.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFFE2C55)),
          );
        }

        if (videos.isEmpty) {
          return _buildEmptyState();
        }

        // 列表自动追加：滑到接近末尾时加载更多视频
        // 刷新通过右上角按钮触发（避免与垂直 PageView 手势冲突）
        return Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              itemCount: videos.length,
              onPageChanged: (index) {
                _currentPage = index;
                // 接近末尾时追加更多视频
                _maybeLoadMore(index, videos.length);
              },
              itemBuilder: (context, index) {
                final video = videos[index];
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    VideoPlayerItem(video: video, index: index),
                    // 视频信息
                    Positioned(
                      left: 12,
                      bottom: 80,
                      right: 70,
                      child: _VideoInfo(video: video),
                    ),
                    // 侧边操作按钮
                    VideoSideActions(video: video),
                  ],
                );
              },
            ),
            // 顶部刷新按钮
            Positioned(
              top: 8,
              right: 12,
              child: SafeArea(
                child: GestureDetector(
                  onTap: _onRefresh,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.refresh,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ),
            // 加载更多指示器
            if (_isLoadingMore)
              Positioned(
                bottom: 20,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          '加载更多...',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.video_library_outlined,
            size: 80,
            color: Colors.white24,
          ),
          const SizedBox(height: 16),
          const Text(
            '还没有视频',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '去"文件夹"页面添加视频文件夹吧',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              // 切换到文件夹tab
              DefaultTabController.of(context).animateTo(1);
            },
            icon: const Icon(Icons.folder_open),
            label: const Text('添加文件夹'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFE2C55),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
        ],
      ),
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
            const Icon(Icons.folder_outlined, color: Colors.white70, size: 14),
            const SizedBox(width: 4),
            Text(
              video.folderId,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 4),
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
