import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_instagram_clone/screen/post_screen.dart';
import 'package:flutter_instagram_clone/widgets/postservice/comments.dart';
import 'package:flutter_instagram_clone/widgets/postservice/like.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class PostWidget extends StatefulWidget {
  final String postId;
  final String username;
  final String caption;
  final List<String> imageUrls; // Changed to List<String>
  final String postTime;
  final String avatarUrl;
  final String uid;

  const PostWidget({
    super.key,
    required this.postId,
    required this.username,
    required this.caption,
    required this.imageUrls, // Changed to imageUrls
    required this.postTime,
    required this.avatarUrl,
    required this.uid,
  });

  @override
  State<PostWidget> createState() => _PostWidgetState();
}

class _PostWidgetState extends State<PostWidget>
    with SingleTickerProviderStateMixin {
  bool _isLiked = false;
  bool _showHeart = false;
  late AnimationController _controller;
  late Animation<double> _animation;
  int _likesCount = 0;
  int _commentsCount = 0;
  List<String> _likedUsers = [];
  List<Map<String, dynamic>> _likedUsersData = [];
  bool _isLoading = false;
  int _currentImageIndex = 0; // Track current image in carousel

  final LikeService _likeService = LikeService();
  final CommentService _commentService = CommentService();
  final TextEditingController _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    if (widget.postId.isNotEmpty) {
      _loadPostData();
    } else {
      print('Error: Invalid postId provided to PostWidget');
    }
  }

  void _initializeAnimations() {
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 1.5,
      end: 0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _showHeart = false;
        });
        _controller.reset();
      }
    });
  }

  Future<void> _loadPostData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final isLiked = await _likeService.isPostLiked(widget.postId);
      final likesCount = await _likeService.getLikesCount(widget.postId);
      final likedUsers = await _likeService.getLikedUsers(widget.postId);
      final commentsCount = await _commentService.getCommentsCount(
        widget.postId,
      );

      List<Map<String, dynamic>> likedUsersData = [];
      for (String uid in likedUsers.take(3)) {
        try {
          DocumentSnapshot userDoc =
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .get();
          if (userDoc.exists) {
            final userData = userDoc.data() as Map<String, dynamic>;
            userData['uid'] = uid;
            likedUsersData.add(userData);
          }
        } catch (e) {
          print('Error loading user data for $uid: $e');
        }
      }

      setState(() {
        _isLiked = isLiked;
        _likesCount = likesCount;
        _likedUsers = likedUsers;
        _likedUsersData = likedUsersData;
        _commentsCount = commentsCount;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading post data: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading post data')));
    }
  }

  Future<void> _toggleLike() async {
    if (widget.postId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Invalid post ID')));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _likeService.toggleLike(widget.postId);
      await _loadPostData();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error updating like')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onDoubleTap() {
    if (!_isLiked) {
      _toggleLike();
    }
    setState(() {
      _showHeart = true;
    });
    _controller.forward();
  }

  void _showCommentsBottomSheet() {
    if (widget.postId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Invalid post ID')));
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => CommentsBottomSheet(
            postId: widget.postId,
            onCommentAdded: () {
              _loadPostData();
            },
          ),
    );
  }

  void _showLikesBottomSheet() {
    if (_likesCount == 0 || widget.postId.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => LikesBottomSheet(likedUsers: _likedUsers),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            child: Row(
              children: [
                Container(
                  width: 40.w,
                  height: 40.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade300, width: 1),
                  ),
                  child: ClipOval(
                    child:
                        widget.avatarUrl.isNotEmpty
                            ? CachedNetworkImage(
                              imageUrl: widget.avatarUrl,
                              fit: BoxFit.cover,
                              placeholder:
                                  (context, url) => Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1.5,
                                    ),
                                  ),
                              errorWidget:
                                  (context, url, error) => Icon(Icons.error),
                            )
                            : Icon(Icons.account_circle, size: 35.w),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    widget.username,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(Icons.more_horiz),
              ],
            ),
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) => PostScreen(
                            username: widget.username,
                            caption: widget.caption,
                            imageUrls: widget.imageUrls, // Pass imageUrls
                            postTime: widget.postTime,
                            avatarUrl: widget.avatarUrl,
                            postId: widget.postId,
                            uid: widget.uid,
                          ),
                    ),
                  );
                },
                onDoubleTap: _onDoubleTap,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12.r),
                  child:
                      widget.imageUrls.isNotEmpty
                          ? CarouselSlider(
                            options: CarouselOptions(
                              height: 375.h,
                              viewportFraction: 1.0,
                              enableInfiniteScroll: false,
                              onPageChanged: (index, reason) {
                                setState(() {
                                  _currentImageIndex = index;
                                });
                              },
                            ),
                            items:
                                widget.imageUrls.map((imageUrl) {
                                  return CachedNetworkImage(
                                    imageUrl: imageUrl.trim(),
                                    width: double.infinity,
                                    height: 375.h,
                                    fit: BoxFit.cover,
                                    placeholder:
                                        (context, url) => Container(
                                          color: Colors.grey.shade200,
                                          child: Center(
                                            child: CircularProgressIndicator(),
                                          ),
                                        ),
                                    errorWidget:
                                        (context, url, error) =>
                                            Icon(Icons.error),
                                  );
                                }).toList(),
                          )
                          : Container(
                            width: double.infinity,
                            height: 375.h,
                            color: Colors.grey.shade200,
                            child: Center(child: Icon(Icons.error)),
                          ),
                ),
              ),
              if (_showHeart)
                ScaleTransition(
                  scale: _animation,
                  child: Icon(
                    Icons.favorite,
                    color: Colors.red.withOpacity(0.8),
                    size: 120.sp,
                  ),
                ),
              // Image index indicator (dots)
              if (widget.imageUrls.length > 1)
                Positioned(
                  bottom: 10.h,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      widget.imageUrls.length,
                      (index) => Container(
                        width: 8.w,
                        height: 8.h,
                        margin: EdgeInsets.symmetric(horizontal: 4.w),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              _currentImageIndex == index
                                  ? Colors.blue
                                  : Colors.grey.withOpacity(0.5),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            child: Row(
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: _isLoading ? null : _toggleLike,
                      child: Icon(
                        _isLiked ? Icons.favorite : Icons.favorite_border,
                        color: _isLiked ? Colors.red : Colors.black,
                        size: 26.sp,
                      ),
                    ),
                    if (_likesCount > 0) ...[
                      SizedBox(width: 6.w),
                      Text(
                        '$_likesCount',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(width: 15.w),
                Row(
                  children: [
                    GestureDetector(
                      onTap: _showCommentsBottomSheet,
                      child: Image.asset('images/comment.png', height: 26.h),
                    ),
                    if (_commentsCount > 0) ...[
                      SizedBox(width: 6.w),
                      Text(
                        '$_commentsCount',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(width: 15.w),
                Image.asset('images/sendoutline.png', height: 26.h),
                Spacer(),
                Image.asset('images/save.png', height: 24.h),
              ],
            ),
          ),
          if (_likedUsersData.isNotEmpty)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ...List.generate(
                        _likedUsersData.length > 3 ? 3 : _likedUsersData.length,
                        (index) => Container(
                          margin: EdgeInsets.only(right: 4.w),
                          child: CircleAvatar(
                            radius: 12.r,
                            backgroundColor: Colors.grey.shade300,
                            backgroundImage:
                                _likedUsersData[index]['avatarUrl'] != null &&
                                        _likedUsersData[index]['avatarUrl']
                                            .isNotEmpty
                                    ? NetworkImage(
                                      _likedUsersData[index]['avatarUrl'],
                                    )
                                    : null,
                            child:
                                _likedUsersData[index]['avatarUrl'] == null ||
                                        _likedUsersData[index]['avatarUrl']
                                            .isEmpty
                                    ? Icon(
                                      Icons.account_circle,
                                      size: 16.sp,
                                      color: Colors.grey,
                                    )
                                    : null,
                          ),
                        ),
                      ),
                      if (_likesCount > 3)
                        Container(
                          margin: EdgeInsets.only(left: 4.w),
                          child: Text(
                            '+${_likesCount - 3}',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 4.h),
                  GestureDetector(
                    onTap: _showLikesBottomSheet,
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(fontSize: 13.sp, color: Colors.black),
                        children: [
                          TextSpan(text: 'được thích bởi '),
                          ...List.generate(
                            _likedUsersData.length > 2
                                ? 2
                                : _likedUsersData.length,
                            (index) => TextSpan(
                              text:
                                  _likedUsersData[index]['username'] ??
                                  'Unknown',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ).expand((span) sync* {
                            yield span;
                            if (span !=
                                _likedUsersData
                                    .take(2)
                                    .map(
                                      (user) => TextSpan(
                                        text: user['username'] ?? 'Unknown',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    )
                                    .last) {
                              yield TextSpan(text: ', ');
                            }
                          }),
                          if (_likesCount > 2)
                            TextSpan(
                              text: ' and ${_likesCount - 2} others',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
            child: RichText(
              text: TextSpan(
                style: TextStyle(color: Colors.black, fontSize: 13.sp),
                children: [
                  TextSpan(
                    text: widget.username + " ",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: widget.caption),
                ],
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_commentsCount > 0)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 2.h),
              child: GestureDetector(
                onTap: _showCommentsBottomSheet,
                child: Text(
                  _commentsCount == 1
                      ? 'Xem 1 bình luận'
                      : 'Xem tất cả $_commentsCount bình luận',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            child: Text(
              widget.postTime,
              style: TextStyle(fontSize: 11.sp, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}

class CommentItem extends StatefulWidget {
  final Map<String, dynamic> comment;
  final String postId;
  final int indentLevel;

  const CommentItem({
    Key? key,
    required this.comment,
    required this.postId,
    this.indentLevel = 0,
  }) : super(key: key);

  @override
  State<CommentItem> createState() => _CommentItemState();
}

class _CommentItemState extends State<CommentItem> {
  bool _isLiked = false;
  int _likesCount = 0;
  bool _isLoading = false;
  bool _isEditing = false;
  bool _isReplying = false;
  final TextEditingController _editController = TextEditingController();
  final TextEditingController _replyController = TextEditingController();
  final CommentService _commentService = CommentService();

  @override
  void initState() {
    super.initState();
    _loadCommentLikes();
    _editController.text = widget.comment['comment'] ?? '';
  }

  Future<void> _loadCommentLikes() async {
    try {
      final commentLikes = List<String>.from(widget.comment['likes'] ?? []);
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;

      setState(() {
        _likesCount = commentLikes.length;
        _isLiked =
            currentUserId != null && commentLikes.contains(currentUserId);
      });
    } catch (e) {
      print('Error loading comment likes: $e');
    }
  }

  Future<void> _toggleCommentLike() async {
    if (_isLoading) return;

    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final commentTimestamp = widget.comment['timestamp'];
      if (commentTimestamp == null) return;

      final postRef = FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId);
      final postDoc = await postRef.get();

      if (postDoc.exists) {
        final postData = postDoc.data() as Map<String, dynamic>;
        final comments = List<Map<String, dynamic>>.from(
          postData['comments'] ?? [],
        );

        for (int i = 0; i < comments.length; i++) {
          if (comments[i]['timestamp'] == commentTimestamp &&
              comments[i]['uid'] == widget.comment['uid']) {
            final commentLikes = List<String>.from(comments[i]['likes'] ?? []);

            if (commentLikes.contains(currentUserId)) {
              commentLikes.remove(currentUserId);
              setState(() {
                _isLiked = false;
                _likesCount = commentLikes.length;
              });
            } else {
              commentLikes.add(currentUserId);
              setState(() {
                _isLiked = true;
                _likesCount = commentLikes.length;
              });
            }

            comments[i]['likes'] = commentLikes;
            break;
          }
        }

        await postRef.update({'comments': comments});
      }
    } catch (e) {
      print('Error toggling comment like: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error updating comment like')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _editComment() async {
    if (_isLoading || _editController.text.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _commentService.editComment(
        widget.postId,
        widget.comment['uid'],
        widget.comment['timestamp'],
        _editController.text.trim(),
      );
      setState(() {
        _isEditing = false;
        widget.comment['comment'] = _editController.text.trim();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Comment updated successfully')));
    } catch (e) {
      print('Error editing comment: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error updating comment')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteComment() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _commentService.deleteComment(
        widget.postId,
        widget.comment['uid'],
        widget.comment['timestamp'],
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Comment deleted successfully')));
      if (mounted) {
        Navigator.of(context).pop(); // Close bottom sheet to refresh
      }
    } catch (e) {
      print('Error deleting comment: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error deleting comment')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _addReply() async {
    if (_isLoading || _replyController.text.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _commentService.addReply(
        widget.postId,
        widget.comment['uid'],
        widget.comment['timestamp'],
        _replyController.text.trim(),
      );
      _replyController.clear();
      setState(() {
        _isReplying = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Reply added successfully')));
      // Trigger refresh by closing and reopening bottom sheet
      if (mounted) {
        Navigator.of(context).pop();
        widget.comment['replies'] = [
          ...(widget.comment['replies'] ?? []),
          {
            'uid': FirebaseAuth.instance.currentUser!.uid,
            'username':
                (await FirebaseFirestore.instance
                        .collection('users')
                        .doc(FirebaseAuth.instance.currentUser!.uid)
                        .get())
                    .data()?['username'] ??
                'Unknown User',
            'avatarUrl':
                (await FirebaseFirestore.instance
                        .collection('users')
                        .doc(FirebaseAuth.instance.currentUser!.uid)
                        .get())
                    .data()?['avatarUrl'] ??
                '',
            'comment': _replyController.text.trim(),
            'timestamp': Timestamp.now(),
            'likes': [],
          },
        ];
        _showCommentsBottomSheet();
      }
    } catch (e) {
      print('Error adding reply: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error adding reply')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _showDeleteConfirmation() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Delete Comment'),
            content: Text('Are you sure you want to delete this comment?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );

    if (confirm == true) {
      await _deleteComment();
    }
  }

  void _showCommentsBottomSheet() {
    if (widget.postId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Invalid post ID')));
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => CommentsBottomSheet(
            postId: widget.postId,
            onCommentAdded: () {
              // Refresh post data
              if (mounted) {
                (context.findAncestorStateOfType<_PostWidgetState>())
                    ?._loadPostData();
              }
            },
          ),
    );
  }

  String _getTimeAgo(dynamic timestamp) {
    if (timestamp == null) return '';

    DateTime commentTime;
    if (timestamp is Timestamp) {
      commentTime = timestamp.toDate();
    } else if (timestamp is DateTime) {
      commentTime = timestamp;
    } else {
      return '';
    }

    final now = DateTime.now();
    final difference = now.difference(commentTime);

    if (difference.inDays > 7) {
      return '${difference.inDays ~/ 7}w';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'now';
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isOwnComment =
        currentUserId != null && currentUserId == widget.comment['uid'];
    final replies = List<Map<String, dynamic>>.from(
      widget.comment['replies'] ?? [],
    );

    return Padding(
      padding: EdgeInsets.only(left: (widget.indentLevel * 20).w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 16.r,
                  backgroundColor: Colors.grey.shade300,
                  backgroundImage:
                      widget.comment['avatarUrl'] != null &&
                              widget.comment['avatarUrl'].isNotEmpty
                          ? NetworkImage(widget.comment['avatarUrl'])
                          : null,
                  child:
                      widget.comment['avatarUrl'] == null ||
                              widget.comment['avatarUrl'].isEmpty
                          ? Icon(
                            Icons.account_circle,
                            size: 20.sp,
                            color: Colors.grey,
                          )
                          : null,
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.comment['username'] ?? 'Unknown User',
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      if (_isEditing) ...[
                        TextField(
                          controller: _editController,
                          decoration: InputDecoration(
                            hintText: 'Sửa bình luận...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12.w,
                              vertical: 8.h,
                            ),
                          ),
                          maxLines: null,
                          autofocus: true,
                        ),
                        SizedBox(height: 8.h),
                        Row(
                          children: [
                            TextButton(
                              onPressed:
                                  _isLoading
                                      ? null
                                      : () => setState(() {
                                        _isEditing = false;
                                        _editController.text =
                                            widget.comment['comment'] ?? '';
                                      }),
                              child: Text('Hủy'),
                            ),
                            TextButton(
                              onPressed: _isLoading ? null : _editComment,
                              child: Text(
                                'Lưu',
                                style: TextStyle(color: Colors.blue),
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        Text(
                          widget.comment['comment'] ?? '',
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: Colors.black87,
                            height: 1.3,
                          ),
                        ),
                        SizedBox(height: 6.h),
                        Row(
                          children: [
                            Text(
                              _getTimeAgo(widget.comment['timestamp']),
                              style: TextStyle(
                                fontSize: 11.sp,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            SizedBox(width: 16.w),
                            if (_likesCount > 0) ...[
                              Text(
                                _likesCount == 1 ? '1' : '$_likesCount',
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(width: 16.w),
                            ],
                            GestureDetector(
                              onTap:
                                  () => setState(
                                    () => _isReplying = !_isReplying,
                                  ),
                              child: Text(
                                'Trả lời',
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(width: 8.w),
                Column(
                  children: [
                    GestureDetector(
                      onTap: _isLoading ? null : _toggleCommentLike,
                      child: Container(
                        padding: EdgeInsets.all(8.w),
                        child: Icon(
                          _isLiked ? Icons.favorite : Icons.favorite_border,
                          size: 16.sp,
                          color: _isLiked ? Colors.red : Colors.grey.shade600,
                        ),
                      ),
                    ),
                    if (_likesCount > 0)
                      Text(
                        '$_likesCount',
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: Colors.grey.shade600,
                        ),
                      ),
                  ],
                ),
                if (isOwnComment)
                  IconButton(
                    icon: Icon(Icons.more_vert, color: Colors.black),
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(16.r),
                          ),
                        ),
                        builder: (context) {
                          return Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ListTile(
                                  leading: Icon(
                                    Icons.edit,
                                    color: Colors.grey.shade600,
                                  ),
                                  title: Text('Sửa'),
                                  onTap:
                                      _isLoading
                                          ? null
                                          : () {
                                            Navigator.pop(context);
                                            setState(() => _isEditing = true);
                                          },
                                ),
                                ListTile(
                                  leading: Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  title: Text('Xóa'),
                                  onTap:
                                      _isLoading
                                          ? null
                                          : () {
                                            Navigator.pop(context);
                                            _showDeleteConfirmation();
                                          },
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
              ],
            ),
          ),
          if (_isReplying) ...[
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _replyController,
                      decoration: InputDecoration(
                        hintText: 'Viết trả lời...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 8.h,
                        ),
                      ),
                      maxLines: null,
                      autofocus: true,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  TextButton(
                    onPressed: _isLoading ? null : _addReply,
                    child: Text('Gửi', style: TextStyle(color: Colors.blue)),
                  ),
                  TextButton(
                    onPressed:
                        _isLoading
                            ? null
                            : () => setState(() {
                              _isReplying = false;
                              _replyController.clear();
                            }),
                    child: Text('Hủy'),
                  ),
                ],
              ),
            ),
          ],
          if (replies.isNotEmpty) ...[
            Padding(
              padding: EdgeInsets.only(left: 20.w),
              child: Column(
                children:
                    replies.map((reply) {
                      return CommentItem(
                        comment: reply,
                        postId: widget.postId,
                        indentLevel: widget.indentLevel + 1,
                      );
                    }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    _editController.dispose();
    _replyController.dispose();
    super.dispose();
  }
}

class CommentsBottomSheet extends StatefulWidget {
  final String postId;
  final VoidCallback onCommentAdded;

  const CommentsBottomSheet({
    Key? key,
    required this.postId,
    required this.onCommentAdded,
  }) : super(key: key);

  @override
  State<CommentsBottomSheet> createState() => _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends State<CommentsBottomSheet> {
  final TextEditingController _commentController = TextEditingController();
  final CommentService _commentService = CommentService();
  List<Map<String, dynamic>> _comments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (widget.postId.isNotEmpty) {
      _loadComments();
    } else {
      print('Error: Invalid postId provided to CommentsBottomSheet');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadComments() async {
    try {
      final comments = await _commentService.getComments(widget.postId);
      setState(() {
        _comments = comments;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading comments')));
    }
  }

  Future<void> _addComment() async {
    if (widget.postId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Invalid post ID')));
      return;
    }
    try {
      await _commentService.addComment(widget.postId, _commentController.text);
      _commentController.clear();
      widget.onCommentAdded();
      await _loadComments();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Comment added successfully')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error adding comment')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
        ),
        child: Column(
          children: [
            Container(
              width: 40.w,
              height: 4.h,
              margin: EdgeInsets.symmetric(vertical: 12.h),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            Text(
              'Comments',
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
            ),
            Divider(height: 20.h),
            Expanded(
              child:
                  _isLoading
                      ? Center(child: CircularProgressIndicator())
                      : _comments.isEmpty
                      ? Center(
                        child: Text(
                          'No comments yet',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14.sp,
                          ),
                        ),
                      )
                      : ListView.builder(
                        itemCount: _comments.length,
                        itemBuilder: (context, index) {
                          final comment = _comments[index];
                          return CommentItem(
                            comment: comment,
                            postId: widget.postId,
                          );
                        },
                      ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      decoration: InputDecoration(
                        hintText: 'Bạn nghĩ gì về nội dung này...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 8.h,
                        ),
                      ),
                      maxLines: null,
                    ),
                  ),
                  TextButton(
                    onPressed: _addComment,
                    child: Text(
                      'Post',
                      style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }
}

class LikesBottomSheet extends StatefulWidget {
  final List<String> likedUsers;

  const LikesBottomSheet({Key? key, required this.likedUsers})
    : super(key: key);

  @override
  State<LikesBottomSheet> createState() => _LikesBottomSheetState();
}

class _LikesBottomSheetState extends State<LikesBottomSheet> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      List<Map<String, dynamic>> users = [];
      for (String uid in widget.likedUsers) {
        DocumentSnapshot userDoc =
            await _firestore.collection('users').doc(uid).get();
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          userData['uid'] = uid;
          users.add(userData);
        }
      }
      setState(() {
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading users: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.5,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      child: Column(
        children: [
          Container(
            width: 40.w,
            height: 4.h,
            margin: EdgeInsets.symmetric(vertical: 12.h),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          Text(
            'Likes',
            style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
          ),
          Divider(height: 20.h),
          Expanded(
            child:
                _isLoading
                    ? Center(child: CircularProgressIndicator())
                    : ListView.builder(
                      itemCount: _users.length,
                      itemBuilder: (context, index) {
                        final user = _users[index];
                        return ListTile(
                          leading: CircleAvatar(
                            radius: 20.r,
                            backgroundImage:
                                user['avatarUrl'] != null &&
                                        user['avatarUrl'].isNotEmpty
                                    ? NetworkImage(user['avatarUrl'])
                                    : null,
                            child:
                                user['avatarUrl'] == null ||
                                        user['avatarUrl'].isEmpty
                                    ? Icon(Icons.account_circle, size: 24.sp)
                                    : null,
                          ),
                          title: Text(
                            user['username'] ?? 'Unknown User',
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle:
                              user['bio'] != null && user['bio'].isNotEmpty
                                  ? Text(
                                    user['bio'],
                                    style: TextStyle(fontSize: 12.sp),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  )
                                  : null,
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
