import 'dart:io';

class VideoItem {
  final String id;
  final String path;
  final String name;
  final String folderId;
  final int fileSize;
  final Duration? duration;
  final int width;
  final int height;
  final String? thumbnailPath;
  final DateTime addedAt;
  final DateTime lastPlayedAt;
  final int playCount;
  final int likeCount;
  final bool isLiked;
  final bool isFavorited;
  final bool isNotInterested;
  final double watchProgress;
  final String? transcodedPath;
  final bool isTranscoded;

  VideoItem({
    required this.id,
    required this.path,
    required this.name,
    required this.folderId,
    this.fileSize = 0,
    this.duration,
    this.width = 0,
    this.height = 0,
    this.thumbnailPath,
    required this.addedAt,
    DateTime? lastPlayedAt,
    this.playCount = 0,
    this.likeCount = 0,
    this.isLiked = false,
    this.isFavorited = false,
    this.isNotInterested = false,
    this.watchProgress = 0.0,
    this.transcodedPath,
    this.isTranscoded = false,
  }) : lastPlayedAt = lastPlayedAt ?? addedAt;

  String get displayName {
    return name.replaceAll(RegExp(r'\.[^.]+$'), '');
  }

  String get fileSizeFormatted {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    if (fileSize < 1024 * 1024 * 1024) {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(fileSize / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String get resolution => '${width}x$height';

  String get playPath => isTranscoded && transcodedPath != null ? transcodedPath! : path;

  VideoItem copyWith({
    String? id,
    String? path,
    String? name,
    String? folderId,
    int? fileSize,
    Duration? duration,
    int? width,
    int? height,
    String? thumbnailPath,
    DateTime? addedAt,
    DateTime? lastPlayedAt,
    int? playCount,
    int? likeCount,
    bool? isLiked,
    bool? isFavorited,
    bool? isNotInterested,
    double? watchProgress,
    String? transcodedPath,
    bool? isTranscoded,
  }) {
    return VideoItem(
      id: id ?? this.id,
      path: path ?? this.path,
      name: name ?? this.name,
      folderId: folderId ?? this.folderId,
      fileSize: fileSize ?? this.fileSize,
      duration: duration ?? this.duration,
      width: width ?? this.width,
      height: height ?? this.height,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      addedAt: addedAt ?? this.addedAt,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      playCount: playCount ?? this.playCount,
      likeCount: likeCount ?? this.likeCount,
      isLiked: isLiked ?? this.isLiked,
      isFavorited: isFavorited ?? this.isFavorited,
      isNotInterested: isNotInterested ?? this.isNotInterested,
      watchProgress: watchProgress ?? this.watchProgress,
      transcodedPath: transcodedPath ?? this.transcodedPath,
      isTranscoded: isTranscoded ?? this.isTranscoded,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'path': path,
      'name': name,
      'folderId': folderId,
      'fileSize': fileSize,
      'duration': duration?.inMilliseconds,
      'width': width,
      'height': height,
      'thumbnailPath': thumbnailPath,
      'addedAt': addedAt.millisecondsSinceEpoch,
      'lastPlayedAt': lastPlayedAt.millisecondsSinceEpoch,
      'playCount': playCount,
      'likeCount': likeCount,
      'isLiked': isLiked ? 1 : 0,
      'isFavorited': isFavorited ? 1 : 0,
      'isNotInterested': isNotInterested ? 1 : 0,
      'watchProgress': watchProgress,
      'transcodedPath': transcodedPath,
      'isTranscoded': isTranscoded ? 1 : 0,
    };
  }

  factory VideoItem.fromMap(Map<String, dynamic> map) {
    return VideoItem(
      id: map['id'] as String,
      path: map['path'] as String,
      name: map['name'] as String,
      folderId: map['folderId'] as String,
      fileSize: map['fileSize'] as int? ?? 0,
      duration: map['duration'] != null
          ? Duration(milliseconds: map['duration'] as int)
          : null,
      width: map['width'] as int? ?? 0,
      height: map['height'] as int? ?? 0,
      thumbnailPath: map['thumbnailPath'] as String?,
      addedAt: DateTime.fromMillisecondsSinceEpoch(map['addedAt'] as int),
      lastPlayedAt: DateTime.fromMillisecondsSinceEpoch(map['lastPlayedAt'] as int),
      playCount: map['playCount'] as int? ?? 0,
      likeCount: map['likeCount'] as int? ?? 0,
      isLiked: (map['isLiked'] as int?) == 1,
      isFavorited: (map['isFavorited'] as int?) == 1,
      isNotInterested: (map['isNotInterested'] as int?) == 1,
      watchProgress: (map['watchProgress'] as num?)?.toDouble() ?? 0.0,
      transcodedPath: map['transcodedPath'] as String?,
      isTranscoded: (map['isTranscoded'] as int?) == 1,
    );
  }
}
