import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_instagram_clone/data/model/adminmodel.dart';
import 'package:flutter_instagram_clone/screen/adminscreens/post_detail.dart';

class PostsManagementScreen extends StatefulWidget {
  const PostsManagementScreen({Key? key}) : super(key: key);

  @override
  State<PostsManagementScreen> createState() => _PostsManagementScreenState();
}

class _PostsManagementScreenState extends State<PostsManagementScreen> {
  final AdminService _adminService = AdminService();
  List<Map<String, dynamic>> _posts = [];
  bool _isLoading = true;
  String _searchQuery = '';

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
      final posts = await _adminService.getAllPosts();
      setState(() {
        _posts = posts;
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load posts')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredPosts {
    if (_searchQuery.isEmpty) {
      return _posts;
    }

    return _posts.where((post) {
      final caption = post['caption']?.toString().toLowerCase() ?? '';
      final username = post['username']?.toString().toLowerCase() ?? '';
      final userId = post['userId']?.toString().toLowerCase() ?? '';

      return caption.contains(_searchQuery.toLowerCase()) ||
          username.contains(_searchQuery.toLowerCase()) ||
          userId.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Post Management'),
        actions: [IconButton(icon: Icon(Icons.refresh), onPressed: _loadPosts)],
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search posts...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          Expanded(
            child:
                _isLoading
                    ? Center(child: CircularProgressIndicator())
                    : _filteredPosts.isEmpty
                    ? Center(child: Text('No posts found'))
                    : ListView.builder(
                      itemCount: _filteredPosts.length,
                      itemBuilder: (context, index) {
                        final post = _filteredPosts[index];
                        return _buildPostCard(post);
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostCard(Map<String, dynamic> post) {
    final DateTime? postDate =
        post['createdAt'] != null
            ? (post['createdAt'] as Timestamp).toDate()
            : null;

    final String dateString =
        postDate != null
            ? '${postDate.day}/${postDate.month}/${postDate.year} ${postDate.hour}:${postDate.minute}'
            : 'Unknown date';

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Post header with user info
          ListTile(
            leading: CircleAvatar(
              backgroundImage:
                  post['userImageUrl'] != null &&
                          post['userImageUrl'].isNotEmpty
                      ? NetworkImage(post['userImageUrl'])
                      : null,
              child:
                  post['userImageUrl'] == null || post['userImageUrl'].isEmpty
                      ? Icon(Icons.person)
                      : null,
            ),
            title: Text(post['username'] ?? 'Unknown user'),
            subtitle: Text(dateString),
            trailing: IconButton(
              icon: Icon(Icons.delete, color: Colors.red),
              onPressed: () => _showDeleteConfirmation(post),
            ),
          ),

          // Post image
          if (post['imageUrl'] != null && post['imageUrl'].isNotEmpty)
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: NetworkImage(post['imageUrl']),
                  fit: BoxFit.cover,
                ),
              ),
            ),

          // Caption
          if (post['caption'] != null && post['caption'].isNotEmpty)
            Padding(
              padding: EdgeInsets.all(16),
              child: Text(post['caption'], style: TextStyle(fontSize: 16)),
            ),

          // Post actions
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Row(
                  children: [
                    Icon(Icons.favorite, color: Colors.red),
                    SizedBox(width: 4),
                    Text('${post['likes']?.length ?? 0}'),
                  ],
                ),
                SizedBox(width: 16),
                Row(
                  children: [
                    Icon(Icons.comment),
                    SizedBox(width: 4),
                    Text('${post['commentCount'] ?? 0}'),
                  ],
                ),
                Spacer(),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PostDetailScreen(post: post),
                      ),
                    ).then((_) => _loadPosts());
                  },
                  child: Text('View Details'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(Map<String, dynamic> post) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Delete Post'),
            content: Text(
              'Are you sure you want to delete this post? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  try {
                    await _adminService.deletePost(post['postId']);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Post deleted successfully')),
                    );
                    _loadPosts();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to delete post')),
                    );
                  }
                },
                child: Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );
  }
}
