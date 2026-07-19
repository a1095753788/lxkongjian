import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import '../models/video_item.dart';
import '../models/folder_item.dart';
import '../utils/constants.dart';
import 'database_service.dart';

class VideoScanService {
  final DatabaseService _dbService = DatabaseService();
  final _uuid = const Uuid();

  Future<FolderItem> addFolder(String folderPath) async {
    final dir = Directory(folderPath);
    if (!await dir.exists()) {
      throw Exception('文件夹不存在: $folderPath');
    }

    final folderName = folderPath.split(RegExp(r'[/\\]')).last;
    final folder = FolderItem(
      id: _uuid.v4(),
      path: folderPath,
      name: folderName,
    );

    await _dbService.insertFolder(folder);
    return folder;
  }

  Future<List<VideoItem>> scanFolder(String folderId) async {
    final folder = await _dbService.getFolderById(folderId);
    if (folder == null) throw Exception('文件夹不存在');

    // 确保存储权限
    await _ensureStoragePermission();

    final dir = Directory(folder.path);
    if (!await dir.exists()) {
      throw Exception('文件夹路径不存在: ${folder.path}');
    }

    final existingVideos = await _dbService.getVideosByFolder(folderId);
    final existingPaths = existingVideos.map((v) => v.path).toSet();

    final newVideos = <VideoItem>[];

    try {
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          final extension = _getExtension(entity.path);
          if (AppConstants.supportedVideoExtensions.contains(extension.toLowerCase())) {
            if (!existingPaths.contains(entity.path)) {
              final video = await _createVideoItem(entity, folderId);
              newVideos.add(video);
              await _dbService.insertVideo(video);
            }
          }
        }
      }
    } catch (e) {
      // 权限不足时 list 可能抛异常，尝试用 listSync
      try {
        for (final entity in dir.listSync(recursive: true)) {
          if (entity is File) {
            final extension = _getExtension(entity.path);
            if (AppConstants.supportedVideoExtensions.contains(extension.toLowerCase())) {
              if (!existingPaths.contains(entity.path)) {
                final video = await _createVideoItem(entity, folderId);
                newVideos.add(video);
                await _dbService.insertVideo(video);
              }
            }
          }
        }
      } catch (e2) {
        throw Exception('无法读取文件夹内容，请检查存储权限: $e2');
      }
    }

    // 删除不存在的视频记录，并为缺少缩略图的现有视频补全缩略图
    for (final video in existingVideos) {
      final file = File(video.path);
      if (!await file.exists()) {
        await _dbService.deleteVideo(video.id);
        await _deleteThumbnail(video.thumbnailPath);
        continue;
      }
      // 若缩略图缺失或文件丢失，重新生成
      bool needThumbnail = video.thumbnailPath == null || video.thumbnailPath!.isEmpty;
      if (!needThumbnail) {
        final thumbFile = File(video.thumbnailPath!);
        if (!await thumbFile.exists()) {
          needThumbnail = true;
        }
      }
      if (needThumbnail) {
        final newThumb = await _generateThumbnail(video.path, video.id);
        if (newThumb != null) {
          await _dbService.updateVideo(video.copyWith(thumbnailPath: newThumb));
        }
      }
    }

    final updatedFolder = folder.copyWith(lastScannedAt: DateTime.now());
    await _dbService.updateFolder(updatedFolder);
    await _dbService.updateVideoCount(folderId);

    return newVideos;
  }

  Future<List<VideoItem>> scanAllFolders() async {
    final folders = await _dbService.getAllFolders();
    final allNewVideos = <VideoItem>[];

    for (final folder in folders) {
      if (folder.autoScan) {
        try {
          final newVideos = await scanFolder(folder.id);
          allNewVideos.addAll(newVideos);
        } catch (e) {
          continue;
        }
      }
    }

    return allNewVideos;
  }

  Future<VideoItem> _createVideoItem(File file, String folderId) async {
    final stat = await file.stat();
    final name = file.path.split(RegExp(r'[/\\]')).last;
    final videoId = _uuid.v4();

    // 生成缩略图并保存到应用文档目录（持久化，避免临时目录被清理）
    final thumbnailPath = await _generateThumbnail(file.path, videoId);

    return VideoItem(
      id: videoId,
      path: file.path,
      name: name,
      folderId: folderId,
      fileSize: stat.size,
      addedAt: DateTime.now(),
      thumbnailPath: thumbnailPath,
    );
  }

  Future<String?> _generateThumbnail(String videoPath, String videoId) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final thumbDir = Directory('${appDir.path}/thumbnails');
      if (!await thumbDir.exists()) {
        await thumbDir.create(recursive: true);
      }
      final thumbPath = await VideoThumbnail.thumbnailFile(
        video: videoPath,
        thumbnailPath: thumbDir.path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 480,
        quality: 75,
      );
      if (thumbPath != null) {
        // 重命名为以视频ID命名，避免冲突
        final renamedPath = '${thumbDir.path}/$videoId.jpg';
        final renamedFile = File(renamedPath);
        if (await renamedFile.exists()) {
          await renamedFile.delete();
        }
        await File(thumbPath).rename(renamedPath);
        return renamedPath;
      }
    } catch (e) {
      // 缩略图生成失败不阻塞扫描流程
    }
    return null;
  }

  Future<void> _deleteThumbnail(String? thumbnailPath) async {
    if (thumbnailPath == null) return;
    try {
      final file = File(thumbnailPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  String _getExtension(String path) {
    final dotIndex = path.lastIndexOf('.');
    if (dotIndex == -1) return '';
    return path.substring(dotIndex).toLowerCase();
  }

  Future<void> _ensureStoragePermission() async {
    // Android 13+ 需要细粒度媒体权限或 manageExternalStorage
    if (await Permission.manageExternalStorage.request().isGranted) return;
    if (await Permission.storage.request().isGranted) return;
    if (await Permission.videos.request().isGranted) return;
  }

  Future<void> deleteVideo(String videoId) async {
    final video = await _dbService.getVideoById(videoId);
    if (video == null) return;

    // 如果有转码文件，也删除
    if (video.transcodedPath != null) {
      final transcodedFile = File(video.transcodedPath!);
      if (await transcodedFile.exists()) {
        await transcodedFile.delete();
      }
    }

    // 删除缩略图文件
    await _deleteThumbnail(video.thumbnailPath);

    await _dbService.deleteVideo(videoId);
    await _dbService.updateVideoCount(video.folderId);
  }

  Future<void> deleteVideoWithFile(String videoId) async {
    final video = await _dbService.getVideoById(videoId);
    if (video == null) return;

    // 删除原始文件
    final file = File(video.path);
    if (await file.exists()) {
      await file.delete();
    }

    // 删除转码文件
    if (video.transcodedPath != null) {
      final transcodedFile = File(video.transcodedPath!);
      if (await transcodedFile.exists()) {
        await transcodedFile.delete();
      }
    }

    // 删除缩略图文件
    await _deleteThumbnail(video.thumbnailPath);

    await _dbService.deleteVideo(videoId);
    await _dbService.updateVideoCount(video.folderId);
  }

  Future<void> deleteFolder(String folderId, {bool deleteFiles = false}) async {
    final folder = await _dbService.getFolderById(folderId);
    if (folder == null) return;

    if (deleteFiles) {
      final videos = await _dbService.getVideosByFolder(folderId);
      for (final video in videos) {
        await deleteVideoWithFile(video.id);
      }
    }

    await _dbService.deleteFolder(folderId);
  }
}
