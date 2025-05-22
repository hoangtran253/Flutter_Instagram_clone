import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_instagram_clone/screen/post_screen.dart';
import 'package:flutter_instagram_clone/screen/profile_screen.dart';
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
  final searchController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isSearching = false;
  String _searchQuery = '';
  late TabController _tabController;

  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    searchController.removeListener(_onSearchChanged);
    searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = searchController.text.trim();
      _isSearching = _searchQuery.isNotEmpty;
    });

    if (_isSearching) {
      _performSearch();
    } else {
      setState(() {
        _searchResults = [];
      });
    }
  }

  Future<void> _performSearch() async {
    final query = _searchQuery.trim().toLowerCase();
    final List<Map<String, dynamic>> results = [];

    // Lấy tất cả users
    final usersSnapshot = await _firestore.collection('users').get();
    for (var doc in usersSnapshot.docs) {
      final userData = doc.data();
      final username = userData['username']?.toString().toLowerCase() ?? '';
      final fullName = userData['fullName']?.toString().toLowerCase() ?? '';
      final bio = userData['bio']?.toString().toLowerCase() ?? '';

      if (username.contains(query) ||
          fullName.contains(query) ||
          bio.contains(query)) {
        results.add({
          'id': doc.id,
          'type': 'user',
          'username': userData['username'],
          'avatarUrl': userData['avatarUrl'],
          'fullName': userData['fullName'],
        });
      }
    }

    // Lấy tất cả posts
    final postsSnapshot = await _firestore.collection('posts').get();
    for (var doc in postsSnapshot.docs) {
      final postData = doc.data();
      final caption = postData['caption']?.toString().toLowerCase() ?? '';

      if (caption.contains(query)) {
        postData['id'] = doc.id;
        postData['type'] = 'post';
        results.add(postData);
      }
    }

    // Lấy tất cả reels
    final reelsSnapshot = await _firestore.collection('reels').get();
    for (var doc in reelsSnapshot.docs) {
      final reelData = doc.data();
      final caption = reelData['caption']?.toString().toLowerCase() ?? '';

      if (caption.contains(query)) {
        reelData['id'] = doc.id;
        reelData['type'] = 'reel';
        results.add(reelData);
      }
    }

    setState(() {
      _searchResults = results;
    });
  }

  void _navigateToProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ProfileScreen()),
    );
  }

  void _navigateToPost(Map<String, dynamic> postData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => PostScreen(
              username: postData['username'],
              caption: postData['caption'],
              imageUrl: postData['imageUrl'],
              postTime: postData['postTime'],
              avatarUrl: postData['avatarUrl'] ?? '',
              postId: postData['id'],
            ),
      ),
    );
  }

  void _navigateToReel(String reelId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReelsScreen(initialReelId: reelId),
      ),
    );
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
                  controller: searchController,
                  decoration: const InputDecoration(
                    hintText: 'Tìm kiếm người dùng, bài viết, reels',
                    hintStyle: TextStyle(color: Colors.grey),
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                  onSubmitted: (_) => _performSearch(),
                ),
              ),
              if (_isSearching)
                IconButton(
                  icon: Icon(Icons.clear, color: Colors.grey),
                  onPressed: () {
                    searchController.clear();
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
          child: Text(
            'Không tìm thấy kết quả cho "$_searchQuery"',
            style: TextStyle(fontSize: 16.sp),
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
              Tab(text: 'Tất cả'),
              Tab(text: 'Người dùng'),
              Tab(text: 'Bài viết/Reels'),
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
      return Center(child: Text('Không tìm thấy người dùng'));
    }

    return ListView.builder(
      itemCount: userResults.length,
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
      return Center(child: Text('Không tìm thấy bài viết hoặc reels'));
    }

    return ListView.builder(
      itemCount: contentResults.length,
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
    return ListTile(
      leading: CircleAvatar(
        backgroundImage:
            userData['avatarUrl'] != null && userData['avatarUrl'].isNotEmpty
                ? NetworkImage(userData['avatarUrl'])
                : null,
        child:
            userData['avatarUrl'] == null || userData['avatarUrl'].isEmpty
                ? const Icon(Icons.person)
                : null,
      ),
      title: Text(userData['username'] ?? 'Không có tên'),
      subtitle: Text(userData['bio'] ?? ''),
      onTap: () => _navigateToProfile(),
    );
  }

  Widget _buildPostListItem(Map<String, dynamic> postData) {
    return ListTile(
      leading: Container(
        width: 50.w,
        height: 50.h,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(5.r),
          image: DecorationImage(
            image: NetworkImage(postData['imageUrl']),
            fit: BoxFit.cover,
          ),
        ),
      ),
      title: Text('Bài viết từ ${postData['username']}'),
      subtitle: Text(
        postData['caption'],
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () => _navigateToPost(postData),
    );
  }

  Widget _buildReelListItem(Map<String, dynamic> reelData) {
    return ListTile(
      leading: Container(
        width: 50.w,
        height: 50.h,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(5.r),
        ),
        child: const Center(child: Icon(Icons.play_arrow, color: Colors.white)),
      ),
      title: Text('Reels từ ${reelData['username']}'),
      subtitle: Text(
        reelData['caption'] ?? 'Không có mô tả',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () => _navigateToReel(reelData['id']),
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
                  'Khám phá',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton.icon(
                  icon: Icon(Icons.video_library),
                  label: Text('Reels'),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => ReelsScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
        ),

        // Featured Content Sections
        _buildFeaturedSection(
          title: 'Bài viết đề xuất',
          stream:
              _firestore
                  .collection('posts')
                  .orderBy('postTime', descending: true)
                  .limit(10)
                  .snapshots(),
          itemBuilder: (BuildContext context, DocumentSnapshot doc) {
            final data = doc.data() as Map<String, dynamic>;
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => PostScreen(
                          username: data['username'],
                          caption: data['caption'],
                          imageUrl: data['imageUrl'],
                          postTime: data['postTime'],
                          avatarUrl: data['avatarUrl'] ?? '',
                          postId: doc.id,
                        ),
                  ),
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5.r),
                  color: Colors.grey.shade300,
                ),
                child: _buildCachedImage(data['imageUrl']),
              ),
            );
          },
        ),

        // Posts Grid
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
            child: Text(
              'Khám phá bài viết',
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

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => PostScreen(
                                username: data['username'],
                                caption: data['caption'],
                                imageUrl: data['imageUrl'],
                                postTime: data['postTime'],
                                avatarUrl: data['avatarUrl'] ?? '',
                                postId: doc.id,
                              ),
                        ),
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(color: Colors.grey.shade300),
                      child: _buildCachedImage(data['imageUrl']),
                    ),
                  );
                }, childCount: snapshot.data!.docs.length),
                gridDelegate: SliverQuiltedGridDelegate(
                  crossAxisCount: 3,
                  mainAxisSpacing: 3,
                  crossAxisSpacing: 3,
                  pattern: const [
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

  Widget _buildCachedImage(String imageUrl) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
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
          (context, url, error) => Center(child: Icon(Icons.error, size: 20.w)),
    );
  }
}

// Missing CachedImage Widget (implementation)
class CachedImage extends StatelessWidget {
  final String imageUrl;

  const CachedImage(this.imageUrl, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
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
          (context, url, error) => Center(child: Icon(Icons.error, size: 20.w)),
    );
  }
}
