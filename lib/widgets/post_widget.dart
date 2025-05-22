import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_instagram_clone/screen/post_screen.dart';
import 'package:flutter_instagram_clone/widgets/comments.dart';
import 'package:flutter_instagram_clone/widgets/like.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class PostWidget extends StatefulWidget {
  final String postId;
  final String username;
  final String caption;
  final String imageUrl;
  final String postTime;
  final String avatarUrl;
  final String uid;

  const PostWidget({
    super.key,
    required this.postId,
    required this.username,
    required this.caption,
    required this.imageUrl,
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

      // Load liked users data
      List<Map<String, dynamic>> likedUsersData = [];
      for (String uid in likedUsers.take(3)) {
        // Show only first 3 users
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
      final wasLiked = await _likeService.toggleLike(widget.postId);
      await _loadPostData(); // Reload all data to update liked users list
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
              _loadPostData(); // Reload to update comment count
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
          // Header
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

          // Post Image with double tap
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
                            imageUrl: widget.imageUrl,
                            postTime: widget.postTime,
                            avatarUrl: widget.avatarUrl,
                            postId: widget.postId,
                          ),
                    ),
                  );
                },
                onDoubleTap: _onDoubleTap,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12.r),
                  child: CachedNetworkImage(
                    imageUrl: widget.imageUrl.trim(),
                    width: double.infinity,
                    height: 375.h,
                    fit: BoxFit.cover,
                    placeholder:
                        (context, url) => Container(
                          color: Colors.grey.shade200,
                          child: Center(child: CircularProgressIndicator()),
                        ),
                    errorWidget: (context, url, error) => Icon(Icons.error),
                  ),
                ),
              ),

              // Heart animation
              if (_showHeart)
                ScaleTransition(
                  scale: _animation,
                  child: Icon(
                    Icons.favorite,
                    color: Colors.red.withOpacity(0.8),
                    size: 120.sp,
                  ),
                ),
            ],
          ),

          // Action Buttons with counts
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            child: Row(
              children: [
                // Like button with count
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

                // Comment button with count
                Row(
                  children: [
                    GestureDetector(
                      onTap: _showCommentsBottomSheet,
                      child: Image.asset('images/comment.webp', height: 26.h),
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
                Image.asset('images/send.jpg', height: 24.h),
                Spacer(),
                Image.asset('images/save.png', height: 24.h),
              ],
            ),
          ),

          // Liked users avatars and names (show first 3 users)
          if (_likedUsersData.isNotEmpty)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatars row
                  Row(
                    children: [
                      // Show up to 3 user avatars
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

                  // Usernames
                  GestureDetector(
                    onTap: _showLikesBottomSheet,
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(fontSize: 13.sp, color: Colors.black),
                        children: [
                          TextSpan(text: 'Liked by '),
                          ...List.generate(
                            _likedUsersData.length > 2
                                ? 2
                                : _likedUsersData.length,
                            (index) {
                              final isLast =
                                  index ==
                                  (_likedUsersData.length > 2
                                      ? 1
                                      : _likedUsersData.length - 1);
                              return TextSpan(
                                text:
                                    _likedUsersData[index]['username'] ??
                                    'Unknown',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              );
                            },
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

          // Caption
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

          // Comments count (clickable to view all)
          if (_commentsCount > 0)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 2.h),
              child: GestureDetector(
                onTap: _showCommentsBottomSheet,
                child: Text(
                  _commentsCount == 1
                      ? 'View 1 comment'
                      : 'View all $_commentsCount comments',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ),

          // Time
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

// Comments Bottom Sheet
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
      _loadComments();
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
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            width: 40.w,
            height: 4.h,
            margin: EdgeInsets.symmetric(vertical: 12.h),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),

          // Title
          Text(
            'Comments',
            style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
          ),

          Divider(height: 20.h),

          // Comments list
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
                        return ListTile(
                          leading: CircleAvatar(
                            radius: 16.r,
                            backgroundImage:
                                comment['avatarUrl'] != null &&
                                        comment['avatarUrl'].isNotEmpty
                                    ? NetworkImage(comment['avatarUrl'])
                                    : null,
                            child:
                                comment['avatarUrl'] == null ||
                                        comment['avatarUrl'].isEmpty
                                    ? Icon(Icons.account_circle, size: 20.sp)
                                    : null,
                          ),
                          title: RichText(
                            text: TextSpan(
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 13.sp,
                              ),
                              children: [
                                TextSpan(
                                  text: comment['username'] + ' ',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                TextSpan(text: comment['comment']),
                              ],
                            ),
                          ),
                          dense: true,
                        );
                      },
                    ),
          ),

          // Comment input
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
                      hintText: 'Add a comment...',
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
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }
}

// Likes Bottom Sheet
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
          // Handle
          Container(
            width: 40.w,
            height: 4.h,
            margin: EdgeInsets.symmetric(vertical: 12.h),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),

          // Title
          Text(
            'Likes',
            style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
          ),

          Divider(height: 20.h),

          // Users list
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
