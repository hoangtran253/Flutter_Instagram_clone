import 'package:flutter/material.dart';
import 'package:flutter_instagram_clone/screen/storyviewer_screen.dart';
import 'package:flutter_instagram_clone/widgets/stories/storyservice.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screen/add_story_screen.dart';

class StoryBar extends StatefulWidget {
  final Function()? onStoryAdded;

  const StoryBar({super.key, this.onStoryAdded});

  @override
  State<StoryBar> createState() => _StoryBarState();
}

class _StoryBarState extends State<StoryBar> with TickerProviderStateMixin {
  final StoryService _storyService = StoryService();
  List<Map<String, dynamic>> _allUsers = [];
  bool _isLoading = true;
  String? _currentUserId;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _initAnimations();
    _loadStories();
  }

  void _initAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);
  }

  Future<void> _loadStories() async {
    setState(() => _isLoading = true);

    try {
      // Get all users
      final usersSnapshot =
          await FirebaseFirestore.instance.collection('users').get();

      List<Map<String, dynamic>> usersWithStories = [];

      // Always add current user first (for adding stories)
      if (_currentUserId != null) {
        final currentUserDoc = usersSnapshot.docs.firstWhere(
          (doc) => doc.id == _currentUserId,
          orElse: () => throw Exception('Current user not found'),
        );

        final currentUserData = currentUserDoc.data();
        final hasCurrentUserStories = await _storyService.hasActiveStories(
          _currentUserId!,
        );
        final currentUserStories = await _storyService.getStories(
          _currentUserId!,
        );

        usersWithStories.add({
          'userId': _currentUserId,
          'username': currentUserData['username'] ?? 'Unknown',
          'avatarUrl': currentUserData['avatarUrl'],
          'hasStories': hasCurrentUserStories,
          'hasUnviewedStories': false, // Current user stories are always viewed
          'stories': currentUserStories,
          'isCurrentUser': true,
        });
      }

      // Add other users who have active stories
      for (var userDoc in usersSnapshot.docs) {
        final userData = userDoc.data();
        final userId = userDoc.id;

        // Skip current user (already added)
        if (userId == _currentUserId) continue;

        // Check if user has active stories
        final hasStories = await _storyService.hasActiveStories(userId);

        // Only add users who have stories
        if (hasStories) {
          final stories = await _storyService.getStories(userId);

          // Check if current user has viewed all stories
          bool hasUnviewedStories = false;
          for (var story in stories) {
            final hasViewed = await _storyService.hasViewedStory(
              story['storyId'],
            );
            if (!hasViewed) {
              hasUnviewedStories = true;
              break;
            }
          }

          usersWithStories.add({
            'userId': userId,
            'username': userData['username'] ?? 'Unknown',
            'avatarUrl': userData['avatarUrl'],
            'hasStories': hasStories,
            'hasUnviewedStories': hasUnviewedStories,
            'stories': stories,
            'isCurrentUser': false,
          });
        }
      }

      // Sort other users: unviewed stories first, then viewed stories
      final currentUser = usersWithStories.removeAt(
        0,
      ); // Remove current user temporarily
      usersWithStories.sort((a, b) {
        if (a['hasUnviewedStories'] && !b['hasUnviewedStories']) return -1;
        if (!a['hasUnviewedStories'] && b['hasUnviewedStories']) return 1;
        return 0;
      });
      usersWithStories.insert(
        0,
        currentUser,
      ); // Add current user back at the beginning

      setState(() {
        _allUsers = usersWithStories;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading stories: $e');
      setState(() => _isLoading = false);
    }
  }

  void _navigateToAddStory() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder:
            (context, animation, secondaryAnimation) => AddStoryScreen(
              onUpload: (storyData) {
                _loadStories();
                widget.onStoryAdded?.call();
              },
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;

          var tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  void _navigateToStoryViewer(Map<String, dynamic> userData) {
    // Only navigate if user has stories
    if (!userData['hasStories']) return;

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder:
            (context, animation, secondaryAnimation) => StoryViewerScreen(
              initialUserData: userData,
              allUsers: _allUsers.where((user) => user['hasStories']).toList(),
              onStoryViewed: () => _loadStories(),
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.8, end: 1.0).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOut),
              ),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 110.h,
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child:
          _isLoading
              ? _buildLoadingStories()
              : ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: 8.w),
                itemCount: _allUsers.length,
                itemBuilder: (context, index) {
                  final userData = _allUsers[index];
                  return _buildStoryItem(userData);
                },
              ),
    );
  }

  Widget _buildLoadingStories() {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: 8.w),
      itemCount: 6,
      itemBuilder: (context, index) => _buildLoadingStoryItem(),
    );
  }

  Widget _buildLoadingStoryItem() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 6.w),
      child: Column(
        children: [
          Container(
            width: 68.w,
            height: 68.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey.shade300,
            ),
            child: const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
              ),
            ),
          ),
          SizedBox(height: 6.h),
          Container(
            width: 50.w,
            height: 12.h,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(6.r),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoryItem(Map<String, dynamic> userData) {
    final isCurrentUser = userData['isCurrentUser'] ?? false;
    final hasStories = userData['hasStories'] ?? false;
    final hasUnviewedStories = userData['hasUnviewedStories'] ?? false;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 6.w),
      child: Column(
        children: [
          _buildStoryAvatar(
            userData,
            isCurrentUser,
            hasStories,
            hasUnviewedStories,
          ),
          SizedBox(height: 6.h),
          _buildStoryUsername(userData['username'], isCurrentUser, hasStories),
        ],
      ),
    );
  }

  Widget _buildStoryAvatar(
    Map<String, dynamic> userData,
    bool isCurrentUser,
    bool hasStories,
    bool hasUnviewedStories,
  ) {
    Widget avatarWidget = Container(
      width: 62.w,
      height: 62.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.grey.shade200,
      ),
      child: ClipOval(
        child:
            userData['avatarUrl'] != null
                ? Image.network(
                  userData['avatarUrl'],
                  width: 62.w,
                  height: 62.w,
                  fit: BoxFit.cover,
                  errorBuilder:
                      (context, error, stackTrace) => _buildDefaultAvatar(),
                )
                : _buildDefaultAvatar(),
      ),
    );

    if (isCurrentUser) {
      // Current user - always show add button and story ring if has stories
      return Stack(
        children: [
          GestureDetector(
            onTap: hasStories ? () => _navigateToStoryViewer(userData) : null,
            child: Container(
              width: 68.w,
              height: 68.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient:
                    hasStories
                        ? LinearGradient(
                          colors: [Colors.grey.shade400, Colors.grey.shade300],
                        )
                        : null,
                border:
                    !hasStories
                        ? Border.all(color: Colors.grey.shade300, width: 2)
                        : null,
              ),
              child: Container(
                margin: EdgeInsets.all(hasStories ? 3.w : 3.w),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                child: avatarWidget,
              ),
            ),
          ),
          // Always show add button for current user
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: _navigateToAddStory,
              child: Container(
                width: 20.w,
                height: 20.w,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF1877F2),
                ),
                child: Icon(Icons.add, color: Colors.white, size: 14.sp),
              ),
            ),
          ),
        ],
      );
    } else if (hasStories) {
      // Other users with stories - show appropriate ring and tap to view
      return GestureDetector(
        onTap: () => _navigateToStoryViewer(userData),
        child: AnimatedBuilder(
          animation:
              hasUnviewedStories
                  ? _pulseAnimation
                  : const AlwaysStoppedAnimation(1.0),
          builder: (context, child) {
            return Transform.scale(
              scale: hasUnviewedStories ? _pulseAnimation.value : 1.0,
              child: Container(
                width: 68.w,
                height: 68.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient:
                      hasUnviewedStories
                          ? const LinearGradient(
                            colors: [
                              Color(0xFFFF6B6B),
                              Color(0xFFFFE066),
                              Color(0xFF4ECDC4),
                              Color(0xFF45B7D1),
                              Color(0xFF96CEB4),
                              Color(0xFFFD79A8),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                          : LinearGradient(
                            colors: [
                              Colors.grey.shade400,
                              Colors.grey.shade300,
                            ],
                          ),
                ),
                child: Container(
                  margin: EdgeInsets.all(3.w),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  child: avatarWidget,
                ),
              ),
            );
          },
        ),
      );
    } else {
      // Fallback (shouldn't happen since we filter out users without stories)
      return Container(width: 68.w, height: 68.w, child: avatarWidget);
    }
  }

  Widget _buildDefaultAvatar() {
    return Container(
      width: 62.w,
      height: 62.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.grey.shade300,
      ),
      child: Icon(Icons.person, color: Colors.grey.shade600, size: 30.sp),
    );
  }

  Widget _buildStoryUsername(
    String username,
    bool isCurrentUser,
    bool hasStories,
  ) {
    String displayText;
    if (isCurrentUser) {
      displayText = 'Your Story';
    } else {
      displayText = username;
    }

    return SizedBox(
      width: 70.w,
      child: Text(
        displayText,
        style: TextStyle(
          fontSize: 12.sp,
          color: Colors.black87,
          fontWeight: FontWeight.w500,
        ),
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    );
  }
}
