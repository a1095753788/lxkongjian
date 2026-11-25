import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/folder_provider.dart';
import '../providers/video_provider.dart';
import '../models/folder_item.dart';
import '../models/video_item.dart';
import '../widgets/folder_list_item.dart';
import '../theme/app_theme.dart';

class FolderScreen extends StatefulWidget {
  const FolderScreen({super.key});

  @override
  State<FolderScreen> createState() => _FolderScreenState();
}

class _FolderScreenState extends State<FolderScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FolderProvider>().loadFolders();
    });
  }

  Future<void> _addFolder() async {
    // 请求存储权限 - Android 13+ 需要 manageExternalStorage 或 videos 权限
    bool hasPermission = await Permission.manageExternalStorage.request().isGranted;
    if (!hasPermission) {
      hasPermission = await Permission.storage.request().isGranted;
    }
    if (!hasPermission) {
      hasPermission = await Permission.videos.request().isGranted;
    }
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('需要存储权限才能访问文件')),
        );
      }
      return;
    }

    try {
      final result = await FilePicker.getDirectoryPath(
        dialogTitle: '选择视频文件夹',
      );

      if (result != null && mounted) {
        await context.read<FolderProvider>().addFolder(result);
        // 同时刷新视频列表
        context.read<VideoProvider>().loadVideos();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('文件夹添加成功')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('添加文件夹失败: $e')),
        );
      }
    }
  }

  Future<void> _addNetworkSource() async {
    final controller = TextEditingController();
    late final String? input;
    try {
      input = await showDialog<String>(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1A1A1A),
            title: const Text('添加网络视频源', style: TextStyle(color: Colors.white)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '输入服务器地址，App 会读取 /api/videos.json 中的视频清单',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  autofocus: true,
                  keyboardType: TextInputType.url,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'http://192.168.31.41:8765',
                    hintStyle: TextStyle(color: Colors.white38),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: AppTheme.primaryColor),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, controller.text.trim()),
                child: const Text('添加'),
              ),
            ],
          );
        },
      );
    } finally {
      controller.dispose();
    }

    if (input == null || input.isEmpty || !mounted) return;

    try {
      await context.read<FolderProvider>().addNetworkSource(input);
      // 网络视频和普通视频共用同一张表，顺带刷新视频流。
      context.read<VideoProvider>().loadVideos();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('网络视频源添加成功')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('添加网络源失败: $e')),
        );
      }
    }
  }

  void _showFolderVideos(FolderItem folder) {
    final provider = context.read<FolderProvider>();
    final videos = provider.folderVideos[folder.id] ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          folder.displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white54),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: videos.isEmpty
                      ? const Center(
                          child: Text(
                            '该文件夹没有视频',
                            style: TextStyle(color: Colors.white38),
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: videos.length,
                          itemBuilder: (context, index) {
                            return _VideoListItem(video: videos[index]);
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDeleteFolder(FolderItem folder) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: const Text('删除文件夹', style: TextStyle(color: Colors.white)),
          content: Text(
            '确定要删除文件夹"${folder.displayName}"吗？',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _deleteFolder(folder, deleteFiles: false);
              },
              child: const Text('仅移除记录'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _deleteFolder(folder, deleteFiles: true);
              },
              child: const Text('同时删除文件', style: TextStyle(color: AppTheme.primaryColor)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteFolder(FolderItem folder, {required bool deleteFiles}) async {
    try {
      await context.read<FolderProvider>().deleteFolder(folder.id, deleteFiles: deleteFiles);
      context.read<VideoProvider>().loadVideos();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('文件夹已删除')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('文件夹管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<FolderProvider>().scanAllFolders(),
          ),
        ],
      ),
      body: Consumer<FolderProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            );
          }

          if (provider.folders.isEmpty) {
            return _buildEmptyState();
          }

          return RefreshIndicator(
            color: AppTheme.primaryColor,
            onRefresh: () => provider.scanAllFolders(),
            child: Stack(
              children: [
                ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 80),
                  itemCount: provider.folders.length,
                  itemBuilder: (context, index) {
                    final folder = provider.folders[index];
                    return FolderListItem(
                      folder: folder,
                      onTap: () => _showFolderVideos(folder),
                      onScan: () => provider.scanFolder(folder.id),
                      onDelete: () => _confirmDeleteFolder(folder),
                      onToggleAutoScan: () => provider.toggleAutoScan(folder.id),
                    );
                  },
                ),
                if (provider.isScanning)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      color: AppTheme.primaryColor.withOpacity(0.8),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                          SizedBox(width: 8),
                          Text('正在扫描...', style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'add_network_source',
            mini: true,
            onPressed: _addNetworkSource,
            backgroundColor: const Color(0xFF2A2A2A),
            tooltip: '添加网络源',
            child: const Icon(Icons.cloud_download_outlined, color: Colors.white),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'add_folder',
            onPressed: _addFolder,
            backgroundColor: AppTheme.primaryColor,
            tooltip: '添加本地文件夹',
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.folder_open_outlined, size: 80, color: Colors.white24),
          const SizedBox(height: 16),
          const Text('还没有添加文件夹', style: TextStyle(color: Colors.white54, fontSize: 18)),
          const SizedBox(height: 8),
          const Text('点击右下角按钮添加视频文件夹', style: TextStyle(color: Colors.white38, fontSize: 14)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _addFolder,
            icon: const Icon(Icons.folder_open),
            label: const Text('添加文件夹'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _addNetworkSource,
            icon: const Icon(Icons.cloud_download_outlined),
            label: const Text('添加网络视频源'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              side: const BorderSide(color: Colors.white24),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoListItem extends StatelessWidget {
  final VideoItem video;

  const _VideoListItem({required this.video});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.play_circle_fill, color: AppTheme.primaryColor, size: 28),
      ),
      title: Text(
        video.displayName,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Row(
        children: [
          Text(video.fileSizeFormatted, style: const TextStyle(color: Colors.white38, fontSize: 12)),
          const SizedBox(width: 8),
          if (video.duration != null)
            Text(
              _formatDuration(video.duration!),
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
        ],
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline, color: Colors.white38, size: 20),
        onPressed: () => _confirmDeleteVideo(context, video),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _confirmDeleteVideo(BuildContext context, VideoItem video) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: const Text('删除视频', style: TextStyle(color: Colors.white)),
          content: Text(
            '确定要删除"${video.displayName}"吗？',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                context.read<VideoProvider>().deleteVideo(video.id, deleteFile: false);
              },
              child: const Text('仅移除记录'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                context.read<VideoProvider>().deleteVideo(video.id, deleteFile: true);
              },
              child: const Text('删除文件', style: TextStyle(color: AppTheme.primaryColor)),
            ),
          ],
        );
      },
    );
  }
}
