import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/video_provider.dart';
import '../providers/folder_provider.dart';
import '../services/transcode_service.dart';
import '../theme/app_theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final videoProvider = context.watch<VideoProvider>();
    final folderProvider = context.watch<FolderProvider>();
    final totalVideos = videoProvider.videos.length;
    final totalFolders = folderProvider.folders.length;
    final likedVideos = videoProvider.videos.where((v) => v.isLiked).length;
    final favoriteVideos = videoProvider.videos.where((v) => v.isFavorited).length;
    final notInterestedVideos = videoProvider.videos.where((v) => v.isNotInterested).length;
    final totalPlayCount = videoProvider.videos.fold(0, (sum, v) => sum + v.playCount);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('我的')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          // 统计信息
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatItem(label: '视频', value: '$totalVideos'),
                    _StatItem(label: '喜欢', value: '$likedVideos'),
                    _StatItem(label: '收藏', value: '$favoriteVideos'),
                    _StatItem(label: '总播放', value: '$totalPlayCount'),
                  ],
                ),
                if (notInterestedVideos > 0) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.block, color: Colors.white38, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '已屏蔽 $notInterestedVideos 个不感兴趣视频',
                        style: const TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 功能列表
          _MenuSection(
            title: '视频管理',
            items: [
              _MenuItem(
                icon: Icons.cleaning_services_outlined,
                title: '清理转码缓存',
                subtitle: '清理视频转码产生的临时文件',
                onTap: () async {
                  final service = TranscodeService();
                  await service.cleanTranscodedFiles();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('转码缓存已清理')),
                    );
                  }
                },
              ),
              _MenuItem(
                icon: Icons.sync,
                title: '重新扫描所有文件夹',
                subtitle: '扫描所有已添加的文件夹',
                onTap: () async {
                  await context.read<FolderProvider>().scanAllFolders();
                  await context.read<VideoProvider>().loadVideos();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('扫描完成')),
                    );
                  }
                },
              ),
              _MenuItem(
                icon: Icons.refresh,
                title: '刷新推荐',
                subtitle: '重新生成推荐视频列表',
                onTap: () async {
                  context.read<VideoProvider>().clearRecommendationMemory();
                  await context.read<VideoProvider>().loadRecommendedVideos();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('推荐已刷新')),
                    );
                  }
                },
              ),
              _MenuItem(
                icon: Icons.block_flipped,
                title: '重置不感兴趣',
                subtitle: notInterestedVideos > 0
                    ? '恢复 $notInterestedVideos 个已屏蔽视频'
                    : '暂无已屏蔽视频',
                titleColor: notInterestedVideos > 0 ? Colors.white : Colors.white54,
                onTap: notInterestedVideos == 0
                    ? null
                    : () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: const Color(0xFF1A1A1A),
                            title: const Text(
                              '重置不感兴趣',
                              style: TextStyle(color: Colors.white, fontSize: 18),
                            ),
                            content: Text(
                              '确定恢复 $notInterestedVideos 个已屏蔽视频吗？\n它们将重新出现在推荐列表中。',
                              style: const TextStyle(color: Colors.white70, fontSize: 14),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('取消', style: TextStyle(color: Colors.white70)),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text(
                                  '确定',
                                  style: TextStyle(color: Color(0xFFFE2C55)),
                                ),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          await context.read<VideoProvider>().resetAllNotInterested();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('已重置所有不感兴趣标记')),
                            );
                          }
                        }
                      },
              ),
            ],
          ),
          const SizedBox(height: 16),

          _MenuSection(
            title: '设置',
            items: [
              _MenuItem(
                icon: Icons.info_outline,
                title: '关于',
                subtitle: '本地抖音 v1.0.0',
                onTap: () {
                  showAboutDialog(
                    context: context,
                    applicationName: '本地抖音',
                    applicationVersion: '1.0.0',
                    applicationIcon: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.play_circle_fill, color: Colors.white, size: 28),
                    ),
                    children: [
                      const Text('本地版抖音 - 播放本地视频的抖音风格应用'),
                    ],
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 13),
        ),
      ],
    );
  }
}

class _MenuSection extends StatelessWidget {
  final String title;
  final List<_MenuItem> items;

  const _MenuSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            title,
            style: const TextStyle(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
        ...items,
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? titleColor;
  final VoidCallback? onTap;

  const _MenuItem({
    required this.icon,
    required this.title,
    this.subtitle,
    this.titleColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return ListTile(
      leading: Icon(icon, color: enabled ? Colors.white70 : Colors.white38),
      title: Text(
        title,
        style: TextStyle(color: titleColor ?? (enabled ? Colors.white : Colors.white54)),
      ),
      subtitle: subtitle != null
          ? Text(subtitle!, style: const TextStyle(color: Colors.white38, fontSize: 12))
          : null,
      trailing: Icon(
        Icons.chevron_right,
        color: enabled ? Colors.white24 : Colors.white12,
      ),
      onTap: onTap,
    );
  }
}
