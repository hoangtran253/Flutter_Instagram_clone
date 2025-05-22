import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class PostScreen extends StatefulWidget {
  final String username;
  final String caption;
  final String imageUrl;
  final String postTime;
  final String avatarUrl;
  final String postId; // Added postId for editing and deleting

  const PostScreen({
    super.key,
    required this.username,
    required this.caption,
    required this.imageUrl,
    required this.postTime,
    required this.avatarUrl,
    required this.postId,
  });

  @override
  State<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends State<PostScreen> {
  bool _isImageFullScreen = false;
  bool _isCurrentUserPost = false;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _captionController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();
  bool _isEditing = false;
  List<Map<String, dynamic>> _comments = [];

  @override
  void initState() {
    super.initState();
    _checkIfCurrentUserPost();
    _captionController.text = widget.caption;
    _fetchComments();
  }

  @override
  void dispose() {
    _captionController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  void _toggleFullScreen() {
    setState(() {
      _isImageFullScreen = !_isImageFullScreen;
    });
  }

  // Check if the current post belongs to the logged-in user
  Future<void> _checkIfCurrentUserPost() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        final postDoc =
            await _firestore.collection('posts').doc(widget.postId).get();

        if (postDoc.exists) {
          final postData = postDoc.data();
          setState(() {
            _isCurrentUserPost =
                postData != null && postData['uid'] == user.uid;
          });
        }
      } catch (e) {
        print('Error checking post owner: $e');
      }
    }
  }

  // Fetch comments for the post
  Future<void> _fetchComments() async {
    final postDoc =
        await _firestore.collection('posts').doc(widget.postId).get();
    if (postDoc.exists) {
      final postData = postDoc.data();
      setState(() {
        _comments = List<Map<String, dynamic>>.from(
          postData!['comments'] ?? [],
        );
      });
    }
  }

  // Add a new comment
  Future<void> _addComment() async {
    if (_commentController.text.isNotEmpty) {
      final newComment = {
        'uid': _auth.currentUser!.uid,
        'comment': _commentController.text,
        'timestamp': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('posts').doc(widget.postId).update({
        'comments': FieldValue.arrayUnion([newComment]),
      });

      _commentController.clear();
      _fetchComments(); // Refresh comments
    }
  }

  // Edit post caption
  Future<void> _updatePostCaption() async {
    try {
      await _firestore.collection('posts').doc(widget.postId).update({
        'caption': _captionController.text,
      });

      setState(() {
        _isEditing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cập nhật bài viết thành công')),
      );
    } catch (e) {
      print('Error updating post: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể cập nhật bài viết')),
      );
    }
  }

  // Delete post
  Future<void> _deletePost() async {
    try {
      await _firestore.collection('posts').doc(widget.postId).delete();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã xóa bài viết')));

      // Navigate back to previous screen
      Navigator.pop(context, true); // Pass true to indicate post was deleted
    } catch (e) {
      print('Error deleting post: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Không thể xóa bài viết')));
    }
  }

  // Show confirm dialog before deleting
  void _showDeleteConfirmDialog() {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Xóa bài viết'),
          content: const Text('Bạn có chắc chắn muốn xóa bài viết này không?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Hủy'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _deletePost();
              },
              child: const Text('Xóa', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết bài viết'),
        actions:
            _isCurrentUserPost
                ? [
                  IconButton(
                    icon: Icon(_isEditing ? Icons.check : Icons.edit),
                    onPressed: () {
                      if (_isEditing) {
                        _updatePostCaption();
                      } else {
                        setState(() {
                          _isEditing = true;
                        });
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: _showDeleteConfirmDialog,
                  ),
                ]
                : null,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header (avatar + username)
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundImage:
                          widget.avatarUrl.isNotEmpty
                              ? NetworkImage(widget.avatarUrl)
                              : null,
                      child:
                          widget.avatarUrl.isEmpty
                              ? const Icon(Icons.account_circle, size: 40)
                              : null,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      widget.username,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Image (nhấn vào zoom)
                GestureDetector(
                  onTap: _toggleFullScreen,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: widget.imageUrl,
                      width: double.infinity,
                      height: 375,
                      fit: BoxFit.cover,
                      placeholder:
                          (context, url) =>
                              const Center(child: CircularProgressIndicator()),
                      errorWidget:
                          (context, url, error) => const Icon(Icons.error),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Caption - Show text field if editing, otherwise show text
                _isEditing
                    ? TextField(
                      controller: _captionController,
                      decoration: const InputDecoration(
                        hintText: 'Nhập nội dung bài viết mới...',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    )
                    : Text(
                      widget.caption,
                      style: const TextStyle(fontSize: 14),
                    ),

                const SizedBox(height: 10),

                // Post time
                Text(
                  widget.postTime,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),

                const SizedBox(height: 20),

                // Comments Section
                const Text(
                  'Bình luận:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _comments.length,
                  itemBuilder: (context, index) {
                    final comment = _comments[index];
                    return ListTile(
                      title: Text(comment['comment']),
                      subtitle: Text(comment['uid']),
                    );
                  },
                ),

                // Comment Input
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        decoration: const InputDecoration(
                          hintText: 'Nhập bình luận...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: _addComment,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Overlay ảnh fullscreen với zoom/pan
          if (_isImageFullScreen)
            Positioned.fill(
              child: GestureDetector(
                onTap: _toggleFullScreen,
                child: Container(
                  color: Colors.black,
                  child: InteractiveViewer(
                    minScale: 1,
                    maxScale: 5,
                    child: Center(
                      child: CachedNetworkImage(
                        imageUrl: widget.imageUrl,
                        fit: BoxFit.contain,
                        placeholder:
                            (context, url) => const Center(
                              child: CircularProgressIndicator(),
                            ),
                        errorWidget:
                            (context, url, error) =>
                                const Icon(Icons.error, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
