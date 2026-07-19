import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../models/video_item.dart';
import '../models/folder_item.dart';
import '../models/comment_item.dart';
import '../utils/constants.dart';

class DatabaseService {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, AppConstants.dbName);

    return await openDatabase(
      path,
      version: AppConstants.dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE folders (
        id TEXT PRIMARY KEY,
        path TEXT NOT NULL,
        name TEXT NOT NULL,
        videoCount INTEGER DEFAULT 0,
        addedAt INTEGER NOT NULL,
        lastScannedAt INTEGER NOT NULL,
        autoScan INTEGER DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE videos (
        id TEXT PRIMARY KEY,
        path TEXT NOT NULL,
        name TEXT NOT NULL,
        folderId TEXT NOT NULL,
        fileSize INTEGER DEFAULT 0,
        duration INTEGER,
        width INTEGER DEFAULT 0,
        height INTEGER DEFAULT 0,
        thumbnailPath TEXT,
        addedAt INTEGER NOT NULL,
        lastPlayedAt INTEGER NOT NULL,
        playCount INTEGER DEFAULT 0,
        likeCount INTEGER DEFAULT 0,
        isLiked INTEGER DEFAULT 0,
        isFavorited INTEGER DEFAULT 0,
        watchProgress REAL DEFAULT 0.0,
        transcodedPath TEXT,
        isTranscoded INTEGER DEFAULT 0,
        FOREIGN KEY (folderId) REFERENCES folders (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('CREATE INDEX idx_videos_folderId ON videos(folderId)');
    await db.execute('CREATE INDEX idx_videos_playCount ON videos(playCount)');
    await db.execute('CREATE INDEX idx_videos_lastPlayedAt ON videos(lastPlayedAt)');

    await _createCommentsTable(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createCommentsTable(db);
    }
    if (oldVersion < 3) {
      try {
        await db.execute('ALTER TABLE videos ADD COLUMN isFavorited INTEGER DEFAULT 0');
      } catch (_) {}
    }
  }

  Future<void> _createCommentsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS comments (
        id TEXT PRIMARY KEY,
        videoId TEXT NOT NULL,
        content TEXT NOT NULL,
        userName TEXT NOT NULL,
        videoTimestamp INTEGER,
        createdAt INTEGER NOT NULL,
        likeCount INTEGER DEFAULT 0,
        isLiked INTEGER DEFAULT 0,
        FOREIGN KEY (videoId) REFERENCES videos (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_comments_videoId ON comments(videoId)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_comments_createdAt ON comments(createdAt)');
  }

  // Folder CRUD
  Future<String> insertFolder(FolderItem folder) async {
    final db = await database;
    await db.insert('folders', folder.toMap());
    return folder.id;
  }

  Future<List<FolderItem>> getAllFolders() async {
    final db = await database;
    final maps = await db.query('folders', orderBy: 'addedAt DESC');
    return maps.map((m) => FolderItem.fromMap(m)).toList();
  }

  Future<FolderItem?> getFolderById(String id) async {
    final db = await database;
    final maps = await db.query('folders', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return FolderItem.fromMap(maps.first);
  }

  Future<int> updateFolder(FolderItem folder) async {
    final db = await database;
    return await db.update('folders', folder.toMap(), where: 'id = ?', whereArgs: [folder.id]);
  }

  Future<int> deleteFolder(String id) async {
    final db = await database;
    await db.delete('videos', where: 'folderId = ?', whereArgs: [id]);
    return await db.delete('folders', where: 'id = ?', whereArgs: [id]);
  }

  // Video CRUD
  Future<String> insertVideo(VideoItem video) async {
    final db = await database;
    await db.insert('videos', video.toMap());
    return video.id;
  }

  Future<List<VideoItem>> getAllVideos() async {
    final db = await database;
    final maps = await db.query('videos', orderBy: 'lastPlayedAt DESC');
    return maps.map((m) => VideoItem.fromMap(m)).toList();
  }

  Future<List<VideoItem>> getVideosByFolder(String folderId) async {
    final db = await database;
    final maps = await db.query(
      'videos',
      where: 'folderId = ?',
      whereArgs: [folderId],
      orderBy: 'name ASC',
    );
    return maps.map((m) => VideoItem.fromMap(m)).toList();
  }

  Future<VideoItem?> getVideoById(String id) async {
    final db = await database;
    final maps = await db.query('videos', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return VideoItem.fromMap(maps.first);
  }

  Future<int> updateVideo(VideoItem video) async {
    final db = await database;
    return await db.update('videos', video.toMap(), where: 'id = ?', whereArgs: [video.id]);
  }

  Future<int> deleteVideo(String id) async {
    final db = await database;
    return await db.delete('videos', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteVideosByFolder(String folderId) async {
    final db = await database;
    return await db.delete('videos', where: 'folderId = ?', whereArgs: [folderId]);
  }

  Future<void> incrementPlayCount(String id) async {
    final db = await database;
    await db.rawUpdate(
      'UPDATE videos SET playCount = playCount + 1, lastPlayedAt = ? WHERE id = ?',
      [DateTime.now().millisecondsSinceEpoch, id],
    );
  }

  Future<void> toggleLike(String id) async {
    final db = await database;
    await db.rawUpdate(
      'UPDATE videos SET isLiked = CASE WHEN isLiked = 1 THEN 0 ELSE 1 END, likeCount = CASE WHEN isLiked = 1 THEN likeCount - 1 ELSE likeCount + 1 END WHERE id = ?',
      [id],
    );
  }

  Future<void> toggleFavorite(String id) async {
    final db = await database;
    await db.rawUpdate(
      'UPDATE videos SET isFavorited = CASE WHEN isFavorited = 1 THEN 0 ELSE 1 END WHERE id = ?',
      [id],
    );
  }

  Future<void> updateWatchProgress(String id, double progress) async {
    final db = await database;
    await db.update(
      'videos',
      {'watchProgress': progress},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateVideoCount(String folderId) async {
    final db = await database;
    final count = (await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM videos WHERE folderId = ?',
      [folderId],
    )).first['cnt'] as int;
    await db.update(
      'folders',
      {'videoCount': count},
      where: 'id = ?',
      whereArgs: [folderId],
    );
  }

  // Comment CRUD
  Future<String> insertComment(CommentItem comment) async {
    final db = await database;
    await db.insert('comments', comment.toMap());
    return comment.id;
  }

  Future<List<CommentItem>> getCommentsByVideo(String videoId, {int? limit}) async {
    final db = await database;
    final maps = await db.query(
      'comments',
      where: 'videoId = ?',
      whereArgs: [videoId],
      orderBy: 'createdAt ASC',
      limit: limit,
    );
    return maps.map((m) => CommentItem.fromMap(m)).toList();
  }

  Future<int> getCommentCount(String videoId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM comments WHERE videoId = ?',
      [videoId],
    );
    return (result.first['cnt'] as int?) ?? 0;
  }

  Future<void> toggleCommentLike(String id) async {
    final db = await database;
    await db.rawUpdate(
      'UPDATE comments SET isLiked = CASE WHEN isLiked = 1 THEN 0 ELSE 1 END, likeCount = CASE WHEN isLiked = 1 THEN likeCount - 1 ELSE likeCount + 1 END WHERE id = ?',
      [id],
    );
  }

  Future<int> deleteComment(String id) async {
    final db = await database;
    return await db.delete('comments', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteCommentsByVideo(String videoId) async {
    final db = await database;
    return await db.delete('comments', where: 'videoId = ?', whereArgs: [videoId]);
  }
}
