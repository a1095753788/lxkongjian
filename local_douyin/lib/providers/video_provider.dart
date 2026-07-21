import 'package:flutter/material.dart';
import '../models/video_item.dart';
import '../services/database_service.dart';
import '../services/video_scan_service.dart';
import '../services/recommendation_service.dart';
import '../services/transcode_service.dart';

class VideoProvider extends ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();
  final VideoScanService _scanService = VideoScanService();
  final RecommendationService _recommendationService = RecommendationService();
  final TranscodeService _transcodeService = TranscodeService();

  List<VideoItem> _videos = [];
  List<VideoItem> _recommendedVideos = [];
  VideoItem? _currentVideo;
  bool _isLoading = false;
  String? _error;

  List<VideoItem> get videos => _videos;
  List<VideoItem> get recommendedVideos => _recommendedVideos;
  VideoItem? get currentVideo => _currentVideo;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadVideos() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _videos = await _dbService.getAllVideos();
      _recommendedVideos = await _recommendationService.getRecommendedVideos();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadRecommendedVideos() async {
    try {
      _recommendedVideos = await _recommendationService.getRecommendedVideos();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// 追加更多推荐视频到列表末尾（用于无限下滑）
  /// 返回新增的视频数量（0 表示已无更多视频可推荐）
  Future<int> appendRecommendedVideos({int count = 100}) async {
    try {
      final more = await _recommendationService.getMoreRecommendedVideos(
        limit: count,
        existing: _recommendedVideos,
      );
      if (more.isEmpty) return 0;
      _recommendedVideos = [..._recommendedVideos, ...more];
      notifyListeners();
      return more.length;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return 0;
    }
  }

  void setCurrentVideo(VideoItem? video) {
    _currentVideo = video;
    notifyListeners();
  }

  Future<void> incrementPlayCount(String videoId) async {
    await _dbService.incrementPlayCount(videoId);
    final video = await _dbService.getVideoById(videoId);
    if (video != null) {
      final index = _videos.indexWhere((v) => v.id == videoId);
      if (index != -1) {
        _videos[index] = video;
      }
      if (_currentVideo?.id == videoId) {
        _currentVideo = video;
      }
      notifyListeners();
    }
  }

  Future<void> toggleLike(String videoId) async {
    await _dbService.toggleLike(videoId);
    final video = await _dbService.getVideoById(videoId);
    if (video != null) {
      final index = _videos.indexWhere((v) => v.id == videoId);
      if (index != -1) {
        _videos[index] = video;
      }
      final recIndex = _recommendedVideos.indexWhere((v) => v.id == videoId);
      if (recIndex != -1) {
        _recommendedVideos[recIndex] = video;
      }
      if (_currentVideo?.id == videoId) {
        _currentVideo = video;
      }
      notifyListeners();
    }
  }

  Future<void> toggleFavorite(String videoId) async {
    await _dbService.toggleFavorite(videoId);
    final video = await _dbService.getVideoById(videoId);
    if (video != null) {
      final index = _videos.indexWhere((v) => v.id == videoId);
      if (index != -1) {
        _videos[index] = video;
      }
      final recIndex = _recommendedVideos.indexWhere((v) => v.id == videoId);
      if (recIndex != -1) {
        _recommendedVideos[recIndex] = video;
      }
      if (_currentVideo?.id == videoId) {
        _currentVideo = video;
      }
      notifyListeners();
    }
  }

  Future<void> toggleNotInterested(String videoId) async {
    await _dbService.toggleNotInterested(videoId);
    final video = await _dbService.getVideoById(videoId);
    if (video != null) {
      final index = _videos.indexWhere((v) => v.id == videoId);
      if (index != -1) {
        _videos[index] = video;
      }
      final recIndex = _recommendedVideos.indexWhere((v) => v.id == videoId);
      if (recIndex != -1) {
        _recommendedVideos[recIndex] = video;
      }
      if (_currentVideo?.id == videoId) {
        _currentVideo = video;
      }
      notifyListeners();
    }
  }

  Future<void> resetAllNotInterested() async {
    await _dbService.resetAllNotInterested();
    await loadVideos();
  }

  Future<void> updateWatchProgress(String videoId, double progress) async {
    await _dbService.updateWatchProgress(videoId, progress);
  }

  Future<void> deleteVideo(String videoId, {bool deleteFile = false}) async {
    if (deleteFile) {
      await _scanService.deleteVideoWithFile(videoId);
    } else {
      await _scanService.deleteVideo(videoId);
    }
    _videos.removeWhere((v) => v.id == videoId);
    _recommendedVideos.removeWhere((v) => v.id == videoId);
    if (_currentVideo?.id == videoId) {
      _currentVideo = null;
    }
    notifyListeners();
  }

  Future<bool> transcodeVideo(
    VideoItem video, {
    int? targetWidth,
    int? crf,
    Function(double)? onProgress,
  }) async {
    try {
      final success = await _transcodeService.transcodeVideo(
        video,
        targetWidth: targetWidth,
        crf: crf,
        onProgress: onProgress,
      );
      if (success) {
        await loadVideos();
      }
      return success;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// 删除视频的转码文件
  Future<bool> deleteTranscodedFile(VideoItem video) async {
    try {
      await _transcodeService.deleteTranscodedFile(video);
      await loadVideos();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// 取消正在进行的转码
  Future<void> cancelTranscode() async {
    await _transcodeService.cancelCompression();
  }

  Future<List<VideoItem>> getFreshVideos() async {
    return await _recommendationService.getFreshVideos();
  }

  Future<List<VideoItem>> getLikedVideos() async {
    return await _recommendationService.getLikedVideos();
  }

  Future<List<VideoItem>> getFavoriteVideos() async {
    return await _recommendationService.getFavoriteVideos();
  }

  Future<List<VideoItem>> getMostPlayedVideos() async {
    return await _recommendationService.getMostPlayedVideos();
  }

  /// 清空推荐算法的会话内记忆（短期去重队列）
  /// 用于用户主动下拉刷新时，让所有视频重新参与推荐
  void clearRecommendationMemory() {
    _recommendationService.clearSessionMemory();
  }
}
