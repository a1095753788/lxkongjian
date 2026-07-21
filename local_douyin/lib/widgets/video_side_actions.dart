import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/comment_item.dart';
import '../models/video_item.dart';
import '../providers/video_provider.dart';
import '../providers/player_provider.dart';
import '../providers/comment_provider.dart';
import '../theme/app_theme.dart';
import 'comment_input_sheet.dart';
import 'danmaku_overlay.dart';

class VideoSideActions extends StatelessWidget {
  final VideoItem video;

  const VideoSideActions({super.key, required this.video});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 10,
      bottom: 160,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 删除（最上方，白色）
          _SideActionButton(
            icon: Icons.delete_outline,
            label: '',
            onTap: () => _showDeleteConfirm(context),
          ),
          const SizedBox(height: 22),
          // 不感兴趣
          _SideActionButton(
            icon: Icons.close,
            label: video.isNotInterested ? '已屏蔽' : '',
            color: video.isNotInterested ? const Color(0xFF9CA3AF) : Colors.white,
            onTap: () => _toggleNotInterested(context),
          ),
          const SizedBox(height: 22),
          // 点赞
          _SideActionButton(
            icon: video.isLiked ? Icons.favorite : Icons.favorite_border,
            label: '${video.likeCount}',
            color: video.isLiked ? AppTheme.primaryColor : Colors.white,
            onTap: () => context.read<VideoProvider>().toggleLike(video.id),
          ),
          const SizedBox(height: 22),
          // 评论
          Consumer<CommentProvider>(
            builder: (context, cp, _) {
              final count = cp.countOf(video.id);
              return _SideActionButton(
                icon: Icons.mode_comment_outlined,
                label: '$count',
                onTap: () => _openCommentSheet(context),
              );
            },
          ),
          const SizedBox(height: 22),
          // 收藏
          _SideActionButton(
            icon: video.isFavorited ? Icons.star : Icons.star_border,
            label: video.isFavorited ? '已收藏' : '收藏',
            color: video.isFavorited ? const Color(0xFFFFB800) : Colors.white,
            onTap: () => context.read<VideoProvider>().toggleFavorite(video.id),
          ),
          const SizedBox(height: 22),
          // 倍速
          const _SpeedButton(),
        ],
      ),
    );
  }

  Future<void> _openCommentSheet(BuildContext context) async {
    final cp = context.read<CommentProvider>();
    await cp.setCurrentVideo(video.id);
    if (!context.mounted) return;
    final newComment = await CommentInputSheet.show(context, video);
    if (newComment != null) {
      DanmakuOverlay.addLiveComment(context, newComment);
    }
  }

  void _toggleNotInterested(BuildContext context) async {
    await context.read<VideoProvider>().toggleNotInterested(video.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(video.isNotInterested ? '已取消不感兴趣' : '已标记为不感兴趣'),
        duration: const Duration(milliseconds: 1500),
      ),
    );
  }

  void _showDeleteConfirm(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          '删除视频',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Text(
              '确定要删除 "${video.displayName}" 吗？',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 8),
            const Text(
              '删除后将从本地文件系统中移除，无法恢复',
              style: TextStyle(color: Colors.white38, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              '取消',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<VideoProvider>().deleteVideo(video.id, deleteFile: true);
            },
            child: const Text(
              '删除',
              style: TextStyle(color: Color(0xFFFF4757), fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// 统一的侧边操作按钮样式
///
/// - 无黑色圆形背景（去掉阴影感）
/// - 图标统一 28dp
/// - 文字统一 12sp、白色、中等字重
/// - 图标和文字居中对齐
class _SideActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SideActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 28),
          if (label.isNotEmpty) ...[
            const SizedBox(height: 4),
            SizedBox(
              width: 50,
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SpeedButton extends StatelessWidget {
  const _SpeedButton();

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (context, player, _) {
        final speed = player.playbackSpeed;
        return GestureDetector(
          onTap: () => _showSpeedDialog(context, player),
          behavior: HitTestBehavior.opaque,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.speed, color: Colors.white, size: 28),
              const SizedBox(height: 4),
              Text(
                '${speed}x',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSpeedDialog(BuildContext context, PlayerProvider player) {
    final speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  '播放速度',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: speeds.map((s) {
                  final isSelected = s == player.playbackSpeed;
                  return GestureDetector(
                    onTap: () {
                      player.setPlaybackSpeed(s);
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.primaryColor : const Color(0xFF2A2A2A),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${s}x',
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}
