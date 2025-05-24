import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class PostScreen extends StatefulWidget {
  final String username;
  final String caption;
  final List<String> imageUrls;
  final String postTime;
  final String avatarUrl;
  final String postId;
  final String uid; // Add uid to identify the post's owner

  const PostScreen({
    super.key,
    required this.username,
    required this.caption,
    required this.imageUrls,
    required this.postTime,
    required this.avatarUrl,
    required this.postId,
    required this.uid, // Add uid to constructor
  });

  @override
  State<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends State<PostScreen> {
  int _currentImageIndex = 0;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Delete post from Firestore
  Future<void> _deletePost() async {
    try {
      await _firestore.collection('posts').doc(widget.postId).delete();
      // Optionally delete associated images from Firebase Storage if stored
      // await FirebaseStorage.instance.ref().child('posts/${widget.postId}').delete();
      Navigator.pop(context); // Return to previous screen after deletion
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post deleted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error deleting post: $e')));
    }
  }

  // Show confirmation dialog for deletion
  void _showDeleteConfirmationDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Post'),
            content: const Text(
              'Are you sure you want to delete this post? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  _deletePost();
                },
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _auth.currentUser;
    final isOwner = currentUser != null && currentUser.uid == widget.uid;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.username.isNotEmpty ? widget.username : 'Unknown User',
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          if (isOwner) // Show More menu only for the post's owner
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.black),
              onSelected: (value) {
                if (value == 'edit') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => EditPostScreen(
                            postId: widget.postId,
                            currentCaption: widget.caption,
                            currentImageUrls: widget.imageUrls,
                          ),
                    ),
                  ).then((_) => Navigator.pop(context)); // Refresh after edit
                } else if (value == 'delete') {
                  _showDeleteConfirmationDialog();
                }
              },
              itemBuilder:
                  (context) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        'Delete',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20.r,
                  backgroundImage:
                      widget.avatarUrl.isNotEmpty
                          ? NetworkImage(widget.avatarUrl)
                          : null,
                  child:
                      widget.avatarUrl.isEmpty
                          ? Icon(Icons.account_circle, size: 40.sp)
                          : null,
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    widget.username.isNotEmpty
                        ? widget.username
                        : 'Unknown User',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              widget.imageUrls.isNotEmpty
                  ? CarouselSlider(
                    options: CarouselOptions(
                      height: 400.h,
                      viewportFraction: 1.0,
                      enableInfiniteScroll: false,
                      onPageChanged: (index, reason) {
                        setState(() {
                          _currentImageIndex = index;
                        });
                      },
                    ),
                    items:
                        widget.imageUrls.map((imageUrl) {
                          return CachedNetworkImage(
                            imageUrl: imageUrl.trim(),
                            width: double.infinity,
                            height: 400.h,
                            fit: BoxFit.cover,
                            placeholder:
                                (context, url) => Container(
                                  color: Colors.grey.shade200,
                                  child: const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                            errorWidget:
                                (context, url, error) =>
                                    const Icon(Icons.error),
                          );
                        }).toList(),
                  )
                  : Container(
                    width: double.infinity,
                    height: 400.h,
                    color: Colors.grey.shade200,
                    child: const Center(child: Icon(Icons.error)),
                  ),
              if (widget.imageUrls.length > 1)
                Positioned(
                  bottom: 10.h,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      widget.imageUrls.length,
                      (index) => Container(
                        width: 8.w,
                        height: 8.h,
                        margin: EdgeInsets.symmetric(horizontal: 4.w),
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
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            child: Text(
              widget.caption.isNotEmpty ? widget.caption : 'No caption',
              style: TextStyle(fontSize: 14.sp),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            child: Text(
              widget.postTime.isNotEmpty ? widget.postTime : 'Unknown time',
              style: TextStyle(fontSize: 12.sp, color: Colors.grey),
            ),
          ),
          // Add comments section or other interactions as needed
        ],
      ),
    );
  }
}

class EditPostScreen extends StatefulWidget {
  final String postId;
  final String currentCaption;
  final List<String> currentImageUrls;

  const EditPostScreen({
    super.key,
    required this.postId,
    required this.currentCaption,
    required this.currentImageUrls,
  });

  @override
  State<EditPostScreen> createState() => _EditPostScreenState();
}

class _EditPostScreenState extends State<EditPostScreen> {
  final TextEditingController _captionController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _captionController.text = widget.currentCaption;
  }

  Future<void> _updatePost() async {
    try {
      await _firestore.collection('posts').doc(widget.postId).update({
        'caption': _captionController.text.trim(),
        // Add logic to update imageUrls if needed (e.g., upload new images to Firebase Storage)
      });
      Navigator.pop(context); // Return to PostScreen
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post updated successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error updating post: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Post'),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          TextButton(
            onPressed: _updatePost,
            child: const Text('Save', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _captionController,
              decoration: const InputDecoration(
                labelText: 'Caption',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
            ),
            SizedBox(height: 16.h),
            // Add UI for editing images if needed (e.g., display current images, option to add/remove)
            const Text('Images:'),
            // Placeholder for image editing UI
            Text(widget.currentImageUrls.join(', ')),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }
}
