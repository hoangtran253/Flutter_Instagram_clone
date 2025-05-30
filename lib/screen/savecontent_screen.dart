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

class SavedContentScreen extends StatelessWidget {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  SavedContentScreen({super.key});

  Widget _buildSavedPosts(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream:
          _firestore
              .collection('users')
              .doc(_auth.currentUser!.uid)
              .collection('saved')
              .orderBy('savedAt', descending: true)
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
                Icon(Icons.bookmark_border, size: 80, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'Chưa có bài viết nào được lưu',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  'Lưu các bài viết yêu thích để xem lại sau',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final savedPosts = snapshot.data!.docs;

        return GridView.builder(
          padding: EdgeInsets.all(2.w),
          itemCount: savedPosts.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
          ),
          itemBuilder: (context, index) {
            final savedPost = savedPosts[index].data() as Map<String, dynamic>;
            final imageUrls = List<String>.from(savedPost['imageUrls'] ?? []);
            final firstImageUrl = imageUrls.isNotEmpty ? imageUrls[0] : null;
            final isMultiImage = imageUrls.length > 1;

            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (_) => PostScreen(
                          uid: savedPost['uid'] ?? '',
                          postId: savedPost['postId'] ?? '',
                          username: savedPost['username'] ?? '',
                          caption: savedPost['caption'] ?? '',
                          imageUrls: imageUrls,
                          postTime:
                              savedPost['postTime'] != null
                                  ? _formatTimestamp(
                                    savedPost['postTime'] as Timestamp,
                                  )
                                  : 'Thời gian không xác định',
                          avatarUrl: savedPost['avatarUrl'] ?? '',
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
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ),
                              errorWidget:
                                  (context, url, error) => Container(
                                    color: Colors.grey[300],
                                    child: const Icon(
                                      Icons.image_not_supported,
                                    ),
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
                      child: Icon(
                        Icons.collections,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  const Positioned(
                    left: 4,
                    bottom: 4,
                    child: Icon(Icons.bookmark, color: Colors.yellow, size: 16),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSavedReels(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream:
          _firestore
              .collection('users')
              .doc(_auth.currentUser!.uid)
              .collection('savedReels')
              .orderBy('savedAt', descending: true)
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
                Icon(Icons.bookmark_border, size: 80, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'Chưa có video nào được lưu',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  'Lưu các video yêu thích để xem lại sau',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final savedReels = snapshot.data!.docs;

        return GridView.builder(
          padding: EdgeInsets.all(2.w),
          itemCount: savedReels.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
          ),
          itemBuilder: (context, index) {
            final savedReelDoc = savedReels[index];
            final savedReel = savedReelDoc.data() as Map<String, dynamic>;
            final videoUrl = savedReel['videoUrl'] ?? '';
            final thumbnailUrl = savedReel['thumbnailUrl'] ?? '';
            final caption = savedReel['caption'] ?? '';

            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => ReelDetailScreen(
                          doc: savedReelDoc.id,
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
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.w,
                                ),
                              ),
                            ),
                        errorWidget:
                            (context, url, error) =>
                                Center(child: Icon(Icons.error, size: 20.w)),
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
                      size: 24,
                    ),
                  ),
                  const Positioned(
                    left: 4,
                    bottom: 4,
                    child: Icon(Icons.bookmark, color: Colors.yellow, size: 16),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nội dung đã lưu'),
        backgroundColor: Colors.white,
        elevation: 1.5,
      ),
      body: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            const TabBar(
              indicatorColor: Colors.black,
              labelColor: Colors.black,
              unselectedLabelColor: Colors.grey,
              tabs: [Tab(text: 'Bài viết'), Tab(text: 'Reels')],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildSavedPosts(context),
                  _buildSavedReels(context),
                ],
              ),
            ),
          ],
        ),
      ),
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
