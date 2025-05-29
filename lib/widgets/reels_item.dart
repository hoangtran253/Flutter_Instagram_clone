import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_instagram_clone/widgets/reelservice/likereel.dart';
import 'package:flutter_instagram_clone/widgets/reelservice/commentreel.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReelItem extends StatefulWidget {
  final Map<String, dynamic> reelData;
  final bool currentlyPlaying;
  final VoidCallback? onDataChanged;

  const ReelItem({
    Key? key,
    required this.reelData,
    required this.currentlyPlaying,
    this.onDataChanged,
  }) : super(key: key);

  @override
  State<ReelItem> createState() => _ReelItemState();
}

class _ReelItemState extends State<ReelItem>
    with SingleTickerProviderStateMixin {
  VideoPlayerController? _controller;
  bool _isPlaying = false;
  bool _isInitialized = false;
  bool _isLiked = false;
  int _likesCount = 0;
  int _commentsCount = 0;
  int _sharesCount = 0; // Added share count
  bool _isLoadingLike = false;

  final ReelLikeService _likeService = ReelLikeService();
  final ReelCommentService _commentService = ReelCommentService();

  late final AnimationController _likeAnimationController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );

  late final Animation<double> _likeScaleAnimation = Tween<double>(
    begin: 1.0,
    end: 1.5,
  ).animate(
    CurvedAnimation(parent: _likeAnimationController, curve: Curves.easeOut),
  );

  @override
  void initState() {
    super.initState();
    _initVideo();
    _loadLikeStatus();
    _loadCommentsCount();
    _loadSharesCount(); // Initialize share count
    _likeAnimationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _likeAnimationController.reverse();
      }
    });
  }

  Future<void> _initVideo() async {
    final url = widget.reelData['videoUrl'];
    if (url == null) return;

    _controller = VideoPlayerController.networkUrl(Uri.parse(url));
    await _controller!.initialize();
    _controller!.setLooping(true);

    setState(() => _isInitialized = true);

    if (widget.currentlyPlaying) {
      _controller!.play();
      setState(() => _isPlaying = true);
    }
  }

  Future<void> _saveReel() async {
    final reelId = widget.reelData['reelId'];
    final currentUser = FirebaseAuth.instance.currentUser;
    if (reelId == null || currentUser == null) return;

    try {
      final savedDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .collection('savedReels')
              .doc(reelId)
              .get();

      if (savedDoc.exists) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .collection('savedReels')
            .doc(reelId)
            .delete();

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Đã bỏ lưu video')));
        }
      } else {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .collection('savedReels')
            .doc(reelId)
            .set({
              'reelId': reelId,
              'videoUrl': widget.reelData['videoUrl'],
              'thumbnailUrl': widget.reelData['thumbnailUrl'],
              'caption': widget.reelData['caption'],
              'username': widget.reelData['username'],
              'avatarUrl': widget.reelData['avatarUrl'],
              'uid': widget.reelData['uid'],
              'postTime': widget.reelData['postTime'],
              'savedAt': FieldValue.serverTimestamp(),
            });

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Đã lưu video')));
        }
      }
    } catch (e) {
      print('Error saving reel: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi khi lưu video: $e')));
      }
    }
  }

  Future<void> _loadLikeStatus() async {
    final reelId = widget.reelData['reelId'];
    if (reelId == null) return;

    try {
      final isLiked = await _likeService.isReelLiked(reelId);
      final likesCount = await _likeService.getLikesCount(reelId);

      if (mounted) {
        setState(() {
          _isLiked = isLiked;
          _likesCount = likesCount;
        });
      }
    } catch (e) {
      print('Error loading like status: $e');
    }
  }

  Future<void> _loadCommentsCount() async {
    final reelId = widget.reelData['reelId'];
    if (reelId == null) return;

    try {
      final commentsCount = await _commentService.getCommentsCount(reelId);

      if (mounted) {
        setState(() {
          _commentsCount = commentsCount;
        });
      }
    } catch (e) {
      print('Error loading comments count: $e');
    }
  }

  Future<void> _loadSharesCount() async {
    final reelId = widget.reelData['reelId'];
    if (reelId == null) return;

    try {
      final sharesSnapshot =
          await FirebaseFirestore.instance
              .collection('reels')
              .doc(reelId)
              .collection('shares')
              .get();
      if (mounted) {
        setState(() {
          _sharesCount = sharesSnapshot.docs.length;
        });
      }
    } catch (e) {
      print('Error loading shares count: $e');
    }
  }

  @override
  void didUpdateWidget(covariant ReelItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentlyPlaying && !_isPlaying && _isInitialized) {
      _controller?.play();
      setState(() => _isPlaying = true);
    } else if (!widget.currentlyPlaying && _isPlaying) {
      _controller?.pause();
      setState(() => _isPlaying = false);
    }

    if (oldWidget.reelData['reelId'] != widget.reelData['reelId']) {
      _loadLikeStatus();
      _loadCommentsCount();
      _loadSharesCount();
    }
  }

  void _togglePlayPause() {
    if (!_isInitialized || _controller == null) return;

    setState(() {
      if (_isPlaying) {
        _controller!.pause();
      } else {
        _controller!.play();
      }
      _isPlaying = !_isPlaying;
    });
  }

  Future<void> _onLikePressed() async {
    if (_isLoadingLike) return;

    final reelId = widget.reelData['reelId'];
    if (reelId == null) return;

    setState(() => _isLoadingLike = true);

    try {
      final newLikeStatus = await _likeService.toggleLike(reelId);

      if (mounted) {
        setState(() {
          _isLiked = newLikeStatus;
          _likesCount = newLikeStatus ? _likesCount + 1 : _likesCount - 1;
        });

        if (newLikeStatus) {
          _likeAnimationController.forward();
        }

        widget.onDataChanged?.call();
      }
    } catch (e) {
      print('Error toggling like: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi khi thích bài viết: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingLike = false);
      }
    }
  }

  void _onCommentPressed() {
    final reelId = widget.reelData['reelId'];
    if (reelId == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _buildCommentsBottomSheet(reelId),
    );
  }

  Future<void> _onSharePressed() async {
    final reelId = widget.reelData['reelId'];
    final currentUser = FirebaseAuth.instance.currentUser;
    if (reelId == null || currentUser == null) return;

    try {
      // Check if already shared
      final sharedDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .collection('sharedReels')
              .doc(reelId)
              .get();

      if (sharedDoc.exists) {
        // Remove share
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .collection('sharedReels')
            .doc(reelId)
            .delete();
        await FirebaseFirestore.instance
            .collection('reels')
            .doc(reelId)
            .collection('shares')
            .doc(currentUser.uid)
            .delete();

        if (mounted) {
          setState(() {
            _sharesCount = _sharesCount > 0 ? _sharesCount - 1 : 0;
          });
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Đã bỏ chia sẻ video')));
        }
      } else {
        // Add share
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .collection('sharedReels')
            .doc(reelId)
            .set({
              'reelId': reelId,
              'videoUrl': widget.reelData['videoUrl'],
              'thumbnailUrl': widget.reelData['thumbnailUrl'],
              'caption': widget.reelData['caption'],
              'username': widget.reelData['username'],
              'avatarUrl': widget.reelData['avatarUrl'],
              'uid': widget.reelData['uid'],
              'postTime': widget.reelData['postTime'],
              'sharedAt': FieldValue.serverTimestamp(),
            });

        await FirebaseFirestore.instance
            .collection('reels')
            .doc(reelId)
            .collection('shares')
            .doc(currentUser.uid)
            .set({
              'uid': currentUser.uid,
              'sharedAt': FieldValue.serverTimestamp(),
            });

        if (mounted) {
          setState(() {
            _sharesCount++;
          });
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Đã chia sẻ video')));
        }
      }

      widget.onDataChanged?.call();
    } catch (e) {
      print('Error sharing reel: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi khi chia sẻ video: $e')));
      }
    }
  }

  void _onMorePressed() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder:
          (context) => Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.bookmark_add_outlined,
                    color: Colors.white,
                  ),
                  title: const Text(
                    'Lưu video',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _saveReel();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.report, color: Colors.white),
                  title: const Text(
                    'Báo cáo',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Đã báo cáo video')),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.block, color: Colors.white),
                  title: const Text(
                    'Chặn người dùng',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Đã chặn người dùng')),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.copy, color: Colors.white),
                  title: const Text(
                    'Sao chép liên kết',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Đã sao chép liên kết')),
                    );
                  },
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildCommentsBottomSheet(String reelId) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Bình luận',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.grey, height: 1),
              Expanded(
                child: _CommentsWidget(
                  reelId: reelId,
                  scrollController: scrollController,
                  onCommentsChanged: () {
                    _loadCommentsCount();
                    widget.onDataChanged?.call();
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    _likeAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _isInitialized && _controller!.value.isInitialized
            ? GestureDetector(
              onTap: _togglePlayPause,
              child: Center(
                child: AspectRatio(
                  aspectRatio: _controller!.value.aspectRatio,
                  child: VideoPlayer(_controller!),
                ),
              ),
            )
            : const Center(child: CircularProgressIndicator()),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.transparent, Colors.black.withOpacity(0.6)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Stack(children: [_buildLeftInfo(), _buildRightActions()]),
        ),
        if (!_isPlaying)
          const Center(
            child: Icon(Icons.play_arrow, color: Colors.white, size: 64),
          ),
      ],
    );
  }

  Widget _buildLeftInfo() {
    return Align(
      alignment: Alignment.bottomLeft,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundImage:
                    widget.reelData['avatarUrl'] != null
                        ? CachedNetworkImageProvider(
                          widget.reelData['avatarUrl'],
                        )
                        : null,
                radius: 20,
                backgroundColor: Colors.black,
                child:
                    widget.reelData['avatarUrl'] == null
                        ? const Icon(Icons.person, color: Colors.white)
                        : null,
              ),
              const SizedBox(width: 8),
              Text(
                widget.reelData['username'] ?? 'Người dùng',
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white),
                  minimumSize: const Size(0, 30),
                ),
                child: const Text(
                  'Follow',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.reelData['caption'] ?? '',
            style: const TextStyle(color: Colors.white),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            children: const [
              Icon(Icons.music_note, color: Colors.white, size: 16),
              SizedBox(width: 4),
              Text('Original Audio', style: TextStyle(color: Colors.white)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRightActions() {
    return Align(
      alignment: Alignment.bottomRight,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _likeAnimationController,
            builder:
                (_, child) => Transform.scale(
                  scale: _likeScaleAnimation.value,
                  child: Column(
                    children: [
                      IconButton(
                        icon:
                            _isLoadingLike
                                ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                                : Icon(
                                  _isLiked
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: _isLiked ? Colors.red : Colors.white,
                                  size: 26,
                                ),
                        onPressed: _isLoadingLike ? null : _onLikePressed,
                      ),
                      if (_likesCount > 0)
                        Text(
                          _formatCount(_likesCount),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
          ),
          const SizedBox(height: 8),
          Column(
            children: [
              IconButton(
                icon: Image.asset(
                  'images/comment.png',
                  color: Colors.white,
                  height: 26,
                ),
                onPressed: _onCommentPressed,
              ),
              if (_commentsCount > 0)
                Text(
                  _formatCount(_commentsCount),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Column(
            children: [
              IconButton(
                icon: Image.asset(
                  'images/sendoutline.png',
                  color: Colors.white,
                  height: 26,
                ),
                onPressed: _onSharePressed,
              ),
              if (_sharesCount > 0)
                Text(
                  _formatCount(_sharesCount),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
            ],
          ),
          const SizedBox(height: 8),
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white, size: 26),
            onPressed: _onMorePressed,
          ),
        ],
      ),
    );
  }

  String _formatCount(int count) {
    if (count < 1000) return count.toString();
    if (count < 1000000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '${(count / 1000000).toStringAsFixed(1)}M';
  }
}

class _CommentsWidget extends StatefulWidget {
  final String reelId;
  final ScrollController scrollController;
  final VoidCallback? onCommentsChanged;

  const _CommentsWidget({
    required this.reelId,
    required this.scrollController,
    this.onCommentsChanged,
  });

  @override
  State<_CommentsWidget> createState() => _CommentsWidgetState();
}

class _CommentsWidgetState extends State<_CommentsWidget> {
  final TextEditingController _commentController = TextEditingController();
  final ReelCommentService _commentService = ReelCommentService();
  List<Map<String, dynamic>> _comments = [];
  bool _isLoading = true;
  bool _isSending = false;
  final FocusNode _focusNode = FocusNode();
  String? _replyingTo;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  Future<void> _loadComments() async {
    try {
      final comments = await _commentService.getComments(widget.reelId);
      setState(() {
        _comments = comments;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading comments: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendComment() async {
    if (_commentController.text.trim().isEmpty || _isSending) return;

    setState(() => _isSending = true);

    try {
      if (_replyingTo != null) {
        // Handle reply logic here if needed
        // For now, just add as regular comment
        await _commentService.addComment(
          widget.reelId,
          _commentController.text,
        );
      } else {
        await _commentService.addComment(
          widget.reelId,
          _commentController.text,
        );
      }

      _commentController.clear();
      _focusNode.unfocus();
      setState(() => _replyingTo = null);
      await _loadComments();
      widget.onCommentsChanged?.call();
    } catch (e) {
      print('Error sending comment: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi khi gửi bình luận: $e')));
    } finally {
      setState(() => _isSending = false);
    }
  }

  Future<void> _deleteComment(String commentUid, Timestamp timestamp) async {
    try {
      await _commentService.deleteComment(widget.reelId, commentUid, timestamp);
      await _loadComments();
      widget.onCommentsChanged?.call();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã xóa bình luận')));
    } catch (e) {
      print('Error deleting comment: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi khi xóa bình luận: $e')));
    }
  }

  Future<void> _editComment(
    String commentUid,
    Timestamp timestamp,
    String currentText,
  ) async {
    final controller = TextEditingController(text: currentText);

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Colors.grey[900],
            title: const Text(
              'Chỉnh sửa bình luận',
              style: TextStyle(color: Colors.white),
            ),
            content: TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Nhập bình luận...',
                hintStyle: TextStyle(color: Colors.grey),
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Hủy'),
              ),
              TextButton(
                onPressed: () async {
                  if (controller.text.trim().isNotEmpty) {
                    try {
                      await _commentService.editComment(
                        widget.reelId,
                        commentUid,
                        timestamp,
                        controller.text,
                      );
                      Navigator.pop(context);
                      await _loadComments();
                      widget.onCommentsChanged?.call();
                    } catch (e) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Lỗi khi chỉnh sửa: $e')),
                      );
                    }
                  }
                },
                child: const Text('Lưu'),
              ),
            ],
          ),
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final now = DateTime.now();
    final commentTime = timestamp.toDate();
    final difference = now.difference(commentTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'now';
    }
  }

  void _showCommentOptions(Map<String, dynamic> comment) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isOwner = currentUser?.uid == comment['uid'];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder:
          (context) => Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isOwner) ...[
                  ListTile(
                    leading: const Icon(Icons.edit, color: Colors.white),
                    title: const Text(
                      'Chỉnh sửa',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _editComment(
                        comment['uid'],
                        comment['timestamp'],
                        comment['comment'],
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.delete, color: Colors.red),
                    title: const Text(
                      'Xóa',
                      style: TextStyle(color: Colors.red),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _deleteComment(comment['uid'], comment['timestamp']);
                    },
                  ),
                ] else ...[
                  ListTile(
                    leading: const Icon(Icons.reply, color: Colors.white),
                    title: const Text(
                      'Trả lời',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        _replyingTo = comment['username'];
                      });
                      _focusNode.requestFocus();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.report, color: Colors.white),
                    title: const Text(
                      'Báo cáo',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Đã báo cáo bình luận')),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Comments list
        Expanded(
          child:
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _comments.isEmpty
                  ? const Center(
                    child: Text(
                      'Chưa có bình luận nào\nHãy là người đầu tiên bình luận!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  )
                  : ListView.builder(
                    controller: widget.scrollController,
                    itemCount: _comments.length,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemBuilder: (context, index) {
                      final comment = _comments[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Avatar
                            CircleAvatar(
                              radius: 16,
                              backgroundImage:
                                  comment['avatarUrl'] != null
                                      ? CachedNetworkImageProvider(
                                        comment['avatarUrl'],
                                      )
                                      : null,
                              backgroundColor: Colors.grey[700],
                              child:
                                  comment['avatarUrl'] == null
                                      ? const Icon(
                                        Icons.person,
                                        size: 16,
                                        color: Colors.white,
                                      )
                                      : null,
                            ),
                            const SizedBox(width: 12),
                            // Comment content
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        comment['username'] ?? 'Unknown',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _formatTimestamp(comment['timestamp']),
                                        style: TextStyle(
                                          color: Colors.grey[400],
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    comment['comment'] ?? '',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _replyingTo = comment['username'];
                                          });
                                          _focusNode.requestFocus();
                                        },
                                        child: Text(
                                          'Trả lời',
                                          style: TextStyle(
                                            color: Colors.grey[400],
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // More options
                            IconButton(
                              icon: const Icon(
                                Icons.more_horiz,
                                color: Colors.grey,
                                size: 16,
                              ),
                              onPressed: () => _showCommentOptions(comment),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
        ),

        // Comment input
        Container(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            border: Border(top: BorderSide(color: Colors.grey[700]!)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_replyingTo != null)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Text(
                        'Đang trả lời @$_replyingTo',
                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => setState(() => _replyingTo = null),
                        child: Icon(
                          Icons.close,
                          color: Colors.grey[400],
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              Row(
                children: [
                  // Current user avatar
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.grey[700],
                    child: const Icon(
                      Icons.person,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Text input
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      focusNode: _focusNode,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText:
                            _replyingTo != null
                                ? 'Trả lời @$_replyingTo...'
                                : 'Thêm bình luận...',
                        hintStyle: TextStyle(color: Colors.grey[500]),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey[800],
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Send button
                  GestureDetector(
                    onTap: _isSending ? null : _sendComment,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _isSending ? Colors.grey : Colors.blue,
                        shape: BoxShape.circle,
                      ),
                      child:
                          _isSending
                              ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                              : const Icon(
                                Icons.send,
                                color: Colors.white,
                                size: 16,
                              ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
