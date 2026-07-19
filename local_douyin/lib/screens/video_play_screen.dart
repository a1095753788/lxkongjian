import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/video_item.dart';
import '../providers/video_provider.dart';
import '../providers/player_provider.dart';
import '../widgets/video_player_item.dart';
import '../widgets/video_side_actions.dart';

class VideoPlayScreen extends StatefulWidget {
  final List<VideoItem> videos;
  final int initialIndex;

  const VideoPlayScreen({
    super.key,
    required this.videos,
    this.initialIndex = 0,
  });

  @override
  State<VideoPlayScreen> createState() => _VideoPlayScreenState();
}

class _VideoPlayScreenState extends State<VideoPlayScreen> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    // 停止播放
    context.read<PlayerProvider>().stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: PageView.builder(
          controller: _pageController,
          scrollDirection: Axis.vertical,
          itemCount: widget.videos.length,
          onPageChanged: (index) {
            _currentIndex = index;
          },
          itemBuilder: (context, index) {
            final video = widget.videos[index];
            return Stack(
              fit: StackFit.expand,
              children: [
                VideoPlayerItem(video: video, index: index),
                // 顶部返回按钮
                Positioned(
                  top: 8,
                  left: 8,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
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
