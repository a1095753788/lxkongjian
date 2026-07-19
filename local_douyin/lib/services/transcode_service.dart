import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:video_compress/video_compress.dart';
import '../models/video_item.dart';
import '../utils/constants.dart';
import 'database_service.dart';

/// 转码服务
///
/// 基于 video_compress 实现，使用 Android MediaCodec / iOS AVFoundation
/// 原生转码，不依赖 FFmpeg。
class TranscodeService {
  final DatabaseService _dbService = DatabaseService();
  // video_compress 的 Subscription 类型（非 dart:async 的 StreamSubscription）
  Subscription? _progressSubscription;
  bool _isCanceling = false;

  /// 转码视频
  ///
  /// [targetWidth] 用于选择目标分辨率：
  ///   - <= 640  → 640x480
  ///   - <= 960  → 960x540
  ///   - <= 1280 → 1280x720
  ///   - <= 1920 → 1920x1080
  ///   - 其他    → DefaultQuality
  /// [crf] 不可用（保留接口兼容），改用 [quality] 等级
  Future<bool> transcodeVideo(
    VideoItem video, {
    int? targetWidth,
    int? crf,
    Function(double)? onProgress,
  }) async {
    return _compress(
      video,
      quality: _mapWidthToQuality(targetWidth),
      onProgress: onProgress,
    );
  }

  /// 压缩视频（默认分辨率）
  Future<bool> compressVideo(
    VideoItem video, {
    Function(double)? onProgress,
  }) async {
    return _compress(
      video,
      quality: VideoQuality.DefaultQuality,
      onProgress: onProgress,
    );
  }

  /// 转换为 MP4（保留原分辨率，仅重封装/重编码为 H.264 + AAC）
  Future<bool> convertToMp4(
    VideoItem video, {
    Function(double)? onProgress,
  }) async {
    // 若已经是 mp4 则用默认质量压缩一次（重编码）
    return _compress(
      video,
      quality: VideoQuality.DefaultQuality,
      onProgress: onProgress,
    );
  }

  Future<bool> _compress(
    VideoItem video, {
    required VideoQuality quality,
    Function(double)? onProgress,
  }) async {
    final sourceFile = File(video.path);
    if (!await sourceFile.exists()) {
      return false;
    }

    _isCanceling = false;

    // 订阅进度
    if (onProgress != null) {
      _progressSubscription = VideoCompress.compressProgress$.subscribe((progress) {
        if (!_isCanceling) {
          onProgress(progress);
        }
      });
    }

    try {
      final mediaInfo = await VideoCompress.compressVideo(
        video.path,
        quality: quality,
        deleteOrigin: false, // 保留原文件
        includeAudio: true,
      );

      if (mediaInfo == null || mediaInfo.path == null) {
        return false;
      }

      // 将转码后的文件从 cache 移动到应用文档目录（持久化，避免被系统清理）
      final transcodedFile = File(mediaInfo.path!);
      if (!await transcodedFile.exists()) {
        return false;
      }

      final persistentDir = await _getTranscodeDir();
      final baseName = video.name.replaceAll(RegExp(r'\.[^.]+$'), '');
      final persistentPath =
          '${persistentDir.path}/${baseName}_${DateTime.now().millisecondsSinceEpoch}.${AppConstants.transcodeOutputFormat}';

      // 若已存在旧转码文件，先删除
      final oldTranscoded = video.transcodedPath;
      if (oldTranscoded != null) {
        final oldFile = File(oldTranscoded);
        if (await oldFile.exists()) {
          try {
            await oldFile.delete();
          } catch (_) {}
        }
      }

      // 复制到持久目录后删除 cache 中的文件
      await transcodedFile.copy(persistentPath);
      try {
        await transcodedFile.delete();
      } catch (_) {}
      // 清理 video_compress 在 cache 中产生的其他临时文件
      try {
        await VideoCompress.deleteAllCache();
      } catch (_) {}

      // 更新数据库
      final updatedVideo = video.copyWith(
        transcodedPath: persistentPath,
        isTranscoded: true,
      );
      await _dbService.updateVideo(updatedVideo);

      return true;
    } catch (e) {
      return false;
    } finally {
      // video_compress 的 Subscription 通过 unsubscribe 取消
      try {
        _progressSubscription?.unsubscribe();
      } catch (_) {}
      _progressSubscription = null;
    }
  }

  /// 取消正在进行的转码
  Future<void> cancelCompression() async {
    _isCanceling = true;
    try {
      await VideoCompress.cancelCompression();
    } catch (_) {}
  }

  VideoQuality _mapWidthToQuality(int? targetWidth) {
    if (targetWidth == null) return VideoQuality.DefaultQuality;
    if (targetWidth <= 640) return VideoQuality.Res640x480Quality;
    if (targetWidth <= 960) return VideoQuality.Res960x540Quality;
    if (targetWidth <= 1280) return VideoQuality.Res1280x720Quality;
    if (targetWidth <= 1920) return VideoQuality.Res1920x1080Quality;
    return VideoQuality.DefaultQuality;
  }

  Future<Directory> _getTranscodeDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/transcoded');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// 清理所有转码缓存文件（不影响数据库记录）
  Future<void> cleanTranscodedFiles() async {
    try {
      final dir = await _getTranscodeDir();
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        await dir.create(recursive: true);
      }
      // 同时清理 video_compress 的 cache
      await VideoCompress.deleteAllCache();
    } catch (_) {}
  }

  /// 删除单个视频的转码文件，并更新数据库
  Future<void> deleteTranscodedFile(VideoItem video) async {
    if (video.transcodedPath != null) {
      final file = File(video.transcodedPath!);
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }
      final updatedVideo = video.copyWith(
        transcodedPath: null,
        isTranscoded: false,
      );
      await _dbService.updateVideo(updatedVideo);
    }
  }

  /// 获取媒体信息（包含分辨率、时长、文件大小等）
  Future<Map<String, dynamic>?> getMediaInfo(String path) async {
    final file = File(path);
    if (!await file.exists()) return null;
    try {
      final info = await VideoCompress.getMediaInfo(path);
      return {
        'path': path,
        'title': info.title,
        'author': info.author,
        'duration': info.duration,
        'width': info.width,
        'height': info.height,
        'size': info.filesize,
        'orientation': info.orientation,
      };
    } catch (_) {
      // 失败时回退到文件 stat
      final stat = await file.stat();
      return {
        'path': path,
        'size': stat.size,
        'modified': stat.modified.toIso8601String(),
      };
    }
  }
}
