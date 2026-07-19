import 'package:flutter/material.dart';
import '../models/folder_item.dart';
import '../theme/app_theme.dart';

class FolderListItem extends StatelessWidget {
  final FolderItem folder;
  final VoidCallback onTap;
  final VoidCallback onScan;
  final VoidCallback onDelete;
  final VoidCallback onToggleAutoScan;

  const FolderListItem({
    super.key,
    required this.folder,
    required this.onTap,
    required this.onScan,
    required this.onDelete,
    required this.onToggleAutoScan,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.folder,
                        color: AppTheme.primaryColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            folder.displayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            folder.path,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.white54),
                      color: const Color(0xFF2A2A2A),
                      onSelected: (value) {
                        switch (value) {
                          case 'scan':
                            onScan();
                            break;
                          case 'delete':
                            onDelete();
                            break;
                          case 'auto_scan':
                            onToggleAutoScan();
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'scan',
                          child: Row(
                            children: [
                              Icon(Icons.refresh, color: Colors.white70, size: 20),
                              SizedBox(width: 8),
                              Text('重新扫描', style: TextStyle(color: Colors.white)),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'auto_scan',
                          child: Row(
                            children: [
                              Icon(
                                folder.autoScan ? Icons.check_box : Icons.check_box_outline_blank,
                                color: Colors.white70,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              const Text('自动扫描', style: TextStyle(color: Colors.white)),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline, color: Color(0xFFFE2C55), size: 20),
                              SizedBox(width: 8),
                              Text('删除', style: TextStyle(color: Color(0xFFFE2C55))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _InfoChip(
                      icon: Icons.videocam_outlined,
                      label: '${folder.videoCount} 个视频',
                    ),
                    const SizedBox(width: 16),
                    _InfoChip(
                      icon: Icons.access_time,
                      label: _formatDate(folder.lastScannedAt),
                    ),
                    const Spacer(),
                    if (folder.autoScan)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '自动',
                          style: TextStyle(color: Colors.green, fontSize: 11),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return '${date.month}/${date.day}';
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white38, size: 14),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ],
    );
  }
}
