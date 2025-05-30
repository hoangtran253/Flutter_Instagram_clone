import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:flutter_instagram_clone/widgets/postservice/comments.dart';
import 'package:flutter_instagram_clone/widgets/postservice/like.dart';
import 'package:flutter_instagram_clone/widgets/notifications.dart';

class PostScreen extends StatefulWidget {
  final String username;
  final String caption;
  final List<String> imageUrls;
  final String postTime;
  final String avatarUrl;
  final String postId;
  final String uid; // post owner's uid

  const PostScreen({
    super.key,
    required this.username,
    required this.caption,
    required this.imageUrls,
    required this.postTime,
    required this.avatarUrl,
    required this.postId,
    required this.uid,
  });

  @override
  State<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends State<PostScreen> {
  int _currentImageIndex = 0;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LikeService _likeService = LikeService();
  final CommentService _commentService = CommentService();
  bool _isLiked = false;
  bool _isSaved = false;
  int _likesCount = 0;
  int _commentsCount = 0;
  int _shareCount = 0;
  List<String> _likedUsers = [];
  List<Map<String, dynamic>> _likedUsersData = [];
  List<Map<String, dynamic>> _comments = [];
  bool _isLoading = false;

  final TextEditingController _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPostData();
    _checkSaveStatus();
    _loadComments();
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
      final shareCount = await _getShareCount(widget.postId);

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
        _shareCount = shareCount;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading post data: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Error loading post data')));
    }
  }

  Future<int> _getShareCount(String postId) async {
    try {
      final snapshot =
          await _firestore
              .collection('posts')
              .doc(postId)
              .collection('shares')
              .get();
      return snapshot.docs.length;
    } catch (e) {
      print('Error getting share count: $e');
      return 0;
    }
  }

  Future<void> _checkSaveStatus() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      final saveDoc =
          await _firestore
              .collection('users')
              .doc(currentUser.uid)
              .collection('saved')
              .doc(widget.postId)
              .get();

      setState(() {
        _isSaved = saveDoc.exists;
      });
    } catch (e) {
      print('Error checking save status: $e');
    }
  }

  Future<void> _toggleSave() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null || widget.postId.isEmpty) return;

    try {
      final saveRef = _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('saved')
          .doc(widget.postId);

      if (_isSaved) {
        await saveRef.delete();
      } else {
        await saveRef.set({
          'postId': widget.postId,
          'username': widget.username,
          'caption': widget.caption,
          'imageUrls': widget.imageUrls,
          'postTime': widget.postTime,
          'avatarUrl': widget.avatarUrl,
          'uid': widget.uid,
          'savedAt': FieldValue.serverTimestamp(),
        });
      }

      setState(() {
        _isSaved = !_isSaved;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isSaved ? 'Đã lưu bài viết' : 'Đã bỏ lưu bài viết'),
          duration: const Duration(milliseconds: 1500),
        ),
      );
    } catch (e) {
      print('Error toggling save: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Có lỗi xảy ra: $e')));
    }
  }

  Future<void> _toggleLike() async {
    if (widget.postId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid post ID')));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = _auth.currentUser;
      final wasLiked = _isLiked;

      await _likeService.toggleLike(widget.postId);
      await _loadPostData();

      if (currentUser != null && widget.uid != currentUser.uid && !wasLiked) {
        final userDoc =
            await _firestore.collection('users').doc(currentUser.uid).get();
        final userData = userDoc.data() as Map<String, dynamic>?;

        await NotificationService().addNotification(
          receiverUid: widget.uid,
          type: 'like',
          payload: {
            'fromUid': currentUser.uid,
            'fromUsername': userData?['username'] ?? 'Người dùng',
            'fromAvatar': userData?['avatarUrl'] ?? '',
            'postId': widget.postId,
          },
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Error updating like')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _sharePost() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null || widget.postId.isEmpty) return;

    try {
      final userDoc =
          await _firestore.collection('users').doc(currentUser.uid).get();
      final userData = userDoc.data() as Map<String, dynamic>?;

      await NotificationService().addNotification(
        receiverUid: widget.uid,
        type: 'share',
        payload: {
          'fromUid': currentUser.uid,
          'fromUsername': userData?['username'] ?? 'Người dùng',
          'fromAvatar': userData?['avatarUrl'] ?? '',
          'postId': widget.postId,
        },
      );

      await _firestore
          .collection('posts')
          .doc(widget.postId)
          .collection('shares')
          .doc(currentUser.uid)
          .set({
            'sharedAt': FieldValue.serverTimestamp(),
            'sharedBy': currentUser.uid,
          });

      await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('sharedPosts')
          .doc(widget.postId)
          .set({
            'postId': widget.postId,
            'username': widget.username,
            'caption': widget.caption,
            'imageUrls': widget.imageUrls,
            'postTime': widget.postTime,
            'avatarUrl': widget.avatarUrl,
            'uid': widget.uid,
            'sharedAt': FieldValue.serverTimestamp(),
          });

      final newShareCount = await _getShareCount(widget.postId);
      setState(() {
        _shareCount = newShareCount;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã chia sẻ bài viết'),
          duration: Duration(milliseconds: 1500),
        ),
      );
    } catch (e) {
      print('Error sharing post: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Có lỗi xảy ra khi chia sẻ: $e')));
    }
  }

  // ----------- Comments Section Logic --------------
  Future<void> _loadComments() async {
    try {
      final comments = await _commentService.getComments(widget.postId);
      setState(() {
        _comments = comments;
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Error loading comments')));
    }
  }

  Future<void> _addComment() async {
    if (widget.postId.isEmpty || _commentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid post ID or empty comment')),
      );
      return;
    }
    try {
      await _commentService.addComment(widget.postId, _commentController.text);

      final postDoc =
          await FirebaseFirestore.instance
              .collection('posts')
              .doc(widget.postId)
              .get();
      final postOwnerId = postDoc.data()?['uid'] ?? '';
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null && postOwnerId != currentUser.uid) {
        // Lấy dữ liệu người dùng từ Firestore
        final userDoc =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(currentUser.uid)
                .get();
        final userData = userDoc.data() as Map<String, dynamic>?;

        await NotificationService().addNotification(
          receiverUid: postOwnerId,
          type: 'comment',
          payload: {
            'fromUid': currentUser.uid,
            'fromUsername': userData?['username'] ?? 'Người dùng',
            'fromAvatar': userData?['avatarUrl'] ?? '',
            'postId': widget.postId,
            'comment': _commentController.text,
          },
        );
      }

      _commentController.clear();
      await _loadComments();
      await _loadPostData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Comment added successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error adding comment: $e')));
    }
  }

  // ----------- Edit/Delete Post --------------
  Future<void> _deletePost() async {
    try {
      await _firestore.collection('posts').doc(widget.postId).delete();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post deleted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error deleting post: $e')));
    }
  }

  void _showDeleteConfirmationDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Post'),
            content: const Text(
              'Are you sure you want to delete this post? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _deletePost();
                },
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
  }

  void _showEditPostScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => EditPostScreen(
              postId: widget.postId,
              currentCaption: widget.caption,
              currentImageUrls: widget.imageUrls,
            ),
      ),
    ).then((_) {
      _loadPostData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _auth.currentUser;
    final isOwner = currentUser != null && currentUser.uid == widget.uid;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.username.isNotEmpty ? widget.username : 'Unknown User',
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          if (isOwner)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.black),
              onSelected: (value) {
                if (value == 'edit') {
                  _showEditPostScreen();
                } else if (value == 'delete') {
                  _showDeleteConfirmationDialog();
                }
              },
              itemBuilder:
                  (context) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        'Delete',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
            ),
        ],
      ),
      body: ListView(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20.r,
                  backgroundImage:
                      widget.avatarUrl.isNotEmpty
                          ? NetworkImage(widget.avatarUrl)
                          : null,
                  child:
                      widget.avatarUrl.isEmpty
                          ? Icon(Icons.account_circle, size: 40.sp)
                          : null,
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    widget.username.isNotEmpty
                        ? widget.username
                        : 'Unknown User',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              widget.imageUrls.isNotEmpty
                  ? CarouselSlider(
                    options: CarouselOptions(
                      height: 400.h,
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
                            height: 400.h,
                            fit: BoxFit.cover,
                            placeholder:
                                (context, url) => Container(
                                  color: Colors.grey.shade200,
                                  child: const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                            errorWidget:
                                (context, url, error) =>
                                    const Icon(Icons.error),
                          );
                        }).toList(),
                  )
                  : Container(
                    width: double.infinity,
                    height: 400.h,
                    color: Colors.grey.shade200,
                    child: const Center(child: Icon(Icons.error)),
                  ),
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
                SizedBox(width: 15.w),
                GestureDetector(
                  onTap: () {
                    // Scroll to comments section
                    Scrollable.ensureVisible(
                      context,
                      duration: Duration(milliseconds: 400),
                    );
                  },
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
                SizedBox(width: 15.w),
                GestureDetector(
                  onTap: _sharePost,
                  child: Image.asset('images/sendoutline.png', height: 26.h),
                ),
                if (_shareCount > 0) ...[
                  SizedBox(width: 6.w),
                  Text(
                    '$_shareCount',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ],
                Spacer(),
                GestureDetector(
                  onTap: _toggleSave,
                  child: Icon(
                    _isSaved ? Icons.bookmark : Icons.bookmark_border,
                    color: _isSaved ? Colors.yellow : Colors.black,
                    size: 26.sp,
                  ),
                ),
              ],
            ),
          ),
          if (_likedUsersData.isNotEmpty)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
              child: Row(
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
                                    _likedUsersData[index]['avatarUrl'].isEmpty
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
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            child: Text(
              widget.postTime.isNotEmpty ? widget.postTime : 'Unknown time',
              style: TextStyle(fontSize: 12.sp, color: Colors.grey),
            ),
          ),
          // Comments Section (no bottomsheet)
          Divider(),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: 'Bạn nghĩ gì về nội dung này...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 8.h,
                      ),
                    ),
                    maxLines: null,
                  ),
                ),
                SizedBox(width: 8.w),
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
          ..._comments.map(
            (comment) => CommentItem(comment: comment, postId: widget.postId),
          ),
          SizedBox(height: 20.h),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }
}

