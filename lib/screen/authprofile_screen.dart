import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_instagram_clone/screen/post_screen.dart';
import 'package:flutter_instagram_clone/screen/reel_detail.dart';
import 'package:flutter_instagram_clone/screen/chat_screen.dart'; // Import chat screen
import 'package:flutter_screenutil/flutter_screenutil.dart';

class OtherUserProfileScreen extends StatefulWidget {
  final String userId;
  final String? username; // Optional username for display

  const OtherUserProfileScreen({
    super.key,
    required this.userId,
    this.username,
  });

  @override
  State<OtherUserProfileScreen> createState() => _OtherUserProfileScreenState();
}

class _OtherUserProfileScreenState extends State<OtherUserProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String username = '';
  String email = '';
  String bio = '';
  String avatarUrl = '';
  int postCount = 0;
  int followerCount = 0;
  int followingCount = 0;
  bool isLoading = true;
  bool isFollowing = false;
  bool isCurrentUser = false;

  @override
  void initState() {
    super.initState();
    checkIfCurrentUser();
    fetchUserData();
    checkFollowStatus();
  }

  void checkIfCurrentUser() {
    final currentUser = _auth.currentUser;
    if (currentUser != null && currentUser.uid == widget.userId) {
      isCurrentUser = true;
    }
  }

  Future<void> fetchUserData() async {
    try {
      // Fetch user data
      final userDoc =
          await _firestore.collection('users').doc(widget.userId).get();

      // Fetch post count
      final postSnapshot =
          await _firestore
              .collection('posts')
              .where('uid', isEqualTo: widget.userId)
              .get();

      // Fetch follower count
      final followerSnapshot =
          await _firestore
              .collection('users')
              .doc(widget.userId)
              .collection('followers')
              .get();

      // Fetch following count
      final followingSnapshot =
          await _firestore
              .collection('users')
              .doc(widget.userId)
              .collection('following')
              .get();

      if (userDoc.exists) {
        final data = userDoc.data()!;
        setState(() {
          username = data['username'] ?? '';
          email = data['email'] ?? '';
          bio = data['bio'] ?? '';
          avatarUrl = data['avatarUrl'] ?? '';
          postCount = postSnapshot.docs.length;
          followerCount = followerSnapshot.docs.length;
          followingCount = followingSnapshot.docs.length;
          isLoading = false;
        });
      }
    } catch (e) {
      print('Lỗi khi tải dữ liệu hồ sơ: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> checkFollowStatus() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null || isCurrentUser) return;

    try {
      final followDoc =
          await _firestore
              .collection('users')
              .doc(currentUser.uid)
              .collection('following')
              .doc(widget.userId)
              .get();

      setState(() {
        isFollowing = followDoc.exists;
      });
    } catch (e) {
      print('Lỗi khi kiểm tra trạng thái follow: $e');
    }
  }

  Future<void> toggleFollow() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null || isCurrentUser) return;

    try {
      final batch = _firestore.batch();

      if (isFollowing) {
        // Unfollow
        batch.delete(
          _firestore
              .collection('users')
              .doc(currentUser.uid)
              .collection('following')
              .doc(widget.userId),
        );

        batch.delete(
          _firestore
              .collection('users')
              .doc(widget.userId)
              .collection('followers')
              .doc(currentUser.uid),
        );
      } else {
        // Follow
        batch.set(
          _firestore
              .collection('users')
              .doc(currentUser.uid)
              .collection('following')
              .doc(widget.userId),
          {
            'timestamp': FieldValue.serverTimestamp(),
            'username': username,
            'avatarUrl': avatarUrl,
          },
        );

        batch.set(
          _firestore
              .collection('users')
              .doc(widget.userId)
              .collection('followers')
              .doc(currentUser.uid),
          {'timestamp': FieldValue.serverTimestamp()},
        );
      }

      await batch.commit();

      setState(() {
        isFollowing = !isFollowing;
        followerCount += isFollowing ? 1 : -1;
      });
    } catch (e) {
      print('Lỗi khi thay đổi trạng thái follow: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Có lỗi xảy ra: $e')));
    }
  }

  Future<void> navigateToChat() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null || isCurrentUser) return;

    // Check if following before allowing chat
    if (!isFollowing) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bạn cần follow người này để nhắn tin')),
      );
      return;
    }

    // Create or get chat room
    final chatId = _createChatId(currentUser.uid, widget.userId);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => ChatScreen(
              chatId: chatId,
              otherUserId: widget.userId,
              otherUsername: username,
              otherAvatarUrl: avatarUrl,
            ),
      ),
    );
  }

  String _createChatId(String userId1, String userId2) {
    // Create consistent chat ID regardless of order
    List<String> ids = [userId1, userId2];
    ids.sort();
    return '${ids[0]}_${ids[1]}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1.5,
        title: Text(
          username,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : SafeArea(
                child: RefreshIndicator(
                  onRefresh: () async {
                    await fetchUserData();
                    await checkFollowStatus();
                  },
                  child: DefaultTabController(
                    length: 2,
                    child: Column(
                      children: [
                        Padding(
                          padding: EdgeInsets.all(16.w),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 40.r,
                                backgroundImage:
                                    avatarUrl.isNotEmpty
                                        ? NetworkImage(avatarUrl)
                                        : const AssetImage('images/person.png')
                                            as ImageProvider,
                              ),
                              SizedBox(width: 16.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      username,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18.sp,
                                      ),
                                    ),
                                    if (bio.isNotEmpty) ...[
                                      SizedBox(height: 8.h),
                                      Text(
                                        bio,
                                        style: TextStyle(fontSize: 14.sp),
                                      ),
                                    ],
                                    SizedBox(height: 16.h),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        _buildStatColumn("Posts", postCount),
                                        _buildStatColumn(
                                          "Followers",
                                          followerCount,
                                        ),
                                        _buildStatColumn(
                                          "Following",
                                          followingCount,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!isCurrentUser) ...[
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16.w),
                            child: Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: toggleFollow,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          isFollowing
                                              ? Colors.grey[300]
                                              : Colors.blue,
                                      foregroundColor:
                                          isFollowing
                                              ? Colors.black
                                              : Colors.white,
                                    ),
                                    child: Text(
                                      isFollowing ? "Unfollow" : "Follow",
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8.w),
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: navigateToChat,
                                    child: const Text("Message"),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 10.h),
                        ],
                        TabBar(
                          indicatorColor: Colors.black,
                          labelColor: Colors.black,
                          unselectedLabelColor: Colors.grey,
                          tabs: const [
                            Tab(icon: Icon(Icons.grid_on)),
                            Tab(icon: Icon(Icons.video_collection_outlined)),
                          ],
                        ),
                        Expanded(
                          child: TabBarView(
                            children: [
                              _buildUserPosts(widget.userId),
                              _buildUserReels(widget.userId),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
    );
  }

  Widget _buildUserPosts(String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream:
          _firestore
              .collection('posts')
              .where('uid', isEqualTo: uid)
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('Chưa có bài đăng nào.'));
        }

        final rawPosts = snapshot.data!.docs;
        final posts = List.from(rawPosts)..sort((a, b) {
          final aTime = (a['postTime'] as Timestamp?)?.toDate();
          final bTime = (b['postTime'] as Timestamp?)?.toDate();
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime);
        });

        return GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: posts.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
          ),
          itemBuilder: (context, index) {
            final post = posts[index];
            final postId = posts[index].id;
            final caption = post['caption'] ?? '';
            final imageUrls = List<String>.from(post['imageUrls'] ?? []);
            final postTime = post['postTime'] ?? '';
            final firstImageUrl = imageUrls.isNotEmpty ? imageUrls[0] : null;
            final isMultiImage = imageUrls.length > 1;

            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (_) => PostScreen(
                          uid: uid,
                          postId: postId,
                          username: username,
                          caption: caption,
                          imageUrls: imageUrls,
                          postTime:
                              post['postTime'] != null
                                  ? _formatTimestamp(
                                    post['postTime'] as Timestamp,
                                  )
                                  : 'Unknown time',
                          avatarUrl: avatarUrl,
                        ),
                  ),
                );
              },
              child: Stack(
                children: [
                  Positioned.fill(
                    child:
                        firstImageUrl != null
                            ? CachedNetworkImage(
                              imageUrl: firstImageUrl,
                              fit: BoxFit.cover,
                            )
                            : Container(
                              color: Colors.grey[300],
                              child: const Icon(Icons.image_not_supported),
                            ),
                  ),
                  if (isMultiImage)
                    const Positioned(
                      right: 4,
                      top: 4,
                      child: Icon(
                        Icons.collections,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildUserReels(String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream:
          _firestore
              .collection('reels')
              .where('uid', isEqualTo: uid)
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('Chưa có reels nào.'));
        }

        final rawReels = snapshot.data!.docs;
        final reels = List.from(rawReels)..sort((a, b) {
          final aTime = (a['postTime'] as Timestamp?)?.toDate();
          final bTime = (b['postTime'] as Timestamp?)?.toDate();
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime);
        });

        return GridView.builder(
          itemCount: reels.length,
          padding: EdgeInsets.all(2.w),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 2.w,
            mainAxisSpacing: 2.h,
          ),
          itemBuilder: (context, index) {
            final reelDoc = reels[index]; // DocumentSnapshot instance
            final reel = reelDoc.data() as Map<String, dynamic>;
            final videoUrl = reel['videoUrl'] ?? '';
            final thumbnailUrl = reel['thumbnailUrl'] ?? '';
            final caption = reel['caption'] ?? '';

            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => ReelDetailScreen(
                          doc: reelDoc.id,
                          videoUrl: videoUrl,
                          caption: caption,
                          thumbnailUrl: thumbnailUrl,
                        ),
                  ),
                );
              },
              child:
                  thumbnailUrl != null && thumbnailUrl.isNotEmpty
                      ? Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(thumbnailUrl, fit: BoxFit.cover),
                          const Positioned(
                            bottom: 5,
                            right: 5,
                            child: Icon(
                              Icons.play_circle_outline,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ],
                      )
                      : Container(
                        color: Colors.grey[300],
                        child: Icon(
                          Icons.videocam,
                          size: 30,
                          color: Colors.grey[600],
                        ),
                      ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatColumn(String label, int count) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$count',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp),
        ),
        Text(label, style: TextStyle(color: Colors.grey, fontSize: 14.sp)),
      ],
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final DateTime dateTime = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} ngày trước';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} giờ trước';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} phút trước';
    } else {
      return 'Vừa xong';
    }
  }
}
