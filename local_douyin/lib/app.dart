import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'providers/video_provider.dart';
import 'providers/folder_provider.dart';
import 'providers/player_provider.dart';
import 'providers/comment_provider.dart';
import 'screens/home_screen.dart';
import 'screens/folder_screen.dart';
import 'screens/discover_screen.dart';
import 'screens/profile_screen.dart';
import 'theme/app_theme.dart';

class LocalDouyinApp extends StatefulWidget {
  const LocalDouyinApp({super.key});

  @override
  State<LocalDouyinApp> createState() => _LocalDouyinAppState();
}

class _LocalDouyinAppState extends State<LocalDouyinApp> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    FolderScreen(),
    DiscoverScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => VideoProvider()..loadVideos()),
        ChangeNotifierProvider(create: (_) => FolderProvider()..loadFolders()),
        ChangeNotifierProvider(create: (_) => PlayerProvider()),
        ChangeNotifierProvider(create: (_) => CommentProvider()),
      ],
      child: MaterialApp(
        title: '本地抖音',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: _buildMainScaffold(),
      ),
    );
  }

  Widget _buildMainScaffold() {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          border: Border(top: BorderSide(color: Color(0xFF2A2A2A), width: 0.5)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home,
                  label: '首页',
                  isActive: _currentIndex == 0,
                  onTap: () => setState(() => _currentIndex = 0),
                ),
                _NavItem(
                  icon: Icons.folder_outlined,
                  activeIcon: Icons.folder,
                  label: '文件夹',
                  isActive: _currentIndex == 1,
                  onTap: () => setState(() => _currentIndex = 1),
                ),
                // 中间的+按钮
                GestureDetector(
                  onTap: () {
                    // 切换到文件夹页面添加
                    setState(() => _currentIndex = 1);
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF5DE61D), Color(0xFF1DC8E6)],
                      ),
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 28),
                  ),
                ),
                _NavItem(
                  icon: Icons.explore_outlined,
                  activeIcon: Icons.explore,
                  label: '发现',
                  isActive: _currentIndex == 2,
                  onTap: () => setState(() => _currentIndex = 2),
                ),
                _NavItem(
                  icon: Icons.person_outlined,
                  activeIcon: Icons.person,
                  label: '我的',
                  isActive: _currentIndex == 3,
                  onTap: () => setState(() => _currentIndex = 3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              color: isActive ? Colors.white : Colors.white54,
              size: 24,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.white54,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
