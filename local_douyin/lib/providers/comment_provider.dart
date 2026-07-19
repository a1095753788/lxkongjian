import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/comment_item.dart';
import '../services/database_service.dart';

class CommentProvider extends ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();
  final _uuid = const Uuid();

  // 按视频 id 缓存评论列表
  final Map<String, List<CommentItem>> _commentsByVideo = {};
  // 按视频 id 缓存评论数
  final Map<String, int> _countByVideo = {};
  // 当前激活的视频 id（用于决定弹幕与列表显示哪个视频的评论）
  String? _currentVideoId;

  List<CommentItem> get currentComments =>
      _currentVideoId == null ? [] : (_commentsByVideo[_currentVideoId] ?? []);
  int get currentCount =>
      _currentVideoId == null ? 0 : (_countByVideo[_currentVideoId] ?? 0);

  int countOf(String videoId) => _countByVideo[videoId] ?? 0;

  /// 切换当前视频，自动加载评论
  Future<void> setCurrentVideo(String videoId) async {
    if (_currentVideoId == videoId) return;
    _currentVideoId = videoId;
    if (!_commentsByVideo.containsKey(videoId)) {
      await loadComments(videoId);
    }
    notifyListeners();
  }

  void clearCurrentVideo() {
    _currentVideoId = null;
    notifyListeners();
  }

  Future<void> loadComments(String videoId) async {
    try {
      final list = await _dbService.getCommentsByVideo(videoId);
      final count = list.length;
      _commentsByVideo[videoId] = list;
      _countByVideo[videoId] = count;
      if (_currentVideoId == videoId) notifyListeners();
    } catch (e) {
      // 忽略加载失败
    }
  }

  Future<CommentItem?> addComment({
    required String videoId,
    required String content,
    String userName = '本地用户',
    int? videoTimestamp,
  }) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return null;
    final comment = CommentItem(
      id: _uuid.v4(),
      videoId: videoId,
      content: trimmed,
      userName: userName,
      videoTimestamp: videoTimestamp,
      createdAt: DateTime.now(),
    );
    try {
      await _dbService.insertComment(comment);
      final list = List<CommentItem>.from(_commentsByVideo[videoId] ?? []);
      list.add(comment);
      _commentsByVideo[videoId] = list;
      _countByVideo[videoId] = list.length;
      notifyListeners();
      return comment;
    } catch (e) {
      return null;
    }
  }

  Future<void> toggleLike(String videoId, String commentId) async {
    await _dbService.toggleCommentLike(commentId);
    final list = _commentsByVideo[videoId];
    if (list == null) return;
    final index = list.indexWhere((c) => c.id == commentId);
    if (index == -1) return;
    final old = list[index];
    list[index] = old.copyWith(
      isLiked: !old.isLiked,
      likeCount: old.isLiked ? old.likeCount - 1 : old.likeCount + 1,
    );
    notifyListeners();
  }

  Future<void> deleteComment(String videoId, String commentId) async {
    await _dbService.deleteComment(commentId);
    final list = _commentsByVideo[videoId];
    if (list == null) return;
    list.removeWhere((c) => c.id == commentId);
    _countByVideo[videoId] = list.length;
    notifyListeners();
  }
}
