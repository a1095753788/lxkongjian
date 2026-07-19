import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../models/video_item.dart';

/// 基于 media_kit (libmpv/ffmpeg) 的播放器 Provider
///
/// 通过 `hwdec=no` 强制软解码，规避某些手机硬解码出现的
/// 绿色斜条纹、画面错位拉伸等 stride/pitch 兼容性问题。
class PlayerProvider extends ChangeNotifier {
  Player? _player;
  VideoController? _controller;
  VideoItem? _currentVideo;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _isMuted = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _playbackSpeed = 1.0;

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

    await _disposeController();

    _currentVideo = video;
    _isInitialized = false;
    _position = Duration.zero;
    _duration = Duration.zero;
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

      _isInitialized = true;
      await _player!.play();
      _isPlaying = true;

      notifyListeners();
    } catch (e) {
      _isInitialized = false;
      notifyListeners();
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
    _disposeController();
    super.dispose();
  }
}
