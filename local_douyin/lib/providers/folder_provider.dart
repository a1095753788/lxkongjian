import 'package:flutter/material.dart';
import '../models/folder_item.dart';
import '../models/video_item.dart';
import '../services/database_service.dart';
import '../services/video_scan_service.dart';

class FolderProvider extends ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();
  final VideoScanService _scanService = VideoScanService();

  List<FolderItem> _folders = [];
  Map<String, List<VideoItem>> _folderVideos = {};
  bool _isLoading = false;
  bool _isScanning = false;
  String? _error;

  List<FolderItem> get folders => _folders;
  Map<String, List<VideoItem>> get folderVideos => _folderVideos;
  bool get isLoading => _isLoading;
  bool get isScanning => _isScanning;
  String? get error => _error;

  Future<void> loadFolders() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _folders = await _dbService.getAllFolders();
      for (final folder in _folders) {
        _folderVideos[folder.id] = await _dbService.getVideosByFolder(folder.id);
      }
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<FolderItem> addFolder(String folderPath) async {
    try {
      final folder = await _scanService.addFolder(folderPath);
      _folders.insert(0, folder);
      _folderVideos[folder.id] = [];
      notifyListeners();

      // 自动扫描
      await scanFolder(folder.id);
      return folder;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<List<VideoItem>> scanFolder(String folderId) async {
    _isScanning = true;
    notifyListeners();

    try {
      final newVideos = await _scanService.scanFolder(folderId);
      _folderVideos[folderId] = await _dbService.getVideosByFolder(folderId);

      // 更新文件夹信息
      final index = _folders.indexWhere((f) => f.id == folderId);
      if (index != -1) {
        _folders[index] = (await _dbService.getFolderById(folderId))!;
      }

      _isScanning = false;
      notifyListeners();
      return newVideos;
    } catch (e) {
      _error = e.toString();
      _isScanning = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> scanAllFolders() async {
    _isScanning = true;
    notifyListeners();

    try {
      for (final folder in _folders) {
        if (folder.autoScan) {
          await _scanService.scanFolder(folder.id);
          _folderVideos[folder.id] = await _dbService.getVideosByFolder(folder.id);
        }
      }

      _folders = await _dbService.getAllFolders();
      _isScanning = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isScanning = false;
      notifyListeners();
    }
  }

  Future<void> deleteFolder(String folderId, {bool deleteFiles = false}) async {
    try {
      await _scanService.deleteFolder(folderId, deleteFiles: deleteFiles);
      _folders.removeWhere((f) => f.id == folderId);
      _folderVideos.remove(folderId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> toggleAutoScan(String folderId) async {
    final folder = await _dbService.getFolderById(folderId);
    if (folder == null) return;

    final updated = folder.copyWith(autoScan: !folder.autoScan);
    await _dbService.updateFolder(updated);

    final index = _folders.indexWhere((f) => f.id == folderId);
    if (index != -1) {
      _folders[index] = updated;
      notifyListeners();
    }
  }
}