// ====== CommentItem & EditPostScreen (Keep as in your previous logic) ======

// CommentItem is reused from your main PostWidget (adapt as needed)
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
        // refresh post screen comments
        setState(() {});
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
                                            _deleteComment();
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
          if (replies.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(left: 20.w),
              child: Column(
                children:
                    replies
                        .map(
                          (reply) => CommentItem(
                            comment: reply,
                            postId: widget.postId,
                            indentLevel: widget.indentLevel + 1,
                          ),
                        )
                        .toList(),
              ),
            ),
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

// EditPostScreen class (same as before, unchanged)
class EditPostScreen extends StatefulWidget {
  final String postId;
  final String currentCaption;
  final List<String> currentImageUrls;

  const EditPostScreen({
    super.key,
    required this.postId,
    required this.currentCaption,
    required this.currentImageUrls,
  });

  @override
  State<EditPostScreen> createState() => _EditPostScreenState();
}

class _EditPostScreenState extends State<EditPostScreen> {
  final TextEditingController _captionController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _captionController.text = widget.currentCaption;
  }

  Future<void> _updatePost() async {
    try {
      await _firestore.collection('posts').doc(widget.postId).update({
        'caption': _captionController.text.trim(),
      });
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post updated successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error updating post: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Post'),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          TextButton(
            onPressed: _updatePost,
            child: const Text('Save', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _captionController,
              decoration: const InputDecoration(
                labelText: 'Caption',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
            ),
            SizedBox(height: 16.h),
            const Text('Images:'),
            Text(widget.currentImageUrls.join(', ')),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }
}
