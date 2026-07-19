import 'dart:io';
import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:provider/provider.dart';
import '../models/video_item.dart';
import '../providers/video_provider.dart';
import '../providers/player_provider.dart';
import '../providers/comment_provider.dart';
import 'danmaku_overlay.dart';

class VideoPlayerItem extends StatefulWidget {
  final VideoItem video;
  final int index;

  const VideoPlayerItem({
    super.key,
    required this.video,
    required this.index,
  });

  @override
  State<VideoPlayerItem> createState() => _VideoPlayerItemState();
}

class _VideoPlayerItemState extends State<VideoPlayerItem> {
  late PlayerProvider _playerProvider;
  bool _isVisible = false;

  @override
  void initState() {
    super.initState();
    _playerProvider = Provider.of<PlayerProvider>(context, listen: false);
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    final visible = info.visibleFraction > 0.5;
    if (visible != _isVisible) {
      _isVisible = visible;
      if (visible) {
        _playerProvider.playVideo(widget.video);
        context.read<VideoProvider>().incrementPlayCount(widget.video.id);
        // 同步当前视频的评论到弹幕与列表
        context.read<CommentProvider>().setCurrentVideo(widget.video.id);
      }
    }
  }

  void _onTap() {
    _playerProvider.togglePlay();
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key('video_${widget.video.id}'),
      onVisibilityChanged: _onVisibilityChanged,
      child: Container(
        color: Colors.black,
        child: Consumer<PlayerProvider>(
          builder: (context, player, child) {
            final controller = player.controller;
            final isCurrentVideo = player.currentVideo?.id == widget.video.id;

            return Stack(
              fit: StackFit.expand,
              children: [
                // 视频画面（media_kit 的 Video 内部处理 aspect ratio 与缩放）
                if (isCurrentVideo && controller != null && player.isInitialized)
                  Video(
                    controller: controller,
                    fill: Colors.black,
                    fit: BoxFit.contain,
                    controls: NoVideoControls,
                  )
                else if (isCurrentVideo && !player.isInitialized)
                  const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                    ),
                  )
                else
                  _buildThumbnail(),

                // 弹幕层：仅在当前视频初始化完成时显示
                if (isCurrentVideo && player.isInitialized)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 60,
                    bottom: 120,
                    child: IgnorePointer(
                      child: Consumer<CommentProvider>(
                        builder: (context, cp, _) {
                          return DanmakuOverlay(
                            comments: cp.currentComments,
                            enabled: player.isPlaying,
                          );
                        },
                      ),
                    ),
                  ),

                // 暂停图标
                if (isCurrentVideo && !player.isPlaying)
                  Center(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(20),
                      child: const Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 60,
                      ),
                    ),
                  ),

                // 点击区域
                GestureDetector(
                  onTap: _onTap,
                  behavior: HitTestBehavior.translucent,
                  child: const SizedBox.expand(),
                ),

                // 进度条
                if (isCurrentVideo && player.isInitialized)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _VideoProgressBar(
                      progress: player.progress,
                      position: player.position,
                      duration: player.duration,
                      onSeek: (progress) {
                        final duration = player.duration;
                        final position = Duration(
                          milliseconds: (duration.inMilliseconds * progress).round(),
                        );
                        player.seekTo(position);
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    final thumbPath = widget.video.thumbnailPath;
    if (thumbPath != null && thumbPath.isNotEmpty) {
      final file = File(thumbPath);
      return Container(
        color: const Color(0xFF1A1A1A),
        child: Image.file(
          file,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: const Color(0xFF1A1A1A),
              child: const Center(
                child: Icon(
                  Icons.play_circle_outline,
                  color: Colors.white38,
                  size: 80,
                ),
              ),
            );
          },
        ),
      );
    }
    return Container(
      color: const Color(0xFF1A1A1A),
      child: const Center(
        child: Icon(
          Icons.play_circle_outline,
          color: Colors.white38,
          size: 80,
        ),
      ),
    );
  }
}

class _VideoProgressBar extends StatelessWidget {
  final double progress;
  final Duration position;
  final Duration duration;
  final ValueChanged<double> onSeek;

  const _VideoProgressBar({
    required this.progress,
    required this.position,
    required this.duration,
    required this.onSeek,
  });

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                _formatDuration(position),
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 2,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                    activeTrackColor: const Color(0xFFFE2C55),
                    inactiveTrackColor: Colors.white24,
                    thumbColor: const Color(0xFFFE2C55),
                  ),
                  child: Slider(
                    value: progress.clamp(0.0, 1.0),
                    onChanged: onSeek,
                  ),
                ),
              ),
              Text(
                _formatDuration(duration),
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
