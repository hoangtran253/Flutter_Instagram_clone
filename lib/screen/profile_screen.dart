import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_instagram_clone/screen/chatlist_screen.dart';
import 'package:flutter_instagram_clone/screen/edit_profile_screen.dart';
import 'package:flutter_instagram_clone/screen/authprofile_screen.dart';
import 'package:flutter_instagram_clone/screen/explor_screen.dart';
import 'package:flutter_instagram_clone/screen/post_screen.dart';
import 'package:flutter_instagram_clone/screen/reel_detail.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

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
  int followerCount = 0;
  int followingCount = 0;
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
      setState(() => isLoading = true);

      // Batch fetch user data, posts, followers, and following
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final postSnapshot =
          await _firestore
              .collection('posts')
              .where('uid', isEqualTo: user.uid)
              .get();
      final followerSnapshot =
          await _firestore
              .collection('users')
              .doc(user.uid)
              .collection('followers')
              .get();
      final followingSnapshot =
          await _firestore
              .collection('users')
              .doc(user.uid)
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
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      print('Error fetching profile data: $e');
      setState(() => isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error occurred: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text("User not found")));
    }

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
                            // Navigate to settings page (implement as needed)
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.logout),
                          title: const Text('Logout'),
                          onTap: () async {
                            await _auth.signOut();
                            Navigator.pop(context);
                            // Navigate to login screen (implement as needed)
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
                                        GestureDetector(
                                          onTap:
                                              () => _showFollowersList(context),
                                          child: _buildStatColumn(
                                            "Followers",
                                            followerCount,
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap:
                                              () => _showFollowingList(context),
                                          child: _buildStatColumn(
                                            "Following",
                                            followingCount,
                                          ),
                                        ),
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
                        const TabBar(
                          indicatorColor: Colors.black,
                          labelColor: Colors.black,
                          unselectedLabelColor: Colors.grey,
                          tabs: [
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
                              const Center(child: Text("Saved Posts")),
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

  void _showFollowersList(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Followers ($followerCount)'),
            content: SizedBox(
              width: double.maxFinite,
              height: 300.h,
              child: StreamBuilder<QuerySnapshot>(
                stream:
                    _firestore
                        .collection('users')
                        .doc(_auth.currentUser!.uid)
                        .collection('followers')
                        .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('No followers yet'));
                  }

                  return ListView.builder(
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      final followerId = snapshot.data!.docs[index].id;
                      return FutureBuilder<DocumentSnapshot>(
                        future:
                            _firestore
                                .collection('users')
                                .doc(followerId)
                                .get(),
                        builder: (context, userSnapshot) {
                          if (!userSnapshot.hasData) {
                            return const ListTile(title: Text('Loading...'));
                          }
                          final userData =
                              userSnapshot.data!.data()
                                  as Map<String, dynamic>?;
                          final username = userData?['username'] ?? 'Unknown';
                          final avatarUrl = userData?['avatarUrl'] ?? '';

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage:
                                  avatarUrl.isNotEmpty
                                      ? NetworkImage(avatarUrl)
                                      : const AssetImage('images/person.png')
                                          as ImageProvider,
                            ),
                            title: Text(username),
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => OtherUserProfileScreen(
                                        userId: followerId,
                                        username: username,
                                      ),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  void _showFollowingList(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Following ($followingCount)'),
            content: SizedBox(
              width: double.maxFinite,
              height: 300.h,
              child: StreamBuilder<QuerySnapshot>(
                stream:
                    _firestore
                        .collection('users')
                        .doc(_auth.currentUser!.uid)
                        .collection('following')
                        .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Text('Not following anyone yet'),
                    );
                  }

                  return ListView.builder(
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      final followingData =
                          snapshot.data!.docs[index].data()
                              as Map<String, dynamic>;
                      final followingId = snapshot.data!.docs[index].id;
                      final username = followingData['username'] ?? 'Unknown';
                      final avatarUrl = followingData['avatarUrl'] ?? '';

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage:
                              avatarUrl.isNotEmpty
                                  ? NetworkImage(avatarUrl)
                                  : const AssetImage('images/person.png')
                                      as ImageProvider,
                        ),
                        title: Text(username),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => OtherUserProfileScreen(
                                    userId: followingId,
                                    username: username,
                                  ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
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
          return const Center(child: Text('No posts yet'));
        }

        final rawPosts = snapshot.data!.docs;
        final posts = List.from(rawPosts)..sort((a, b) {
          final aTime = (a['postTime'] as Timestamp?)?.toDate();
          final bTime = (b['postTime'] as Timestamp?)?.toDate();
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime); // Newest first
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
          return const Center(child: Text('No reels yet'));
        }

        final rawReels = snapshot.data!.docs;
        final reels = List.from(rawReels)..sort((a, b) {
          final aTime = (a['postTime'] as Timestamp?)?.toDate();
          final bTime = (b['postTime'] as Timestamp?)?.toDate();
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime); // Newest first
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
            final thumbnailUrl = reel['thumbnailUrl'] ?? '';

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
                  thumbnailUrl.isNotEmpty
                      ? Stack(
                        fit: StackFit.expand,
                        children: [
                          CachedNetworkImage(
                            imageUrl: thumbnailUrl,
                            fit: BoxFit.cover,
                            placeholder:
                                (context, url) => Center(
                                  child: SizedBox(
                                    width: 20.w,
                                    height: 20.h,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.w,
                                    ),
                                  ),
                                ),
                            errorWidget:
                                (context, url, error) => Center(
                                  child: Icon(Icons.error, size: 20.w),
                                ),
                          ),
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
      return '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return 'Just now';
    }
  }
}
