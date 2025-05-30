import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_instagram_clone/screen/edit_profile_screen.dart';
import 'package:flutter_instagram_clone/screen/authprofile_screen.dart';
import 'package:flutter_instagram_clone/screen/post_screen.dart';
import 'package:flutter_instagram_clone/screen/reel_detail.dart';
import 'package:flutter_instagram_clone/screen/savecontent_screen.dart';
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
                          leading: const Icon(Icons.bookmark_border),
                          title: const Text('Nội dung đã lưu'),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SavedContentScreen(),
                              ),
                            );
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
                            Tab(icon: Icon(Icons.share)),
                          ],
                        ),
                        Expanded(
                          child: TabBarView(
                            children: [
                              _buildUserPosts(user.uid),
                              _buildUserReels(user.uid),
                              _buildSharedContent(),
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

  Widget _buildSharedContent() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getCombinedSharedContent(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.share, size: 80, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'Chưa có nội dung đã chia sẻ',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return GridView.builder(
          padding: EdgeInsets.all(2.w),
          itemCount: snapshot.data!.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
          ),
          itemBuilder: (context, index) {
            final item = snapshot.data![index];
            final isPost = item['type'] == 'post';
            return isPost
                ? _buildSharedPostsItem(item)
                : _buildSharedReelsItem(item);
          },
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _getCombinedSharedContent() async {
    final postsSnapshot =
        await _firestore
            .collection('users')
            .doc(_auth.currentUser!.uid)
            .collection('sharedPosts')
            .get();

    final reelsSnapshot =
        await _firestore
            .collection('users')
            .doc(_auth.currentUser!.uid)
            .collection('sharedReels')
            .get();

    List<Map<String, dynamic>> allContent = [];

    for (var doc in postsSnapshot.docs) {
      final data = doc.data();
      data['type'] = 'post';
      allContent.add(data);
    }

    for (var doc in reelsSnapshot.docs) {
      final data = doc.data();
      data['type'] = 'reel';
      allContent.add(data);
    }

    allContent.sort((a, b) {
      final aTime = a['sharedAt'] as Timestamp?;
      final bTime = b['sharedAt'] as Timestamp?;
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });

    return allContent;
  }

  Widget _buildSharedPostsItem(Map<String, dynamic> sharedPost) {
    final imageUrls = List<String>.from(sharedPost['imageUrls'] ?? []);
    final firstImageUrl = imageUrls.isNotEmpty ? imageUrls[0] : null;
    final isMultiImage = imageUrls.length > 1;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (_) => PostScreen(
                  uid: sharedPost['uid'] ?? '',
                  postId: sharedPost['postId'] ?? '',
                  username: sharedPost['username'] ?? '',
                  caption: sharedPost['caption'] ?? '',
                  imageUrls: imageUrls,
                  postTime: _formatTimestamp(sharedPost['postTime']),
                  avatarUrl: sharedPost['avatarUrl'] ?? '',
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
                      placeholder:
                          (context, url) => Container(
                            color: Colors.grey[300],
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                      errorWidget:
                          (context, url, error) => Container(
                            color: Colors.grey[300],
                            child: const Icon(Icons.image_not_supported),
                          ),
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
              child: Icon(Icons.collections, color: Colors.white, size: 20),
            ),
          Positioned(
            left: 4,
            bottom: 4,
            child: Container(
              padding: EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(Icons.share, color: Colors.white, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSharedReelsItem(Map<String, dynamic> sharedReel) {
    final thumbnailUrl = sharedReel['thumbnailUrl'] ?? '';
    final videoUrl = sharedReel['videoUrl'] ?? '';
    final caption = sharedReel['caption'] ?? '';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => ReelDetailScreen(
                  doc: _auth.currentUser!.uid,
                  videoUrl: videoUrl,
                  caption: caption,
                  thumbnailUrl: thumbnailUrl,
                ),
          ),
        );
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          thumbnailUrl.isNotEmpty
              ? CachedNetworkImage(
                imageUrl: thumbnailUrl,
                fit: BoxFit.cover,
                placeholder:
                    (context, url) => Center(
                      child: SizedBox(
                        width: 20.w,
                        height: 20.h,
                        child: CircularProgressIndicator(strokeWidth: 2.w),
                      ),
                    ),
                errorWidget:
                    (context, url, error) =>
                        Center(child: Icon(Icons.error, size: 20.w)),
              )
              : Container(
                color: Colors.grey[300],
                child: Icon(Icons.videocam, size: 30, color: Colors.grey[600]),
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
          Positioned(
            left: 4,
            bottom: 4,
            child: Container(
              padding: EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(Icons.share, color: Colors.white, size: 16),
            ),
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

  Widget _buildSharedPosts() {
    return StreamBuilder<QuerySnapshot>(
      stream:
          _firestore
              .collection('users')
              .doc(_auth.currentUser!.uid)
              .collection('sharedPosts')
              .orderBy('sharedAt', descending: true)
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.share, size: 80, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'Chưa có bài viết đã chia sẻ',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  'Chia sẻ các bài viết để xem lại sau',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final sharedPosts = snapshot.data!.docs;

        return GridView.builder(
          padding: EdgeInsets.all(2.w),
          itemCount: sharedPosts.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
          ),
          itemBuilder: (context, index) {
            final sharedPost =
                sharedPosts[index].data() as Map<String, dynamic>;
            return _buildSharedPostsItem(sharedPost);
          },
        );
      },
    );
  }

  Widget _buildSharedReels() {
    return StreamBuilder<QuerySnapshot>(
      stream:
          _firestore
              .collection('users')
              .doc(_auth.currentUser!.uid)
              .collection('sharedReels')
              .orderBy('sharedAt', descending: true)
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.share, size: 80, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'Chưa có reel đã chia sẻ',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        final sharedReels = snapshot.data!.docs;
        return GridView.builder(
          padding: EdgeInsets.all(2.w),
          itemCount: sharedReels.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
          ),
          itemBuilder: (context, index) {
            final sharedReel =
                sharedReels[index].data() as Map<String, dynamic>;
            return _buildSharedReelsItem(sharedReel);
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

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Unknown time';
    if (timestamp is String) return timestamp; // Đã là string thì trả lại luôn
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      final now = DateTime.now();
      final diff = now.difference(date);
      if (diff.inDays > 0) return '${diff.inDays} ngày trước';
      if (diff.inHours > 0) return '${diff.inHours} giờ trước';
      if (diff.inMinutes > 0) return '${diff.inMinutes} phút trước';
      return 'Vừa xong';
    }
    if (timestamp is DateTime) {
      final now = DateTime.now();
      final diff = now.difference(timestamp);
      if (diff.inDays > 0) return '${diff.inDays} ngày trước';
      if (diff.inHours > 0) return '${diff.inHours} giờ trước';
      if (diff.inMinutes > 0) return '${diff.inMinutes} phút trước';
      return 'Vừa xong';
    }
    return 'Unknown time';
  }
}
