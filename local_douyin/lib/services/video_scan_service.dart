import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import '../models/video_item.dart';
import '../models/folder_item.dart';
import '../utils/constants.dart';
import 'database_service.dart';

/// 判断一个视频路径是否是网络 URL。
///
/// 本地视频与网络视频共用同一张 videos 表，靠 path 前缀区分，
/// 不引入新字段、不升 dbVersion，保证已有的收藏/进度/推荐数据不受影响。
bool isNetworkVideoPath(String path) =>
    path.startsWith('http://') || path.startsWith('https://');

/// 服务端 JSON 中的单条视频记录。
class NetworkVideoEntry {
  final String url;
  final String name;
  final int size;
  final String folder;
  final int mtime;

  NetworkVideoEntry({
    required this.url,
    required this.name,
    required this.size,
    required this.folder,
    required this.mtime,
  });
}

/// 服务端 /api/videos.json 的解析结果。
class NetworkSourceData {
  final String server;
  final List<NetworkVideoEntry> videos;

  NetworkSourceData({required this.server, required this.videos});
}

/// 解析服务端清单，格式错误时抛出带中文信息的 [FormatException]。
///
/// 抽成顶层纯函数，便于在不依赖 Flutter/数据库的环境下测试。
NetworkSourceData parseNetworkVideosJson(String body) {
  dynamic decoded;
  try {
    decoded = jsonDecode(body);
  } catch (e) {
    throw FormatException('不是合法的 JSON: $e');
  }
  if (decoded is! Map<String, dynamic>) {
    throw FormatException('JSON 根节点必须是对象');
  }

  final serverValue = decoded['server'];
  if (serverValue is! String || serverValue.trim().isEmpty) {
    throw FormatException('缺少 server 字段或格式不正确');
  }

  final videosValue = decoded['videos'];
  if (videosValue is! List) {
    throw FormatException('缺少 videos 数组或格式不正确');
  }

  final videos = <NetworkVideoEntry>[];
  for (var i = 0; i < videosValue.length; i++) {
    final item = videosValue[i];
    if (item is! Map<String, dynamic>) {
      throw FormatException('videos[$i] 不是对象');
    }
    final url = item['url'];
    final name = item['name'];
    final folder = item['folder'];
    if (url is! String || url.isEmpty) {
      throw FormatException('videos[$i].url 缺失或格式不正确');
    }
    if (name is! String || name.isEmpty) {
      throw FormatException('videos[$i].name 缺失或格式不正确');
    }
    if (folder is! String || folder.isEmpty) {
      throw FormatException('videos[$i].folder 缺失或格式不正确');
    }
    final size = item['size'];
    final mtime = item['mtime'];
    videos.add(NetworkVideoEntry(
      url: url,
      name: name,
      size: size is int ? size : (size is num ? size.toInt() : 0),
      folder: folder,
      mtime: mtime is int ? mtime : (mtime is num ? mtime.toInt() : 0),
    ));
  }

  return NetworkSourceData(server: serverValue.trim(), videos: videos);
}

/// 按 folder 字段分组，保持各组中视频的原有顺序。
Map<String, List<NetworkVideoEntry>> groupNetworkVideosByFolder(
  List<NetworkVideoEntry> videos,
) {
  final groups = <String, List<NetworkVideoEntry>>{};
  for (final video in videos) {
    groups.putIfAbsent(video.folder, () => []).add(video);
  }
  return groups;
}

/// 从网络文件夹的 path 中还原 server 与相对目录。
///
/// 网络文件夹的 path 形如 `http://host:port/m/1630621300/video`。
({String server, String folder})? parseNetworkFolderPath(String path) {
  const marker = '/m/';
  final index = path.indexOf(marker);
  if (index <= 0) return null;
  final server = path.substring(0, index);
  final folder = path.substring(index + marker.length);
  if (server.isEmpty || folder.isEmpty) return null;
  return (server: server, folder: folder);
}

class _NetworkImportResult {
  final FolderItem folder;
  final List<VideoItem> videos;

