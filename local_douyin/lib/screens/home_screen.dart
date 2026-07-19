import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/video_provider.dart';
import '../widgets/video_feed.dart';
import '../widgets/favorite_feed.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // 加载视频
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VideoProvider>().loadVideos();
    });
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
      body: SafeArea(
        child: Column(
          children: [
            // 顶部标签栏
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                indicatorSize: TabBarIndicatorSize.label,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white54,
                labelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                unselectedLabelStyle: const TextStyle(fontSize: 16),
                tabs: const [
                  Tab(text: '推荐'),
                  Tab(text: '收藏'),
                ],
              ),
            ),
            // 视频内容
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  const VideoFeed(),
                  const FavoriteFeed(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
