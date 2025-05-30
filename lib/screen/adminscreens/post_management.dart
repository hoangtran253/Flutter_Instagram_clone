import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_instagram_clone/data/model/adminmodel.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

class PostsManagementPage extends StatefulWidget {
  final AdminService adminService;

  const PostsManagementPage({Key? key, required this.adminService})
    : super(key: key);

  @override
  _PostsManagementPageState createState() => _PostsManagementPageState();
}

class _PostsManagementPageState extends State<PostsManagementPage> {
  List<Map<String, dynamic>> _posts = [];
  List<Map<String, dynamic>> _filteredPosts = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _sortBy = 'newest'; // 'newest', 'oldest'

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final posts = await widget.adminService.getAllPosts();
      setState(() {
        _posts = posts;
        _filterAndSortPosts();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading posts: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load posts')));
    }
  }

  void _filterAndSortPosts() {
    setState(() {
      // Filter posts
      _filteredPosts =
          _posts.where((post) {
            final caption = post['caption']?.toString() ?? '';
            final username = post['username']?.toString() ?? '';
            return caption.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                username.toLowerCase().contains(_searchQuery.toLowerCase());
          }).toList();

      _filteredPosts.sort((a, b) {
        final DateTime aTime = a['postTime'].toDate();
        final DateTime bTime = b['postTime'].toDate();
        return _sortBy == 'newest'
            ? bTime.compareTo(aTime)
            : aTime.compareTo(bTime);
      });
    });
  }

  // Helper method to safely get imageUrls as List<String>
  List<String> _getImageUrls(Map<String, dynamic> post) {
    final imageUrls = post['imageUrls'];

    if (imageUrls == null || imageUrls is! List) {
      print('Post imageUrls is null or not a list');
      return [];
    }

    return List<String>.from(imageUrls);
  }

