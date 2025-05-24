import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_instagram_clone/screen/authprofile_screen.dart';
import 'package:flutter_instagram_clone/screen/post_screen.dart';
import 'package:flutter_instagram_clone/screen/reelsScreen.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;

  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  bool _isLoading = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    setState(() {
      _searchQuery = query;
      _isSearching = query.isNotEmpty;
    });

    Future.delayed(const Duration(milliseconds: 500), () {
      if (_searchController.text == query) {
        _performSearch(query);
      }
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final List<Map<String, dynamic>> results = [];
      final Set<String> userIds = {};

      final normalizedQuery = query.toLowerCase();

      final usersSnapshot = await _firestore.collection('users').get();

      for (final doc in usersSnapshot.docs) {
        if (doc.id == currentUser.uid) continue;

        final data = doc.data();
        final username = data['username']?.toString().toLowerCase() ?? '';
        final bio = data['bio']?.toString().toLowerCase() ?? '';

        if (username.contains(normalizedQuery) ||
            bio.contains(normalizedQuery)) {
          if (!userIds.contains(doc.id)) {
            userIds.add(doc.id);
            final resultData = data;
            resultData['id'] = doc.id;
            resultData['type'] = 'user';
            results.add(resultData);
          }
        }
      }

      final postsSnapshot = await _firestore.collection('posts').get();

      for (var doc in postsSnapshot.docs) {
        final data = doc.data();
        final caption = data['caption']?.toString().toLowerCase() ?? '';

        if (caption.contains(normalizedQuery)) {
          final resultData = data;
          resultData['id'] = doc.id;
          resultData['type'] = 'post';
          results.add(resultData);
        }
      }

      final reelsSnapshot = await _firestore.collection('reels').get();

      for (var doc in reelsSnapshot.docs) {
        final data = doc.data();
        final caption = data['caption']?.toString().toLowerCase() ?? '';

        if (caption.contains(normalizedQuery)) {
          final resultData = data;
          resultData['id'] = doc.id;
          resultData['type'] = 'reel';
          results.add(resultData);
        }
      }

      results.sort((a, b) {
        final aValue =
            (a['username'] ?? a['caption'] ?? '').toString().toLowerCase();
        final bValue =
            (b['username'] ?? b['caption'] ?? '').toString().toLowerCase();

        if (aValue.startsWith(normalizedQuery) &&
            !bValue.startsWith(normalizedQuery)) {
          return -1;
        } else if (!aValue.startsWith(normalizedQuery) &&
            bValue.startsWith(normalizedQuery)) {
          return 1;
        }

        final aIndex = aValue.indexOf(normalizedQuery);
        final bIndex = bValue.indexOf(normalizedQuery);

        if (aIndex != bIndex) {
          return aIndex.compareTo(bIndex);
        }

        return aValue.length.compareTo(bValue.length);
      });

      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    } catch (e) {
      print('Error searching: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error occurred: $e')));
    }
  }

  Future<bool> _checkFollowStatus(String userId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return false;

    try {
      final followDoc =
          await _firestore
              .collection('users')
              .doc(currentUser.uid)
              .collection('following')
              .doc(userId)
              .get();
      return followDoc.exists;
    } catch (e) {
      print('Error checking follow status: $e');
      return false;
    }
  }

  Future<void> _toggleFollow(String userId, bool isCurrentlyFollowing) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return;

      final userData = userDoc.data()!;
      final username = userData['username'] ?? '';
      final avatarUrl = userData['avatarUrl'] ?? '';

      final batch = _firestore.batch();

      if (isCurrentlyFollowing) {
        batch.delete(
          _firestore
              .collection('users')
              .doc(currentUser.uid)
              .collection('following')
              .doc(userId),
        );
        batch.delete(
          _firestore
              .collection('users')
              .doc(userId)
              .collection('followers')
              .doc(currentUser.uid),
        );
      } else {
        batch.set(
          _firestore
              .collection('users')
              .doc(currentUser.uid)
              .collection('following')
              .doc(userId),
          {
            'timestamp': FieldValue.serverTimestamp(),
            'username': username,
            'avatarUrl': avatarUrl,
          },
        );
        batch.set(
          _firestore
              .collection('users')
              .doc(userId)
              .collection('followers')
              .doc(currentUser.uid),
          {'timestamp': FieldValue.serverTimestamp()},
        );
      }

      await batch.commit();
      setState(() {});
    } catch (e) {
      print('Error toggling follow: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error occurred: $e')));
    }
  }

  // Format Timestamp to String, consistent with ProfileScreen
  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown time';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchBox(),
            if (_isSearching)
              _buildSearchResults()
            else
              Expanded(child: _buildExploreContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBox() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
      child: Container(
        width: double.infinity,
        height: 60.h,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.all(Radius.circular(5.r)),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 3.w),
          child: Row(
            children: [
              Icon(Icons.search, color: Colors.black),
              SizedBox(width: 7.w),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search users, posts, reels',
                    hintStyle: TextStyle(color: Colors.grey[600]),
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                  style: const TextStyle(color: Colors.black),
                  autofocus: false,
                ),
              ),
              if (_isSearching)
                IconButton(
                  icon: Icon(Icons.clear, color: Colors.grey),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _isSearching = false;
                      _searchResults = [];
                    });
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_isLoading) {
      return const Expanded(child: Center(child: CircularProgressIndicator()));
    }

    if (_searchResults.isEmpty) {
      return Expanded(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_search, size: 64, color: Colors.grey),
              SizedBox(height: 16.h),
              Text(
                'No results found for "$_searchQuery"',
                style: TextStyle(fontSize: 18.sp, color: Colors.grey[600]),
              ),
              SizedBox(height: 8.h),
              Text(
                'Try searching with a different keyword',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return Expanded(
      child: Column(
        children: [
          TabBar(
            controller: _tabController,
            labelColor: Colors.black,
            unselectedLabelColor: Colors.grey,
            tabs: const [
              Tab(text: 'All'),
              Tab(text: 'Users'),
              Tab(text: 'Posts/Reels'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAllResults(),
                _buildUserResults(),
                _buildContentResults(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllResults() {
    return ListView.builder(
      itemCount: _searchResults.length,
      padding: EdgeInsets.all(8.w),
      itemBuilder: (context, index) {
        final result = _searchResults[index];
        if (result['type'] == 'user') {
          return _buildUserListItem(result);
        } else if (result['type'] == 'post') {
          return _buildPostListItem(result);
        } else if (result['type'] == 'reel') {
          return _buildReelListItem(result);
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildUserResults() {
    final userResults =
        _searchResults.where((result) => result['type'] == 'user').toList();
    if (userResults.isEmpty) {
      return Center(
        child: Text('No users found', style: TextStyle(fontSize: 16.sp)),
      );
    }

    return ListView.builder(
      itemCount: userResults.length,
      padding: EdgeInsets.all(8.w),
      itemBuilder: (context, index) => _buildUserListItem(userResults[index]),
    );
  }

  Widget _buildContentResults() {
    final contentResults =
        _searchResults
            .where(
              (result) => result['type'] == 'post' || result['type'] == 'reel',
            )
            .toList();
    if (contentResults.isEmpty) {
      return Center(
        child: Text(
          'No posts or reels found',
          style: TextStyle(fontSize: 16.sp),
        ),
      );
    }

    return ListView.builder(
      itemCount: contentResults.length,
      padding: EdgeInsets.all(8.w),
      itemBuilder: (context, index) {
        final result = contentResults[index];
        if (result['type'] == 'post') {
          return _buildPostListItem(result);
        } else {
          return _buildReelListItem(result);
        }
      },
    );
  }

  Widget _buildUserListItem(Map<String, dynamic> userData) {
    final userId = userData['id'] ?? '';
    final username = userData['username'] ?? 'Unknown';
    final bio = userData['bio'] ?? '';
    final avatarUrl = userData['avatarUrl'] ?? '';

    return FutureBuilder<bool>(
      future: _checkFollowStatus(userId),
      builder: (context, followSnapshot) {
        final isFollowing = followSnapshot.data ?? false;

        return Card(
          margin: EdgeInsets.symmetric(vertical: 4.h),
          child: ListTile(
            leading: CircleAvatar(
              radius: 24.r,
              backgroundImage:
                  avatarUrl.isNotEmpty
                      ? NetworkImage(avatarUrl)
                      : const AssetImage('images/person.png') as ImageProvider,
            ),
            title: Text(
              username,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp),
            ),
            subtitle:
                bio.isNotEmpty
                    ? Text(
                      bio,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14.sp,
                      ),
                    )
                    : null,
            trailing: SizedBox(
              width: 80.w,
              child: ElevatedButton(
                onPressed: () => _toggleFollow(userId, isFollowing),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isFollowing ? Colors.grey[300] : Colors.blue,
                  foregroundColor: isFollowing ? Colors.black : Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 8.w),
                ),
                child: Text(
                  isFollowing ? 'Unfollow' : 'Follow',
                  style: TextStyle(fontSize: 12.sp),
                ),
              ),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => OtherUserProfileScreen(
                        userId: userId,
                        username: username,
                      ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildPostListItem(Map<String, dynamic> postData) {
    final imageUrls = List<String>.from(postData['imageUrls'] ?? []);
    final firstImageUrl = imageUrls.isNotEmpty ? imageUrls[0] : null;
    final isMultiImage = imageUrls.length > 1;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => PostScreen(
                  username: postData['username'] ?? 'Unknown',
                  caption: postData['caption'] ?? '',
                  imageUrls: imageUrls,
                  postTime:
                      postData['postTime'] != null
                          ? _formatTimestamp(postData['postTime'] as Timestamp)
                          : 'Unknown time',
                  avatarUrl: postData['avatarUrl'] ?? '',
                  postId: postData['id'] ?? '',
                  uid: postData['uid'] ?? '',
                ),
          ),
        );
      },
      child: Card(
        margin: EdgeInsets.symmetric(vertical: 4.h),
        child: Row(
          children: [
            SizedBox(
              width: 50.w,
              height: 50.h,
              child: Stack(
                children: [
                  Positioned.fill(
                    child:
                        firstImageUrl != null
                            ? CachedNetworkImage(
                              imageUrl: firstImageUrl,
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
                                  (context, url, error) =>
                                      const Icon(Icons.image_not_supported),
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
                        size: 16,
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Post from ${postData['username'] ?? 'Unknown'}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14.sp,
                    ),
                  ),
                  Text(
                    postData['caption'] ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReelListItem(Map<String, dynamic> reelData) {
    final thumbnailUrl = reelData['thumbnailUrl'] ?? '';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ReelsScreen(initialReelId: reelData['id']),
          ),
        );
      },
      child: Card(
        margin: EdgeInsets.symmetric(vertical: 4.h),
        child: Row(
          children: [
            SizedBox(
              width: 50.w,
              height: 50.h,
              child: Stack(
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
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.w,
                                ),
                              ),
                            ),
                        errorWidget:
                            (context, url, error) => const Icon(Icons.error),
                      )
                      : Container(
                        color: Colors.grey[300],
                        child: Icon(
                          Icons.videocam,
                          size: 30,
                          color: Colors.grey[600],
                        ),
                      ),
                  const Positioned(
                    bottom: 5,
                    right: 5,
                    child: Icon(
                      Icons.play_circle_outline,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reel from ${reelData['username'] ?? 'Unknown'}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14.sp,
                    ),
                  ),
                  Text(
                    reelData['caption'] ?? 'No description',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExploreContent() {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tìm kiếm',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.video_library),
                  label: const Text('Reels'),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ReelsScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        _buildFeaturedSection(
          title: 'Bài viết nổi bật',
          stream:
              _firestore
                  .collection('posts')
                  .orderBy('postTime', descending: true)
                  .limit(10)
                  .snapshots(),
          itemBuilder: (context, doc) {
            final data = doc.data() as Map<String, dynamic>;
            final imageUrls = List<String>.from(data['imageUrls'] ?? []);
            final firstImageUrl = imageUrls.isNotEmpty ? imageUrls[0] : null;
            final isMultiImage = imageUrls.length > 1;

            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => PostScreen(
                          username: data['username'] ?? 'Unknown',
                          caption: data['caption'] ?? '',
                          imageUrls: imageUrls,
                          postTime:
                              data['postTime'] != null
                                  ? _formatTimestamp(
                                    data['postTime'] as Timestamp,
                                  )
                                  : 'Unknown time',
                          avatarUrl: data['avatarUrl'] ?? '',
                          postId: doc.id,
                          uid: data['uid'] ?? '',
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
                                  (context, url, error) =>
                                      const Icon(Icons.image_not_supported),
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
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
            child: Text(
              'Tìm kiếm bài viết...',
              style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        StreamBuilder(
          stream: _firestore.collection('posts').snapshots(),
          builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
            if (!snapshot.hasData) {
              return const SliverToBoxAdapter(
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: 3.w),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final doc = snapshot.data!.docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final imageUrls = List<String>.from(data['imageUrls'] ?? []);
                  final firstImageUrl =
                      imageUrls.isNotEmpty ? imageUrls[0] : null;
                  final isMultiImage = imageUrls.length > 1;

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => PostScreen(
                                username: data['username'] ?? 'Unknown',
                                caption: data['caption'] ?? '',
                                imageUrls: imageUrls,
                                postTime:
                                    data['postTime'] != null
                                        ? _formatTimestamp(
                                          data['postTime'] as Timestamp,
                                        )
                                        : 'Unknown time',
                                avatarUrl: data['avatarUrl'] ?? '',
                                postId: doc.id,
                                uid: data['uid'] ?? '',
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
                                        (context, url, error) => const Icon(
                                          Icons.image_not_supported,
                                        ),
                                  )
                                  : Container(
                                    color: Colors.grey[300],
                                    child: const Icon(
                                      Icons.image_not_supported,
                                    ),
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
                }, childCount: snapshot.data!.docs.length),
                gridDelegate: SliverQuiltedGridDelegate(
                  crossAxisCount: 3,
                  mainAxisSpacing: 3,
                  crossAxisSpacing: 3,
                  pattern: [
                    QuiltedGridTile(2, 1),
                    QuiltedGridTile(2, 2),
                    QuiltedGridTile(1, 1),
                    QuiltedGridTile(1, 1),
                    QuiltedGridTile(1, 1),
                  ],
                  repeatPattern: QuiltedGridRepeatPattern.inverted,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildFeaturedSection({
    required String title,
    required Stream<QuerySnapshot> stream,
    required Widget Function(BuildContext, DocumentSnapshot) itemBuilder,
  }) {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
            child: Text(
              title,
              style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(
            height: 180.h,
            child: StreamBuilder<QuerySnapshot>(
              stream: stream,
              builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: 5.w),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final doc = snapshot.data!.docs[index];
                    return Padding(
                      padding: EdgeInsets.symmetric(horizontal: 5.w),
                      child: SizedBox(
                        width: 140.w,
                        child: itemBuilder(context, doc),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCachedImage(List<String> imageUrls) {
    final firstImageUrl = imageUrls.isNotEmpty ? imageUrls[0] : null;
    final isMultiImage = imageUrls.length > 1;

    return Stack(
      children: [
        Positioned.fill(
          child:
              firstImageUrl != null
                  ? CachedNetworkImage(
                    imageUrl: firstImageUrl,
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
                            const Icon(Icons.image_not_supported),
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
      ],
    );
  }
}
