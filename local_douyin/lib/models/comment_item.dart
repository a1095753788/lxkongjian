class CommentItem {
  final String id;
  final String videoId;
  final String content;
  final String userName;
  final int? videoTimestamp; // 评论时视频所处的毫秒位置
  final DateTime createdAt;
  final int likeCount;
  final bool isLiked;

  CommentItem({
    required this.id,
    required this.videoId,
    required this.content,
    required this.userName,
    this.videoTimestamp,
    required this.createdAt,
    this.likeCount = 0,
    this.isLiked = false,
  });

  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inSeconds < 60) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    if (diff.inDays < 30) return '${diff.inDays}天前';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}个月前';
    return '${(diff.inDays / 365).floor()}年前';
  }

  CommentItem copyWith({
    String? id,
    String? videoId,
    String? content,
    String? userName,
    int? videoTimestamp,
    DateTime? createdAt,
    int? likeCount,
    bool? isLiked,
  }) {
    return CommentItem(
      id: id ?? this.id,
      videoId: videoId ?? this.videoId,
      content: content ?? this.content,
      userName: userName ?? this.userName,
      videoTimestamp: videoTimestamp ?? this.videoTimestamp,
      createdAt: createdAt ?? this.createdAt,
      likeCount: likeCount ?? this.likeCount,
      isLiked: isLiked ?? this.isLiked,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'videoId': videoId,
      'content': content,
      'userName': userName,
      'videoTimestamp': videoTimestamp,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'likeCount': likeCount,
      'isLiked': isLiked ? 1 : 0,
    };
  }

  factory CommentItem.fromMap(Map<String, dynamic> map) {
    return CommentItem(
      id: map['id'] as String,
      videoId: map['videoId'] as String,
      content: map['content'] as String,
      userName: map['userName'] as String? ?? '本地用户',
      videoTimestamp: map['videoTimestamp'] as int?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      likeCount: map['likeCount'] as int? ?? 0,
      isLiked: (map['isLiked'] as int?) == 1,
    );
  }
}
