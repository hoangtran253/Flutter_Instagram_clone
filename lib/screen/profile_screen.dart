import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_instagram_clone/screen/post_screen.dart';
import 'package:flutter_instagram_clone/screen/reel_detail.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_instagram_clone/screen/edit_profile_screen.dart'; // Import for edit profile

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String username = '';
  String email = '';
  String bio = '';
  String avatarUrl = '';
  int postCount = 0;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchUserData();
  }

  Future<void> fetchUserData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final postSnapshot =
          await _firestore
              .collection('posts')
              .where('uid', isEqualTo: user.uid)
              .get();

      if (userDoc.exists) {
        final data = userDoc.data()!;
        setState(() {
          username = data['username'] ?? '';
          email = data['email'] ?? '';
          bio = data['bio'] ?? '';
          avatarUrl = data['avatarUrl'] ?? '';
          postCount = postSnapshot.docs.length;
          isLoading = false;
        });
      }
    } catch (e) {
      print('Lỗi khi tải dữ liệu hồ sơ: $e');
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("Không tìm thấy người dùng")),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1.5,
        title: Text(
          bio,
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.black),
            onPressed: () async {
              showModalBottomSheet(
                context: context,
                builder:
                    (context) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.settings),
                          title: const Text('Settings'),
                          onTap: () {
                            Navigator.pop(context);
                            // Navigate to settings page
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.logout),
                          title: const Text('Logout'),
                          onTap: () async {
                            await _auth.signOut();
                            Navigator.pop(context);
                            // You might need to navigate to login screen here
                          },
                        ),
                      ],
                    ),
              );
            },
          ),
        ],
      ),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : SafeArea(
                child: RefreshIndicator(
                  onRefresh: fetchUserData,
                  child: DefaultTabController(
                    length: 3,
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
                                    SizedBox(height: 16.h),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        _buildStatColumn("Posts", postCount),
                                        _buildStatColumn("Followers", 0),
                                        _buildStatColumn("Following", 0),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.w),
                          child: Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (context) => EditProfileScreen(
                                              currentUsername: username,
                                              currentBio: bio,
                                              currentAvatarUrl: avatarUrl,
                                            ),
                                      ),
                                    ).then((_) => fetchUserData());
                                  },
                                  child: const Text("Edit Profile"),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 10.h),
                        TabBar(
                          indicatorColor: Colors.black,
                          labelColor: Colors.black,
                          unselectedLabelColor: Colors.grey,
                          tabs: const [
                            Tab(icon: Icon(Icons.grid_on)),
                            Tab(icon: Icon(Icons.video_collection_outlined)),
                            Tab(icon: Icon(Icons.bookmark_border)),
                          ],
                        ),
                        Expanded(
                          child: TabBarView(
                            children: [
                              _buildUserPosts(user.uid),
                              _buildUserReels(user.uid),
                              Center(child: Text("Saved Posts")),
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
          return const Center(child: Text('Bạn chưa đăng bài nào.'));
        }

        final rawPosts = snapshot.data!.docs;

        // Sắp xếp ở client theo postTime
        final posts = List.from(rawPosts)..sort((a, b) {
          final aTime = (a['postTime'] as Timestamp?)?.toDate();
          final bTime = (b['postTime'] as Timestamp?)?.toDate();
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1; // null thì để sau
          if (bTime == null) return -1;
          return bTime.compareTo(aTime); // mới nhất trước
        });

        return GridView.builder(
          itemCount: posts.length,
          padding: EdgeInsets.all(2.w),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 2.w,
            mainAxisSpacing: 2.h,
          ),
          itemBuilder: (context, index) {
            final post = posts[index].data() as Map<String, dynamic>;
            final postId =
                posts[index].id; // Get document ID for editing/deleting
            final imageUrl = post['imageUrl'] ?? '';
            final caption = post['caption'] ?? '';
            final postTime =
                post['postTime'] != null
                    ? _formatTimestamp(post['postTime'] as Timestamp)
                    : 'Unknown time';

            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (_) => PostScreen(
                          postId: postId,
                          username: username,
                          caption: caption,
                          imageUrl: imageUrl,
                          postTime: postTime,
                          avatarUrl: avatarUrl,
                        ),
                  ),
                ).then((deleted) {
                  // Refresh data if post was deleted
                  if (deleted == true) {
                    fetchUserData();
                  }
                });
              },
              child:
                  imageUrl.isNotEmpty
                      ? Image.network(imageUrl, fit: BoxFit.cover)
                      : Container(
                        color: Colors.grey[300],
                        child: Icon(
                          Icons.image,
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
          return const Center(child: Text('Bạn chưa có reels nào.'));
        }

        final rawReels = snapshot.data!.docs;

        // Sắp xếp ở client theo postTime
        final reels = List.from(rawReels)..sort((a, b) {
          final aTime = (a['postTime'] as Timestamp?)?.toDate();
          final bTime = (b['postTime'] as Timestamp?)?.toDate();
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1; // null thì để sau
          if (bTime == null) return -1;
          return bTime.compareTo(aTime); // mới nhất trước
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
            final reel = reels[index].data() as Map<String, dynamic>;
            final videoUrl = reel['videoUrl'] ?? '';
            final thumbnailUrl = reel['thumbnailUrl'];

            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => ReelDetailScreen(
                          videoUrl: videoUrl,
                          caption: reel['caption'] ?? '',
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

  // Helper to format timestamp
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