  Future<void> _deletePost(String postId, String username) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Delete Post'),
            content: Text(
              'Are you sure you want to delete this post by $username?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('CANCEL'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text('DELETE'),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      setState(() {
        _isLoading = true;
      });
      try {
        await widget.adminService.deletePost(postId);
        await _loadPosts();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Post deleted successfully')));
      } catch (e) {
        print('Error deleting post: $e');
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to delete post')));
      }
    }
  }

  void _showPostDetails(Map<String, dynamic> post) {
    int _currentImageIndex = 0;
    final imageUrls = _getImageUrls(post);

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setDialogState) {
              return Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.7,
                  padding: EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 20.r,
                            backgroundImage:
                                post['avatarUrl'] != null &&
                                        post['avatarUrl'].toString().isNotEmpty
                                    ? NetworkImage(post['avatarUrl'])
                                    : null,
                            child:
                                post['avatarUrl'] == null ||
                                        post['avatarUrl'].toString().isEmpty
                                    ? Text(
                                      (post['username']?.toString() ?? 'U')[0]
                                          .toUpperCase(),
                                    )
                                    : null,
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  post['username']?.toString() ??
                                      'Unknown User',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16.sp,
                                  ),
                                ),
                                Text(
                                  DateFormat(
                                    'MMM d, yyyy - HH:mm',
                                  ).format(post['postTime'].toDate()),
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12.sp,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              Navigator.of(context).pop();
                              _deletePost(
                                post['postId'],
                                post['username'] ?? 'Unknown',
                              );
                            },
                            tooltip: 'Delete Post',
                          ),
                        ],
                      ),
                      SizedBox(height: 16.h),
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          imageUrls.isNotEmpty
                              ? CarouselSlider(
                                options: CarouselOptions(
                                  height: 300.h,
                                  viewportFraction: 1.0,
                                  enableInfiniteScroll: false,
                                  onPageChanged: (index, reason) {
                                    setDialogState(() {
                                      _currentImageIndex = index;
                                    });
                                  },
                                ),
                                items:
                                    imageUrls.map((imageUrl) {
                                      return CachedNetworkImage(
                                        imageUrl: imageUrl,
                                        width: double.infinity,
                                        height: 300.h,
                                        fit: BoxFit.cover,
                                        placeholder:
                                            (context, url) => Container(
                                              color: Colors.grey.shade200,
                                              child: Center(
                                                child:
                                                    CircularProgressIndicator(),
                                              ),
                                            ),
                                        errorWidget:
                                            (context, url, error) => Container(
                                              color: Colors.grey.shade200,
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Icon(Icons.error, size: 40),
                                                  SizedBox(height: 8),
                                                  Text(
                                                    'Failed to load image',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                      );
                                    }).toList(),
                              )
                              : Container(
                                width: double.infinity,
                                height: 300.h,
                                color: Colors.grey.shade200,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.image_not_supported, size: 40),
                                    SizedBox(height: 8),
                                    Text('No images available'),
                                  ],
                                ),
                              ),
                          if (imageUrls.length > 1)
                            Positioned(
                              bottom: 10.h,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(
                                  imageUrls.length,
                                  (index) => Container(
                                    width: 8.w,
                                    height: 8.h,
                                    margin: EdgeInsets.symmetric(
                                      horizontal: 4.w,
                                    ),
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
                      SizedBox(height: 16.h),
                      Text(
                        post['caption']?.toString() ?? 'No caption',
                        style: TextStyle(fontSize: 16.sp),
                      ),
                      SizedBox(height: 16.h),
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Post ID: ${post['postId'] ?? 'N/A'}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12.sp,
                              ),
                            ),
                            Text(
                              'User ID: ${post['uid'] ?? 'N/A'}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12.sp,
                              ),
                            ),
                            Text(
                              'Images: ${imageUrls.length}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12.sp,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 16.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text('CLOSE'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Posts Management',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 16),
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by caption or username',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                      _filterAndSortPosts();
                    });
                  },
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    ChoiceChip(
                      label: Text('Newest First'),
                      selected: _sortBy == 'newest',
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _sortBy = 'newest';
                            _filterAndSortPosts();
                          });
                        }
                      },
                    ),
                    SizedBox(width: 8),
                    ChoiceChip(
                      label: Text('Oldest First'),
                      selected: _sortBy == 'oldest',
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _sortBy = 'oldest';
                            _filterAndSortPosts();
                          });
                        }
                      },
                    ),
                    Spacer(),
                    Text(
                      '${_filteredPosts.length} posts',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child:
                _isLoading
                    ? Center(child: CircularProgressIndicator())
                    : _filteredPosts.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.photo_library_outlined,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No posts found',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                    : RefreshIndicator(
                      onRefresh: _loadPosts,
                      child: GridView.builder(
                        padding: EdgeInsets.all(2.w),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 1,
                          crossAxisSpacing: 2.w,
                          mainAxisSpacing: 2.h,
                        ),
                        itemCount: _filteredPosts.length,
                        itemBuilder: (context, index) {
                          final post = _filteredPosts[index];
                          final imageUrls = _getImageUrls(post);
                          final firstImageUrl =
                              imageUrls.isNotEmpty ? imageUrls[0] : null;
                          final isMultiImage = imageUrls.length > 1;

                          return GestureDetector(
                            onTap: () => _showPostDetails(post),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                firstImageUrl != null
                                    ? CachedNetworkImage(
                                      imageUrl: firstImageUrl,
                                      fit: BoxFit.cover,
                                      placeholder:
                                          (context, url) => Container(
                                            color: Colors.grey[300],
                                            child: Center(
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.w,
                                              ),
                                            ),
                                          ),
                                      errorWidget:
                                          (context, url, error) => Container(
                                            color: Colors.grey[300],
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(Icons.image_not_supported),
                                                Text(
                                                  'Error',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                    )
                                    : Container(
                                      color: Colors.grey[300],
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.image_not_supported),
                                          Text(
                                            'No Image',
                                            style: TextStyle(fontSize: 10),
                                          ),
                                        ],
                                      ),
                                    ),
                                if (isMultiImage)
                                  Positioned(
                                    right: 4.w,
                                    top: 4.h,
                                    child: Container(
                                      padding: EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.7),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Icon(
                                        Icons.collections,
                                        color: Colors.white,
                                        size: 16.sp,
                                      ),
                                    ),
                                  ),
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8.w,
                                      vertical: 4.h,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                        colors: [
                                          Colors.black.withOpacity(0.7),
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            post['username']?.toString() ??
                                                'Unknown User',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12.sp,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap:
                                              () => _deletePost(
                                                post['postId'],
                                                post['username']?.toString() ??
                                                    'Unknown',
                                              ),
                                          child: Container(
                                            padding: EdgeInsets.all(4.w),
                                            child: Icon(
                                              Icons.delete_outline,
                                              color: Colors.white,
                                              size: 18.sp,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadPosts,
        child: Icon(Icons.refresh),
        tooltip: 'Refresh',
      ),
    );
  }
}
