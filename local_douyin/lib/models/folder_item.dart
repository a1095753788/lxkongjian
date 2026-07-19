class FolderItem {
  final String id;
  final String path;
  final String name;
  final int videoCount;
  final DateTime addedAt;
  final DateTime lastScannedAt;
  final bool autoScan;

  FolderItem({
    required this.id,
    required this.path,
    required this.name,
    this.videoCount = 0,
    DateTime? addedAt,
    DateTime? lastScannedAt,
    this.autoScan = true,
  })  : addedAt = addedAt ?? DateTime.now(),
        lastScannedAt = lastScannedAt ?? DateTime.now();

  String get displayName {
    return name.split(RegExp(r'[/\\]')).last;
  }

  FolderItem copyWith({
    String? id,
    String? path,
    String? name,
    int? videoCount,
    DateTime? addedAt,
    DateTime? lastScannedAt,
    bool? autoScan,
  }) {
    return FolderItem(
      id: id ?? this.id,
      path: path ?? this.path,
      name: name ?? this.name,
      videoCount: videoCount ?? this.videoCount,
      addedAt: addedAt ?? this.addedAt,
      lastScannedAt: lastScannedAt ?? this.lastScannedAt,
      autoScan: autoScan ?? this.autoScan,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'path': path,
      'name': name,
      'videoCount': videoCount,
      'addedAt': addedAt.millisecondsSinceEpoch,
      'lastScannedAt': lastScannedAt.millisecondsSinceEpoch,
      'autoScan': autoScan ? 1 : 0,
    };
  }

  factory FolderItem.fromMap(Map<String, dynamic> map) {
    return FolderItem(
      id: map['id'] as String,
      path: map['path'] as String,
      name: map['name'] as String,
      videoCount: map['videoCount'] as int? ?? 0,
      addedAt: DateTime.fromMillisecondsSinceEpoch(map['addedAt'] as int),
      lastScannedAt: DateTime.fromMillisecondsSinceEpoch(map['lastScannedAt'] as int),
      autoScan: (map['autoScan'] as int?) == 1,
    );
  }
}
