import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/video_provider.dart';
import '../models/video_item.dart';
import '../theme/app_theme.dart';
import 'video_play_screen.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('发现'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryColor,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: '最新'),
            Tab(text: '最热'),
            Tab(text: '喜欢'),
            Tab(text: '收藏'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _VideoList(loader: () => context.read<VideoProvider>().getFreshVideos()),
          _VideoList(loader: () => context.read<VideoProvider>().getMostPlayedVideos()),
          _VideoList(loader: () => context.read<VideoProvider>().getLikedVideos()),
          _VideoList(loader: () => context.read<VideoProvider>().getFavoriteVideos()),
        ],
      ),
    );
  }
}

class _VideoList extends StatefulWidget {
  final Future<List<VideoItem>> Function() loader;

  const _VideoList({required this.loader});

  @override
  State<_VideoList> createState() => _VideoListState();
}

class _VideoListState extends State<_VideoList> {
  List<VideoItem> _videos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVideos();
  }

  Future<void> _loadVideos() async {
    setState(() => _isLoading = true);
    try {
      _videos = await widget.loader();
    } catch (e) {
      _videos = [];
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
    }

    if (_videos.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.explore_outlined, size: 60, color: Colors.white24),
            SizedBox(height: 16),
            Text('暂无视频', style: TextStyle(color: Colors.white38, fontSize: 16)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppTheme.primaryColor,
      onRefresh: _loadVideos,
      child: GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.75,
        ),
        itemCount: _videos.length,
        itemBuilder: (context, index) {
          final video = _videos[index];
          return _VideoGridItem(
            video: video,
            videos: _videos,
            index: index,
          );
        },
      ),
    );
  }
}

class _VideoGridItem extends StatelessWidget {
  final VideoItem video;
  final List<VideoItem> videos;
  final int index;

  const _VideoGridItem({
    required this.video,
    required this.videos,
    required this.index,
  });

  Widget _buildThumbnail(VideoItem video) {
    final thumbPath = video.thumbnailPath;
    if (thumbPath != null && thumbPath.isNotEmpty) {
      final file = File(thumbPath);
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          file,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) {
            return const Center(
              child: Icon(Icons.play_circle_outline, color: Colors.white24, size: 40),
            );
          },
        ),
      );
    }
    return const Center(
      child: Icon(Icons.play_circle_outline, color: Colors.white24, size: 40),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => VideoPlayScreen(
                  videos: videos,
                  initialIndex: index,
                ),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2A2A),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _buildThumbnail(video),
                    ),
                    // 渐变遮罩，让底部信息更易读
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.3),
                            ],
                            stops: const [0.6, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.displayName,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.play_arrow, color: Colors.white38, size: 14),
                        const SizedBox(width: 2),
                        Text(
                          '${video.playCount}',
                          style: const TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                        const Spacer(),
                        Text(
                          video.fileSizeFormatted,
                          style: const TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
