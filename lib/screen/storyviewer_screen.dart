import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_instagram_clone/widgets/stories/storyservice.dart';
import 'package:flutter_instagram_clone/screen/chat_screen.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:video_player/video_player.dart';
import 'dart:async';

class StoryViewerScreen extends StatefulWidget {
  final Map<String, dynamic> initialUserData;
  final List<Map<String, dynamic>> allUsers;
  final VoidCallback? onStoryViewed;

  const StoryViewerScreen({
    super.key,
    required this.initialUserData,
    required this.allUsers,
    this.onStoryViewed,
  });

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen>
    with TickerProviderStateMixin {
  final StoryService _storyService = StoryService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _replyController = TextEditingController();

  late PageController _pageController;
  late AnimationController _progressController;
  late AnimationController _likeAnimationController;

  late String currentUserId;
  List<String> viewedBy = [];
  bool canViewViewedBy = false;

  int _currentUserIndex = 0;
  int _currentStoryIndex = 0;
  List<Map<String, dynamic>> _currentStories = [];
  VideoPlayerController? _videoController;
  Timer? _storyTimer;
  bool _isVideoPlaying = false;
  bool _isPaused = false;
  bool _showReplyInput = false;
  bool _isLiked = false;
  int _likesCount = 0;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _findInitialUserIndex();
    _loadCurrentUserStories();
    currentUserId = FirebaseAuth.instance.currentUser!.uid;
    loadViewedBy();
  }

  void _initializeControllers() {
    _pageController = PageController();
    _progressController = AnimationController(
      duration: const Duration(seconds: 5),
      vsync: this,
    );
    _likeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _progressController.addStatusListener(_onProgressComplete);
  }

  void _findInitialUserIndex() {
    _currentUserIndex = widget.allUsers.indexWhere(
      (user) => user['userId'] == widget.initialUserData['userId'],
    );
    if (_currentUserIndex == -1) _currentUserIndex = 0;
  }

  Future<void> loadViewedBy() async {
    final storyId = _currentStories[_currentStoryIndex]['storyId'];

    final doc =
        await FirebaseFirestore.instance
            .collection('stories')
            .doc(storyId)
            .get();

    final List<dynamic> viewers = doc['viewedBy'] ?? [];

    setState(() {
      viewedBy = viewers.cast<String>();
      canViewViewedBy = viewedBy.contains(currentUserId);
    });
  }

  Future<void> _loadCurrentUserStories() async {
    final currentUser = widget.allUsers[_currentUserIndex];
    _currentStories = List<Map<String, dynamic>>.from(
      currentUser['stories'] ?? [],
    );

    // Sort stories by timestamp (newest first for display, but we'll navigate chronologically)
    _currentStories.sort((a, b) {
      final aTime = a['timestamp'] as Timestamp?;
      final bTime = b['timestamp'] as Timestamp?;
      if (aTime == null || bTime == null) return 0;
      return aTime.compareTo(bTime); // Oldest first for viewing order
    });

    _currentStoryIndex = 0;
    await _loadCurrentStory();
  }

  Future<void> _loadCurrentStory() async {
    if (_currentStories.isEmpty) {
      _navigateToNextUser();
      return;
    }

    final story = _currentStories[_currentStoryIndex];

    // Mark story as viewed
    await _storyService.markStoryAsViewed(story['storyId']);
    widget.onStoryViewed?.call();

    // Load like status and count
    await _loadLikeStatus(story['storyId']);

    // Handle video stories
    if (story['videoUrl'] != null) {
      await _initializeVideoPlayer(story['videoUrl']);
    } else {
      _videoController?.dispose();
      _videoController = null;
      _isVideoPlaying = false;
    }

    _startStoryTimer();
  }

