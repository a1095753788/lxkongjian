import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/comment_item.dart';
import '../models/video_item.dart';
import '../providers/comment_provider.dart';
import '../theme/app_theme.dart';

/// 评论输入与列表底部弹窗。
///
/// 返回的 [CommentItem?] 是用户新发送的最后一条评论（用于让弹幕层立即显示）。
class CommentInputSheet extends StatefulWidget {
  final VideoItem video;
  const CommentInputSheet({super.key, required this.video});

  /// 弹出评论面板；返回用户新发送的评论（如有）
  static Future<CommentItem?> show(BuildContext context, VideoItem video) {
    return showModalBottomSheet<CommentItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => CommentInputSheet(video: video),
    );
  }

  @override
  State<CommentInputSheet> createState() => _CommentInputSheetState();
}

class _CommentInputSheetState extends State<CommentInputSheet> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _sending = false;
  CommentItem? _lastSent;

  @override
  void initState() {
    super.initState();
    // 进入面板时确保评论已加载
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CommentProvider>().setCurrentVideo(widget.video.id);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    final provider = context.read<CommentProvider>();
    final comment = await provider.addComment(
      videoId: widget.video.id,
      content: text,
    );
    if (comment != null) {
      _controller.clear();
      _lastSent = comment;
    }
    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          children: [
            // 顶部条
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Color(0xFF2A2A2A), width: 0.5),
                ),
              ),
              child: Row(
                children: [
                  const Text(
                    '评论',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Consumer<CommentProvider>(
                    builder: (context, p, _) {
                      final count = p.countOf(widget.video.id);
                      return Text(
                        '$count',
                        style: const TextStyle(color: Colors.white54, fontSize: 14),
                      );
                    },
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context, _lastSent),
                    child: const Icon(Icons.close, color: Colors.white70, size: 22),
                  ),
                ],
              ),
            ),
            // 评论列表
            Expanded(
              child: Consumer<CommentProvider>(
                builder: (context, p, _) {
                  final list = p.currentComments;
                  if (list.isEmpty) {
                    return const Center(
                      child: Text(
                        '还没有评论，发一条试试',
                        style: TextStyle(color: Colors.white38, fontSize: 14),
                      ),
                    );
                  }
                  final reversed = list.reversed.toList();
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: reversed.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 4),
                    itemBuilder: (context, index) {
                      final c = reversed[index];
                      return _CommentTile(
                        comment: c,
                        onLike: () => p.toggleLike(widget.video.id, c.id),
                        onDelete: () => p.deleteComment(widget.video.id, c.id),
                      );
                    },
                  );
                },
              ),
            ),
            // 输入框
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Color(0xFF2A2A2A), width: 0.5),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        maxLines: 1,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        decoration: InputDecoration(
                          hintText: '发条弹幕...',
                          hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
                          filled: true,
                          fillColor: const Color(0xFF2A2A2A),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _sending ? null : _send,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: _sending
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                '发送',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final CommentItem comment;
  final VoidCallback onLike;
  final VoidCallback onDelete;

  const _CommentTile({
    required this.comment,
    required this.onLike,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头像占位
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.7),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              comment.userName.isNotEmpty ? comment.userName.substring(0, 1) : '?',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment.userName,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      comment.timeAgo,
                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  comment.content,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    GestureDetector(
                      onTap: onLike,
                      child: Row(
                        children: [
                          Icon(
                            comment.isLiked ? Icons.favorite : Icons.favorite_border,
                            size: 14,
                            color: comment.isLiked ? AppTheme.primaryColor : Colors.white54,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${comment.likeCount}',
                            style: const TextStyle(color: Colors.white54, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: onDelete,
                      child: const Row(
                        children: [
                          Icon(Icons.delete_outline, size: 14, color: Colors.white54),
                          SizedBox(width: 4),
                          Text('删除', style: TextStyle(color: Colors.white54, fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
