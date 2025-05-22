import 'package:flutter/material.dart';
import 'package:flutter_instagram_clone/data/model/adminmodel.dart';
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
            return post['caption'].toString().toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ) ||
                post['username'].toString().toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                );
          }).toList();

      // Sort posts
      _filteredPosts.sort((a, b) {
        final DateTime aTime = a['postTime'].toDate();
        final DateTime bTime = b['postTime'].toDate();
        return _sortBy == 'newest'
            ? bTime.compareTo(aTime)
            : aTime.compareTo(bTime);
      });
    });
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
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
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
                        backgroundImage:
                            post['avatarUrl'] != null
                                ? NetworkImage(post['avatarUrl'])
                                : null,
                        child:
                            post['avatarUrl'] == null
                                ? Text(post['username'][0].toUpperCase())
                                : null,
                      ),
                      SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            post['username'],
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            DateFormat(
                              'MMM d, yyyy - HH:mm',
                            ).format(post['postTime'].toDate()),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      Spacer(),
                      IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          Navigator.of(context).pop();
                          _deletePost(post['postId'], post['username']);
                        },
                        tooltip: 'Delete Post',
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  if (post['imageUrl'] != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        post['imageUrl'],
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: 300,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            height: 300,
                            width: double.infinity,
                            color: Colors.grey[200],
                            child: Center(
                              child: CircularProgressIndicator(
                                value:
                                    loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress
                                                .cumulativeBytesLoaded /
                                            loadingProgress.expectedTotalBytes!
                                        : null,
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 300,
                            width: double.infinity,
                            color: Colors.grey[200],
                            child: Center(
                              child: Icon(
                                Icons.error,
                                color: Colors.red,
                                size: 48,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  SizedBox(height: 16),
                  Text(post['caption'] ?? '', style: TextStyle(fontSize: 16)),
                  SizedBox(height: 16),
                  Text(
                    'Post ID: ${post['postId']}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  Text(
                    'User ID: ${post['uid']}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  SizedBox(height: 16),
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
                        padding: EdgeInsets.all(8),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 1,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: _filteredPosts.length,
                        itemBuilder: (context, index) {
                          final post = _filteredPosts[index];
                          return GestureDetector(
                            onTap: () => _showPostDetails(post),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child:
                                      post['imageUrl'] != null
                                          ? Image.network(
                                            post['imageUrl'],
                                            fit: BoxFit.cover,
                                            loadingBuilder: (
                                              context,
                                              child,
                                              loadingProgress,
                                            ) {
                                              if (loadingProgress == null)
                                                return child;
                                              return Container(
                                                color: Colors.grey[200],
                                                child: Center(
                                                  child: CircularProgressIndicator(
                                                    value:
                                                        loadingProgress
                                                                    .expectedTotalBytes !=
                                                                null
                                                            ? loadingProgress
                                                                    .cumulativeBytesLoaded /
                                                                loadingProgress
                                                                    .expectedTotalBytes!
                                                            : null,
                                                  ),
                                                ),
                                              );
                                            },
                                            errorBuilder: (
                                              context,
                                              error,
                                              stackTrace,
                                            ) {
                                              return Container(
                                                color: Colors.grey[200],
                                                child: Center(
                                                  child: Icon(
                                                    Icons.error,
                                                    color: Colors.red,
                                                  ),
                                                ),
                                              );
                                            },
                                          )
                                          : Container(
                                            color: Colors.grey[200],
                                            child: Center(
                                              child: Icon(
                                                Icons.photo,
                                                color: Colors.grey[400],
                                              ),
                                            ),
                                          ),
                                ),
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
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
                                      borderRadius: BorderRadius.only(
                                        bottomLeft: Radius.circular(8),
                                        bottomRight: Radius.circular(8),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            post['username'],
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            Icons.delete_outline,
                                            color: Colors.white,
                                            size: 18,
                                          ),
                                          onPressed:
                                              () => _deletePost(
                                                post['postId'],
                                                post['username'],
                                              ),
                                          constraints: BoxConstraints(),
                                          padding: EdgeInsets.all(0),
                                          tooltip: 'Delete Post',
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