  Future<void> _loadLikeStatus(String storyId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // Check if current user liked this story
      final likeDoc =
          await _firestore
              .collection('stories')
              .doc(storyId)
              .collection('likes')
              .doc(user.uid)
              .get();

      // Get total likes count
      final likesSnapshot =
          await _firestore
              .collection('stories')
              .doc(storyId)
              .collection('likes')
              .get();

      if (mounted) {
        setState(() {
          _isLiked = likeDoc.exists;
          _likesCount = likesSnapshot.docs.length;
        });
      }
    } catch (e) {
      print('Error loading like status: $e');
    }
  }

  Future<void> _toggleLike() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final story = _currentStories[_currentStoryIndex];
    final storyId = story['storyId'];
    final storyOwnerId = widget.allUsers[_currentUserIndex]['userId'];

    // Không gửi thông báo nếu người dùng thích story của chính mình
    if (storyOwnerId == user.uid) return;

    try {
      final likeRef = _firestore
          .collection('stories')
          .doc(storyId)
          .collection('likes')
          .doc(user.uid);

      if (_isLiked) {
        // Unlike
        await likeRef.delete();
        setState(() {
          _isLiked = false;
          _likesCount = _likesCount > 0 ? _likesCount - 1 : 0;
        });
      } else {
        // Like
        await likeRef.set({
          'userId': user.uid,
          'timestamp': FieldValue.serverTimestamp(),
        });
        setState(() {
          _isLiked = true;
          _likesCount++;
        });

        // Animate like
        _likeAnimationController.forward().then((_) {
          _likeAnimationController.reverse();
        });

        // Gửi thông báo đến chủ story
        final userDoc =
            await _firestore.collection('users').doc(user.uid).get();
        final userData = userDoc.data() as Map<String, dynamic>?;

        await _firestore
            .collection('users')
            .doc(storyOwnerId)
            .collection('notifications')
            .add({
              'type': 'likeStory',
              'payload': {
                'fromUid': user.uid,
                'storyId': storyId,
                'fromUsername': userData?['username'] ?? 'Người dùng',
                'fromAvatar': userData?['avatarUrl'] ?? '',
              },
              'timestamp': FieldValue.serverTimestamp(),
              'isRead': false,
            });
      }
    } catch (e) {
      print('Error toggling like: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không thể thích story: $e')));
    }
  }

  Future<void> _sendReply() async {
    final user = _auth.currentUser;
    if (user == null || _replyController.text.trim().isEmpty) return;

    final currentUser = widget.allUsers[_currentUserIndex];
    final storyOwnerId = currentUser['userId'];

    // Don't allow replying to your own story
    if (storyOwnerId == user.uid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể reply story của chính mình')),
      );
      return;
    }

    final story = _currentStories[_currentStoryIndex];
    final replyText = _replyController.text.trim();

    try {
      // Create or get existing chat
      final chatId = _generateChatId(user.uid, storyOwnerId);

      // Send reply message with story reference
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add({
            'senderId': user.uid,
            'receiverId': storyOwnerId,
            'message': replyText,
            'timestamp': FieldValue.serverTimestamp(),
            'isRead': false,
            'reactions': [],
            'edited': false,
            'deleted': false,
            'storyReply': {
              'storyId': story['storyId'],
              'storyType': story['videoUrl'] != null ? 'video' : 'image',
              'storyUrl':
                  story['videoUrl'] ?? (story['imageUrls']?.first ?? ''),
              'storyOwner': currentUser['username'],
            },
          });

      // Update chat metadata
      await _firestore.collection('chats').doc(chatId).set({
        'participants': [user.uid, storyOwnerId],
        'lastMessage': 'Đã reply story của bạn: $replyText',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': user.uid,
      }, SetOptions(merge: true));

      _replyController.clear();
      setState(() {
        _showReplyInput = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã gửi reply')));

      // Navigate to chat screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder:
              (context) => ChatScreen(
                chatId: chatId,
                otherUserId: storyOwnerId,
                otherUsername: currentUser['username'] ?? 'Unknown',
                otherAvatarUrl: currentUser['avatarUrl'] ?? '',
              ),
        ),
      );
    } catch (e) {
      print('Error sending reply: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không thể gửi reply: $e')));
    }
  }

  String _generateChatId(String userId1, String userId2) {
    final ids = [userId1, userId2]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  Future<void> _initializeVideoPlayer(String videoUrl) async {
    _videoController?.dispose();
    _videoController = VideoPlayerController.network(videoUrl);

    try {
      await _videoController!.initialize();
      if (mounted) {
        setState(() {
          _isVideoPlaying = true;
        });
        _videoController!.play();
      }
    } catch (e) {
      print('Error initializing video: $e');
      _isVideoPlaying = false;
    }
  }

  void _startStoryTimer() {
    _storyTimer?.cancel();
    _progressController.reset();

    if (!_isPaused && !_showReplyInput) {
      if (_isVideoPlaying && _videoController != null) {
        // For video stories, use video duration
        final videoDuration = _videoController!.value.duration;
        _progressController.duration =
            videoDuration.inSeconds > 0
                ? videoDuration
                : const Duration(seconds: 15);
      } else {
        // For image stories, use default duration
        _progressController.duration = const Duration(seconds: 5);
      }

      _progressController.forward();
    }
  }

  void _onProgressComplete(AnimationStatus status) {
    if (status == AnimationStatus.completed && !_showReplyInput) {
      _navigateToNextStory();
    }
  }

  void _navigateToNextStory() {
    if (_currentStoryIndex < _currentStories.length - 1) {
      setState(() {
        _currentStoryIndex++;
        _showReplyInput = false;
      });
      _loadCurrentStory();
    } else {
      _navigateToNextUser();
    }
  }

  void _navigateToPreviousStory() {
    if (_currentStoryIndex > 0) {
      setState(() {
        _currentStoryIndex--;
        _showReplyInput = false;
      });
      _loadCurrentStory();
    } else {
      _navigateToPreviousUser();
    }
  }

  void _navigateToNextUser() {
    if (_currentUserIndex < widget.allUsers.length - 1) {
      setState(() {
        _currentUserIndex++;
        _showReplyInput = false;
      });
      _loadCurrentUserStories();
      loadViewedBy(); // Cập nhật viewedBy cho story đầu tiên của user mới
    } else {
      Navigator.of(context).pop();
    }
  }

  void _navigateToPreviousUser() {
    if (_currentUserIndex > 0) {
      setState(() {
        _currentUserIndex--;
        _showReplyInput = false;
      });
      _loadCurrentUserStories();
      loadViewedBy(); // Cập nhật viewedBy cho story đầu tiên của user mới
    } else {
      Navigator.of(context).pop();
    }
  }

  void _pauseStory() {
    setState(() {
      _isPaused = true;
    });
    _progressController.stop();
    _videoController?.pause();
  }

  void _handleSwipe(DragEndDetails details) {
    if (_showReplyInput) return;

    _resumeStory();
    final velocity = details.velocity.pixelsPerSecond.dx;

    if (velocity < -100) {
      // Vuốt sang phải -> Chuyển đến user tiếp theo
      _navigateToNextUser();
    } else if (velocity > 100) {
      // Vuốt sang trái -> Chuyển đến user trước đó
      _navigateToPreviousUser();
    }
  }

  void _resumeStory() {
    if (!_showReplyInput) {
      setState(() {
        _isPaused = false;
      });
      _progressController.forward();
      _videoController?.play();
    }
  }

  void _handleTap(TapUpDetails details) {
    if (_showReplyInput) return;

    _resumeStory();
    final screenWidth = MediaQuery.of(context).size.width;
    if (details.globalPosition.dx < screenWidth / 3) {
      _navigateToPreviousStory();
    } else if (details.globalPosition.dx > screenWidth * 2 / 3) {
      _navigateToNextStory();
    }
  }

  void _showViewedByBottomSheet() async {
    // Lấy thông tin người dùng từ userId
    List<Map<String, dynamic>> viewers = [];

    for (String uid in viewedBy) {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (userDoc.exists) {
        viewers.add(userDoc.data()!);
      }
    }

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children:
              viewers.map((viewer) {
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: NetworkImage(viewer['avatarUrl'] ?? ''),
                  ),
                  title: Text(viewer['username'] ?? ''),
                );
              }).toList(),
        );
      },
    );
  }

  String _getTimeAgo(dynamic timestamp) {
    if (timestamp == null) return 'now';

    try {
      final DateTime storyTime = (timestamp as Timestamp).toDate();
      final Duration difference = DateTime.now().difference(storyTime);

      if (difference.inMinutes < 1) {
        return 'now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return '${(difference.inDays / 7).floor()}w ago';
      }
    } catch (e) {
      return 'now';
    }
  }

  @override
  void dispose() {
    _storyTimer?.cancel();
    _progressController.dispose();
    _likeAnimationController.dispose();
    _videoController?.dispose();
    _pageController.dispose();
    _replyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentStories.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final currentStory = _currentStories[_currentStoryIndex];
    final currentUser = widget.allUsers[_currentUserIndex];
    final isOwnStory = currentUser['userId'] == _auth.currentUser?.uid;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: _showReplyInput ? null : (details) => _pauseStory(),
        onTapUp:
            _showReplyInput
                ? null
                : _handleTap, // Điều hướng giữa story trong user
        onHorizontalDragEnd:
            _showReplyInput ? null : _handleSwipe, // Điều hướng giữa user
        onTapCancel: _showReplyInput ? null : () => _resumeStory(),
        child: Stack(
          children: [
            // Story Content
            Center(child: _buildStoryContent(currentStory)),

            // Like Animation Overlay
            if (_likeAnimationController.isAnimating)
              Center(
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.5, end: 1.5).animate(
                    CurvedAnimation(
                      parent: _likeAnimationController,
                      curve: Curves.elasticOut,
                    ),
                  ),
                  child: Icon(Icons.favorite, color: Colors.red, size: 100.sp),
                ),
              ),

            // Progress Indicators
            Positioned(
              top: MediaQuery.of(context).padding.top + 10.h,
              left: 12.w,
              right: 60.w,
              child: _buildProgressIndicators(),
            ),

            // User Info Header
            Positioned(
              top: MediaQuery.of(context).padding.top + 50.h,
              left: 12.w,
              right: 12.w,
              child: _buildUserHeader(currentUser, currentStory),
            ),

            // Close Button
            Positioned(
              top: MediaQuery.of(context).padding.top + 10.h,
              right: 12.w,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(Icons.close, color: Colors.white, size: 28.sp),
              ),
            ),

            // Action Buttons (Like and Reply)
            if (!isOwnStory)
              Positioned(
                bottom: _showReplyInput ? 120.h : 50.h,
                right: 12.w,
                child: Column(
                  children: [
                    // Like Button
                    GestureDetector(
                      onTap: _toggleLike,
                      child: Container(
                        padding: EdgeInsets.all(12.w),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isLiked ? Icons.favorite : Icons.favorite_border,
                          color: _isLiked ? Colors.red : Colors.white,
                          size: 28.sp,
                        ),
                      ),
                    ),
                    if (_likesCount > 0) ...[
                      SizedBox(height: 4.h),
                      Text(
                        _likesCount.toString(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                    SizedBox(height: 16.h),
                    // Reply Button
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _showReplyInput = !_showReplyInput;
                          if (_showReplyInput) {
                            _pauseStory();
                          } else {
                            _resumeStory();
                          }
                        });
                      },
                      child: Container(
                        padding: EdgeInsets.all(12.w),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.reply_all_outlined,
                          color: Colors.white,
                          size: 28.sp,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Reply Input
            if (_showReplyInput)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.8),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20.r),
                    ),
                  ),
                  child: SafeArea(
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16.r,
                          backgroundImage:
                              _auth.currentUser?.photoURL != null
                                  ? NetworkImage(_auth.currentUser!.photoURL!)
                                  : null,
                          backgroundColor: Colors.grey,
                          child:
                              _auth.currentUser?.photoURL == null
                                  ? Icon(
                                    Icons.person,
                                    size: 16.sp,
                                    color: Colors.white,
                                  )
                                  : null,
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: TextField(
                            controller: _replyController,
                            style: TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText:
                                  'Reply to ${currentUser['username']}...',
                              hintStyle: TextStyle(color: Colors.grey),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20.r),
                                borderSide: BorderSide(color: Colors.grey),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20.r),
                                borderSide: BorderSide(color: Colors.white),
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16.w,
                                vertical: 8.h,
                              ),
                            ),
                            maxLines: null,
                            onSubmitted: (_) => _sendReply(),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        IconButton(
                          onPressed: _sendReply,
                          icon: Icon(
                            Icons.send,
                            color: Colors.white,
                            size: 24.sp,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoryContent(Map<String, dynamic> story) {
    if (story['videoUrl'] != null && _videoController != null) {
      return AspectRatio(
        aspectRatio: _videoController!.value.aspectRatio,
        child: VideoPlayer(_videoController!),
      );
    } else if (story['imageUrls'] != null && story['imageUrls'].isNotEmpty) {
      return Image.network(
        story['imageUrls'][0],
        fit: BoxFit.contain,
        width: double.infinity,
        height: double.infinity,
        errorBuilder:
            (context, error, stackTrace) =>
                Icon(Icons.error, color: Colors.white, size: 50.sp),
      );
    } else {
      return Icon(Icons.error, color: Colors.white, size: 50.sp);
    }
  }

  Widget _buildProgressIndicators() {
    return Row(
      children: List.generate(_currentStories.length, (index) {
        return Expanded(
          child: Container(
            height: 3.h,
            margin: EdgeInsets.symmetric(horizontal: 1.w),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(1.5.r),
              color: Colors.white.withOpacity(0.3),
            ),
            child: AnimatedBuilder(
              animation: _progressController,
              builder: (context, child) {
                double progress = 0.0;
                if (index < _currentStoryIndex) {
                  progress = 1.0;
                } else if (index == _currentStoryIndex) {
                  progress = _progressController.value;
                }

                return LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.transparent,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                );
              },
            ),
          ),
        );
      }),
    );
  }

  Widget _buildUserHeader(
    Map<String, dynamic> user,
    Map<String, dynamic> currentStory,
  ) {
    final isOwnStory = user['userId'] == _auth.currentUser?.uid;

    return Row(
      children: [
        CircleAvatar(
          radius: 18.r,
          backgroundImage:
              user['avatarUrl'] != null
                  ? NetworkImage(user['avatarUrl'])
                  : null,
          backgroundColor: Colors.grey.shade400,
          child:
              user['avatarUrl'] == null
                  ? Icon(Icons.person, size: 20.sp, color: Colors.white)
                  : null,
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user['username'] ?? 'Unknown',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                _getTimeAgo(currentStory['timestamp']),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 12.sp,
                ),
              ),
            ],
          ),
        ),
        if (isOwnStory &&
            canViewViewedBy) // Chỉ hiển thị nếu là story của chính mình
          IconButton(
            icon: Icon(Icons.remove_red_eye_outlined, color: Colors.white),
            onPressed: _showViewedByBottomSheet,
          ),
        // Story counter
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Text(
            '${_currentStoryIndex + 1}/${_currentStories.length}',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
