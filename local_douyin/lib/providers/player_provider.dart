import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../models/video_item.dart';
import '../services/database_service.dart';

/// 基于 media_kit (libmpv/ffmpeg) 的播放器 Provider
///
/// 通过 `hwdec=no` 强制软解码，规避某些手机硬解码出现的
/// 绿色斜条纹、画面错位拉伸等 stride/pitch 兼容性问题。
///
/// 同时负责观看进度（watchProgress）的落库与恢复：
/// - 播放中每 [_persistInterval] 秒写一次数据库（节流，避免频繁 IO）
/// - 切换视频 / 停止 / 销毁前补一次，避免最后一段进度丢失
/// - 打开视频后按上次的进度 seek，实现断点续播
///
/// 这个字段不只是给续播用的：推荐算法的 Dwell Time 评分完全依赖它，
/// 不写库的话所有视频都会被当成"快速划走"，推荐会失去区分度。
class PlayerProvider extends ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();

  static const Duration _persistInterval = Duration(seconds: 5);

  /// 低于这个进度不值得续播（刚点开就划走的）
  static const double _resumeMinProgress = 0.02;

  /// 高于这个进度视为已看完，下次从头播
  static const double _resumeMaxProgress = 0.95;

  Player? _player;
  VideoController? _controller;
  VideoItem? _currentVideo;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _isMuted = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _playbackSpeed = 1.0;
  DateTime _lastPersistAt = DateTime.now();

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<bool>? _completedSub;

  Player? get player => _player;
  VideoController? get controller => _controller;
  VideoItem? get currentVideo => _currentVideo;
  bool get isInitialized => _isInitialized;
  bool get isPlaying => _isPlaying;
  bool get isMuted => _isMuted;
  Duration get position => _position;
  Duration get duration => _duration;
  double get playbackSpeed => _playbackSpeed;

  double get progress {
    if (_duration.inMilliseconds == 0) return 0.0;
    return _position.inMilliseconds / _duration.inMilliseconds;
  }

  Future<void> playVideo(VideoItem video) async {
    if (_currentVideo?.id == video.id && _player != null) {
      return;
    }

    // 切走前先把上一条的进度落库，否则最后几秒的观看记录会丢
    await _persistProgress();
    await _disposeController();

    _currentVideo = video;
    _isInitialized = false;
    _position = Duration.zero;
    _duration = Duration.zero;
    _lastPersistAt = DateTime.now();
    notifyListeners();

    try {
      _player = Player(
        configuration: const PlayerConfiguration(
          bufferSize: 64 * 1024 * 1024,
        ),
      );
      // 强制软解码，规避硬件解码绿屏/错位问题
      final native = _player!.platform;
      if (native is NativePlayer) {
        await native.setProperty('hwdec', 'no');
      }
      // 循环播放
      await _player!.setPlaylistMode(PlaylistMode.loop);

      _controller = VideoController(_player!);

      // 监听播放器流
      _positionSub = _player!.stream.position.listen((pos) {
        _position = pos;
        notifyListeners();
        _maybePersistProgress();
      });
      _durationSub = _player!.stream.duration.listen((dur) {
        _duration = dur;
        notifyListeners();
      });
      _playingSub = _player!.stream.playing.listen((playing) {
        _isPlaying = playing;
        notifyListeners();
      });
      _completedSub = _player!.stream.completed.listen((completed) {
        // PlaylistMode.loop 由底层处理，无需手动 replay
      });

      // 打开媒体文件
      final file = File(video.playPath);
      if (!await file.exists()) {
        _isInitialized = false;
        notifyListeners();
        return;
      }

      await _player!.open(Media(video.playPath));
      // 设置音量/速率
      await _player!.setVolume(_isMuted ? 0.0 : 100.0);
      await _player!.setRate(_playbackSpeed);

      // 断点续播：恢复到上次离开的位置（在 play() 之前 seek 才不会先闪一下开头）
      await _restoreProgress(video);

      _isInitialized = true;
      await _player!.play();
      _isPlaying = true;

      notifyListeners();
    } catch (e) {
      _isInitialized = false;
      notifyListeners();
    }
  }

  /// 按上次记录的进度 seek。
  ///
  /// 需要等 duration 可用才能算出目标位置，所以用 firstWhere 等待并加超时兜底；
  /// 拿不到 duration 就直接从头播，不影响正常播放。
  Future<void> _restoreProgress(VideoItem video) async {
    final saved = video.watchProgress;
    if (saved <= _resumeMinProgress || saved >= _resumeMaxProgress) return;

    // _durationSub 在 open() 之前就已订阅，_duration 字段会随流更新。
    // 这里轮询字段而不是等 stream 的下一个事件——duration 可能在
    // open() 后立刻发出，此时再订阅就错过了。
    final deadline = DateTime.now().add(const Duration(seconds: 3));
    while (_duration <= Duration.zero && DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(milliseconds: 50));
    }
    if (_duration <= Duration.zero) return;

    try {
      final target = Duration(
        milliseconds: (_duration.inMilliseconds * saved).round(),
      );
      await _player!.seek(target);
    } catch (_) {
      // seek 失败就从头播，不影响正常使用
    }
  }

  /// 节流版进度落库：position 流每秒会回调多次，不必每次都写库
  void _maybePersistProgress() {
    final now = DateTime.now();
    if (now.difference(_lastPersistAt) < _persistInterval) return;
    _lastPersistAt = now;
    _persistProgress();
  }

  /// 把当前进度写入数据库。
  ///
  /// 进度 >= 95% 统一记为 1.0：循环播放模式下 position 会绕回 0，
  /// 不这样处理会把"看完了"误判成"刚开始"。
  Future<void> _persistProgress() async {
    final video = _currentVideo;
    if (video == null) return;
    if (_duration.inMilliseconds <= 0) return;

    final ratio = _position.inMilliseconds / _duration.inMilliseconds;
    if (ratio.isNaN || ratio.isInfinite) return;

    final value =
        ratio >= _resumeMaxProgress ? 1.0 : ratio.clamp(0.0, 1.0).toDouble();
    try {
      await _dbService.updateWatchProgress(video.id, value);
    } catch (_) {
      // 写库失败不影响播放
    }
  }

  Future<void> togglePlay() async {
    if (_player == null) return;
    await _player!.playOrPause();
  }

  Future<void> toggleMute() async {
    _isMuted = !_isMuted;
    await _player?.setVolume(_isMuted ? 0.0 : 100.0);
    notifyListeners();
  }

  Future<void> setPlaybackSpeed(double speed) async {
    _playbackSpeed = speed;
    await _player?.setRate(speed);
    notifyListeners();
  }

  Future<void> seekTo(Duration position) async {
    await _player?.seek(position);
  }

  Future<void> stop() async {
    await _persistProgress();
    await _disposeController();
    _currentVideo = null;
    _isInitialized = false;
    _isPlaying = false;
    notifyListeners();
  }

  Future<void> _disposeController() async {
    await _positionSub?.cancel();
    await _durationSub?.cancel();
    await _playingSub?.cancel();
    await _completedSub?.cancel();
    _positionSub = null;
    _durationSub = null;
    _playingSub = null;
    _completedSub = null;

    if (_player != null) {
      try {
        await _player!.dispose();
      } catch (_) {}
      _player = null;
      _controller = null;
    }
  }

  @override
  void dispose() {
    // 不 await：这里只做最后一次落库，不阻塞销毁
    _persistProgress();
    _disposeController();
    super.dispose();
  }
}
