import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/comment_item.dart';

/// 视频上方的弹幕层。
///
/// 会从 [comments] 中按顺序循环取出评论，从屏幕右侧推入并向左移动。
/// 新增评论（通过 [addLiveComment]）会立即飘过。
class DanmakuOverlay extends StatefulWidget {
  final List<CommentItem> comments;
  final bool enabled;
  final int maxVisibleLines;

  const DanmakuOverlay({
    super.key,
    required this.comments,
    this.enabled = true,
    this.maxVisibleLines = 5,
  });

  @override
  State<DanmakuOverlay> createState() => DanmakuOverlayState();

  /// 公开方法，方便外部立即推入一条新评论
  static void addLiveComment(BuildContext context, CommentItem comment) {
    final state = context.findAncestorStateOfType<DanmakuOverlayState>();
    state?.addLiveComment(comment);
  }
}

class DanmakuOverlayState extends State<DanmakuOverlay>
    with TickerProviderStateMixin {
  final List<_ActiveDanmaku> _active = [];
  // 用可变列表代替 final，便于在 maxVisibleLines 变化时重建
  List<int> _laneOccupiedUntil = [];
  Timer? _timer;
  int _cursor = 0;
  final math.Random _random = math.Random();
  int _nextId = 0;

  @override
  void initState() {
    super.initState();
    _laneOccupiedUntil = List<int>.filled(widget.maxVisibleLines, 0);
    if (widget.enabled) _startLoop();
  }

  @override
  void didUpdateWidget(covariant DanmakuOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.maxVisibleLines != widget.maxVisibleLines) {
      _laneOccupiedUntil = List<int>.filled(widget.maxVisibleLines, 0);
    }
    if (oldWidget.enabled != widget.enabled) {
      if (widget.enabled) {
        _startLoop();
      } else {
        _stopLoop();
        _clearActive();
      }
    }
  }

  @override
  void dispose() {
    _stopLoop();
    _clearActive();
    super.dispose();
  }

  void _startLoop() {
    _stopLoop();
    _timer = Timer.periodic(const Duration(milliseconds: 1200), (_) {
      _spawnNext();
    });
    // 立即先发一条
    _spawnNext();
  }

  void _stopLoop() {
    _timer?.cancel();
    _timer = null;
  }

  void _clearActive() {
    for (final d in _active) {
      d.controller.dispose();
    }
    _active.clear();
    if (mounted) setState(() {});
  }

  void _spawnNext() {
    if (!mounted || !widget.enabled) return;
    if (widget.comments.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;

    // 找一条空闲轨道
    int? laneIndex;
    for (int i = 0; i < _laneOccupiedUntil.length; i++) {
      if (_laneOccupiedUntil[i] <= now) {
        laneIndex = i;
        break;
      }
    }
    if (laneIndex == null) return;

    final comment = widget.comments[_cursor % widget.comments.length];
    _cursor++;
    _spawn(comment, laneIndex);
  }

  void addLiveComment(CommentItem comment) {
    if (!mounted || !widget.enabled) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    int? laneIndex;
    for (int i = 0; i < _laneOccupiedUntil.length; i++) {
      if (_laneOccupiedUntil[i] <= now) {
        laneIndex = i;
        break;
      }
    }
    if (laneIndex == null) {
      laneIndex = _random.nextInt(_laneOccupiedUntil.length);
    }
    _spawn(comment, laneIndex);
  }

  void _spawn(CommentItem comment, int laneIndex) {
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );
    final id = _nextId++;
    final danmaku = _ActiveDanmaku(
      id: id,
      comment: comment,
      controller: controller,
      laneIndex: laneIndex,
    );
    _active.add(danmaku);

    // 估算弹幕完全进入屏幕所需的时间（基于字符数粗略估算）
    final enterMs = math.max(800, comment.content.length * 60);
    _laneOccupiedUntil[laneIndex] =
        DateTime.now().millisecondsSinceEpoch + enterMs;

    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        controller.dispose();
        _active.removeWhere((d) => d.id == id);
        if (mounted) setState(() {});
      }
    });
    controller.forward();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || _active.isEmpty) {
      return const SizedBox.shrink();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenHeight = constraints.maxHeight;
        final laneHeight = screenHeight / widget.maxVisibleLines;
        return Stack(
          clipBehavior: Clip.none,
          children: _active.map((d) {
            return AnimatedBuilder(
              animation: d.controller,
              builder: (context, child) {
                final t = d.controller.value;
                // 从右侧外（1.0）移到左侧外（-1.0）
                final offsetX = (1.0 - t * 2) * (constraints.maxWidth + 200);
                final top = d.laneIndex * laneHeight + 4.0;
                return Positioned(
                  left: offsetX,
                  top: top,
                  child: child!,
                );
              },
              child: _DanmakuChip(comment: d.comment),
            );
          }).toList(),
        );
      },
    );
  }
}

class _ActiveDanmaku {
  final int id;
  final CommentItem comment;
  final AnimationController controller;
  final int laneIndex;

  _ActiveDanmaku({
    required this.id,
    required this.comment,
    required this.controller,
    required this.laneIndex,
  });
}

class _DanmakuChip extends StatelessWidget {
  final CommentItem comment;
  const _DanmakuChip({required this.comment});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              comment.content,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                shadows: [
                  Shadow(color: Colors.black, offset: Offset(0.5, 0.5), blurRadius: 2),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