  _NetworkImportResult({required this.folder, required this.videos});
}

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

  /// 新增网络视频源：拉取清单、按 folder 建文件夹并入库，返回第一个文件夹。
  Future<FolderItem> addNetworkSource(String serverUrl) async {
    final result = await _importNetworkSource(serverUrl);
    return result.folder;
  }

  /// 重新扫描单个网络源文件夹。本地文件逻辑不会走到这里。
  Future<List<VideoItem>> refreshNetworkSource(FolderItem folder) async {
    final meta = parseNetworkFolderPath(folder.path);
    if (meta == null) {
      throw Exception('不是有效的网络视频源: ${folder.name}');
    }
    final result = await _importNetworkSource(meta.server, onlyFolder: meta.folder);
    return result.videos;
  }

  Future<_NetworkImportResult> _importNetworkSource(
    String serverUrl, {
    String? onlyFolder,
  }) async {
    final baseUrl = _normalizeServerUrl(serverUrl);
    final uri = Uri.tryParse('$baseUrl/api/videos.json');
    if (baseUrl.isEmpty ||
        uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      throw Exception('服务器地址无效，请输入以 http:// 或 https:// 开头的地址');
    }

    // 用 dart:io 自带的 HttpClient，不引入第三方 http 包，
    // 避免新增依赖影响现有打包流程和原生库版本。
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    late final int statusCode;
    late final String responseBody;
    try {
      final request = await client.getUrl(uri);
      final response = await request.close().timeout(const Duration(seconds: 15));
      statusCode = response.statusCode;
      responseBody = await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw Exception('连接服务器超时 $baseUrl，请检查地址和网络');
    } catch (e) {
      throw Exception('无法连接服务器 $baseUrl，请检查地址和网络: $e');
    } finally {
      client.close(force: true);
    }
    if (statusCode != 200) {
      throw Exception('服务器返回错误码 $statusCode');
    }

    NetworkSourceData data;
    try {
      data = parseNetworkVideosJson(responseBody);
    } on FormatException catch (e) {
      throw Exception('服务器返回的数据格式不正确: ${e.message}');
    }

    // 以服务端返回的 server 为准拼接媒体 URL；缺省时退回用户输入的地址。
    final server = _normalizeServerUrl(data.server.isEmpty ? baseUrl : data.server);
    final groups = groupNetworkVideosByFolder(data.videos);
    if (groups.isEmpty) {
      throw Exception('服务器返回的视频列表为空');
    }

    final importedFolders = <FolderItem>[];
    for (final group in groups.entries) {
      if (onlyFolder != null && group.key != onlyFolder) continue;

      final folderId = 'net|$server|${group.key}';
      final folderPath = '$server/m/${group.key}';
      final folderName = group.key.split(RegExp(r'[/\\]')).last;

      // 刷新时先按 folder 清掉旧记录再插入，保证服务端已删除的视频不残留。
      // 同时暂存旧记录，把收藏/进度等用户数据带到新记录上，避免刷新丢数据。
      final oldVideos = await _dbService.getVideosByFolder(folderId);
      final oldById = <String, VideoItem>{for (final v in oldVideos) v.id: v};
      final existingFolder = await _dbService.getFolderById(folderId);
      if (existingFolder != null) {
        await _dbService.deleteVideosByFolder(folderId);
      }

      var folder = FolderItem(
        id: folderId,
        path: folderPath,
        name: folderName,
        lastScannedAt: DateTime.now(),
      );
      if (existingFolder != null) {
        folder = existingFolder.copyWith(
          path: folderPath,
          name: folderName,
          lastScannedAt: DateTime.now(),
        );
      } else {
        await _dbService.insertFolder(folder);
      }

      for (final entry in group.value) {
        final old = oldById[entry.url];
        final video = VideoItem(
          id: entry.url,
          path: entry.url,
          name: entry.name,
          folderId: folderId,
          fileSize: entry.size,
          duration: old?.duration,
          width: old?.width ?? 0,
          height: old?.height ?? 0,
          thumbnailPath: null,
          addedAt: old?.addedAt ??
              DateTime.fromMillisecondsSinceEpoch(entry.mtime * 1000),
          lastPlayedAt: old?.lastPlayedAt,
          playCount: old?.playCount ?? 0,
          likeCount: old?.likeCount ?? 0,
          isLiked: old?.isLiked ?? false,
          isFavorited: old?.isFavorited ?? false,
          isNotInterested: old?.isNotInterested ?? false,
          watchProgress: old?.watchProgress ?? 0.0,
        );
        await _dbService.insertVideo(video);
      }

      await _dbService.updateVideoCount(folderId);
      folder = folder.copyWith(videoCount: group.value.length);
      await _dbService.updateFolder(folder);
      importedFolders.add(folder);
    }

    if (importedFolders.isEmpty) {
      throw Exception('服务器清单中没有找到该视频源: $onlyFolder');
    }

    // 刷新单个文件夹时返回它自己；新增时返回第一个文件夹。
    final targetFolder = importedFolders.first;
    final targetVideos = await _dbService.getVideosByFolder(targetFolder.id);
    return _NetworkImportResult(folder: targetFolder, videos: targetVideos);
  }

  String _normalizeServerUrl(String url) {
    var normalized = url.trim();
    while (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }

  Future<List<VideoItem>> scanFolder(String folderId) async {
    final folder = await _dbService.getFolderById(folderId);
    if (folder == null) throw Exception('文件夹不存在');

    // 网络视频源走 HTTP 刷新，不碰本地目录与存储权限。
    if (isNetworkVideoPath(folder.path)) {
      return await refreshNetworkSource(folder);
    }

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
      // 网络视频的 path 是 URL，不是本地文件，不能按"文件丢失"清理。
      if (isNetworkVideoPath(video.path)) continue;
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
    // video_thumbnail 只支持本地文件，网络视频保持 thumbnailPath 为 null。
    if (isNetworkVideoPath(videoPath)) return null;
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

    // 删除缩略图文件
    await _deleteThumbnail(video.thumbnailPath);

    await _dbService.deleteVideo(videoId);
    await _dbService.updateVideoCount(video.folderId);
  }

  /// 请求服务器删除一条网络视频（服务端会把它移到自己的回收站）。
  /// 失败时抛异常，调用方据此保留本地记录，避免「记录没了、文件还在」。
  Future<void> deleteNetworkFile(String url) async {
    final parsed = Uri.tryParse(url);
    if (parsed == null || parsed.host.isEmpty) {
      throw Exception('视频地址无效，无法删除');
    }
    final target = Uri(
      scheme: parsed.scheme,
      host: parsed.host,
      port: parsed.hasPort ? parsed.port : null,
      path: '/api/delete',
    );

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.postUrl(target);
      request.headers.contentType = ContentType.json;
      request.add(utf8.encode(jsonEncode(<String, String>{'url': url})));
      final response =
          await request.close().timeout(const Duration(seconds: 20));
      final text = await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        var message = '服务器返回 HTTP ${response.statusCode}';
        try {
          final decoded = jsonDecode(text);
          if (decoded is Map && decoded['error'] is String) {
            message = decoded['error'] as String;
          }
        } catch (_) {}
        throw Exception(message);
      }
    } on TimeoutException {
      throw Exception('删除超时，服务器没有响应');
    } finally {
      client.close(force: true);
    }
  }

  Future<void> deleteVideoWithFile(String videoId) async {
    final video = await _dbService.getVideoById(videoId);
    if (video == null) return;

    if (isNetworkVideoPath(video.path)) {
      // 网络视频：请求服务器删除（服务端会移入自己的回收站）。
      // 失败直接抛出，本地记录保持不动。
      await deleteNetworkFile(video.path);
    } else {
      final file = File(video.path);
      if (await file.exists()) {
        await file.delete();
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
        if (isNetworkVideoPath(video.path)) {
          // 网络视频没有本地文件可删，只移除数据库记录。
          await _dbService.deleteVideo(video.id);
        } else {
          await deleteVideoWithFile(video.id);
        }
      }
    }

    await _dbService.deleteFolder(folderId);
  }
}
