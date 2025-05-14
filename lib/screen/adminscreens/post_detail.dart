import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_instagram_clone/data/model/adminmodel.dart';

class PostDetailScreen extends StatefulWidget {
  final Map<String, dynamic> post;

  const PostDetailScreen({Key? key, required this.post}) : super(key: key);

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final AdminService _adminService = AdminService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>> _comments = [];
  bool _isLoadingComments = true;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  Future<void> _loadComments() async {
    setState(() {
      _isLoadingComments = true;
    });

    try {
      final QuerySnapshot snapshot =
          await _firestore
              .collection('comments')
              .where('postId', isEqualTo: widget.post['postId'])
              .orderBy('createdAt', descending: true)
              .get();

      setState(() {
        _comments =
            snapshot.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return {'commentId': doc.id, ...data};
            }).toList();
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load comments')));
    } finally {
      setState(() {
        _isLoadingComments = false;
      });
    }
  }

  Future<void> _deleteComment(String commentId) async {
    try {
      await _firestore.collection('comments').doc(commentId).delete();

      // Update comment count in post
      await _firestore.collection('posts').doc(widget.post['postId']).update({
        'commentCount': FieldValue.increment(-1),
      });

      setState(() {
        _comments.removeWhere((comment) => comment['commentId'] == commentId);
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Comment deleted successfully')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete comment')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final DateTime? postDate =
        widget.post['createdAt'] != null
            ? (widget.post['createdAt'] as Timestamp).toDate()
            : null;

    final String dateString =
        postDate != null
            ? '${postDate.day}/${postDate.month}/${postDate.year} ${postDate.hour}:${postDate.minute}'
            : 'Unknown date';

    return Scaffold(
      appBar: AppBar(
        title: Text('Post Details'),
        actions: [
          IconButton(
            icon: Icon(Icons.delete, color: Colors.red),
            onPressed: () => _showDeletePostConfirmation(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Post image
            if (widget.post['imageUrl'] != null &&
                widget.post['imageUrl'].isNotEmpty)
              Container(
                height: 300,
                width: double.infinity,
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: NetworkImage(widget.post['imageUrl']),
                    fit: BoxFit.cover,
                  ),
                ),
              ),

            // Post info
            Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundImage:
                            widget.post['userImageUrl'] != null &&
                                    widget.post['userImageUrl'].isNotEmpty
                                ? NetworkImage(widget.post['userImageUrl'])
                                : null,
                        child:
                            widget.post['userImageUrl'] == null ||
                                    widget.post['userImageUrl'].isEmpty
                                ? Icon(Icons.person)
                                : null,
                      ),
                      SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.post['username'] ?? 'Unknown user',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            'User ID: ${widget.post['userId']}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  SizedBox(height: 16),

                  // Caption
                  if (widget.post['caption'] != null &&
                      widget.post['caption'].isNotEmpty)
                    Text(
                      widget.post['caption'],
                      style: TextStyle(fontSize: 16),
                    ),

                  SizedBox(height: 8),

                  // Post metadata
                  Row(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.favorite, color: Colors.red),
                          SizedBox(width: 4),
                          Text('${widget.post['likes']?.length ?? 0} likes'),
                        ],
                      ),
                      SizedBox(width: 16),
                      Row(
                        children: [
                          Icon(Icons.comment),
                          SizedBox(width: 4),
                          Text('${widget.post['commentCount'] ?? 0} comments'),
                        ],
                      ),
                    ],
                  ),

                  SizedBox(height: 8),

                  Text(
                    'Posted on: $dateString',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),

                  Divider(height: 32),

                  // Comments section
                  Text(
                    'Comments',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),

                  SizedBox(height: 16),

                  _isLoadingComments
                      ? Center(child: CircularProgressIndicator())
                      : _comments.isEmpty
                      ? Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Text('No comments on this post'),
                        ),
                      )
                      : ListView.builder(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        itemCount: _comments.length,
                        itemBuilder: (context, index) {
                          final comment = _comments[index];
                          return _buildCommentTile(comment);
                        },
                      ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentTile(Map<String, dynamic> comment) {
    final DateTime? commentDate =
        comment['createdAt'] != null
            ? (comment['createdAt'] as Timestamp).toDate()
            : null;

    final String dateString =
        commentDate != null
            ? '${commentDate.day}/${commentDate.month}/${commentDate.year}'
            : '';

    return Card(
      margin: EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: EdgeInsets.all(12),
        leading: CircleAvatar(
          backgroundImage:
              comment['userImageUrl'] != null &&
                      comment['userImageUrl'].isNotEmpty
                  ? NetworkImage(comment['userImageUrl'])
                  : null,
          child:
              comment['userImageUrl'] == null || comment['userImageUrl'].isEmpty
                  ? Icon(Icons.person)
                  : null,
        ),
        title: Row(
          children: [
            Text(
              comment['username'] ?? 'Unknown',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Spacer(),
            Text(
              dateString,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [SizedBox(height: 4), Text(comment['text'] ?? '')],
        ),
        trailing: IconButton(
          icon: Icon(Icons.delete, color: Colors.red),
          onPressed: () => _showDeleteCommentConfirmation(comment),
        ),
      ),
    );
  }

  void _showDeletePostConfirmation() {
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
                    await _adminService.deletePost(widget.post['postId']);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Post deleted successfully')),
                    );
                    Navigator.pop(context); // Go back to post list
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

  void _showDeleteCommentConfirmation(Map<String, dynamic> comment) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Delete Comment'),
            content: Text(
              'Are you sure you want to delete this comment? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _deleteComment(comment['commentId']);
                },
                child: Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );
  }
}
