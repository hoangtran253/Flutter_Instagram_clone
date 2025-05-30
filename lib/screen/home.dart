import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_instagram_clone/screen/chatlist_screen.dart';
import 'package:flutter_instagram_clone/screen/notifications_screen.dart';
import 'package:flutter_instagram_clone/widgets/post_widget.dart';
import 'package:flutter_instagram_clone/widgets/notifications.dart';
import 'package:flutter_instagram_clone/widgets/story_bar.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final NotificationService _notificationService = NotificationService();

  String _getTimeAgo(dynamic timestamp) {
    if (timestamp == null) return '';

    DateTime postTime;
    if (timestamp is Timestamp) {
      postTime = timestamp.toDate();
    } else if (timestamp is DateTime) {
      postTime = timestamp;
    } else {
      return '';
    }

    final now = DateTime.now();
    final difference = now.difference(postTime);

    if (difference.inDays > 365) {
      return '${difference.inDays ~/ 365} năm trước';
    } else if (difference.inDays > 30) {
      return '${difference.inDays ~/ 30} tháng trước';
    } else if (difference.inDays > 7) {
      return '${difference.inDays ~/ 7} tuần trước';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} ngày trước';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} giờ trước';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} phút trước';
    } else {
      return 'Vừa xong';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(55.h),
        child: AppBar(
          elevation: 0.5,
          backgroundColor: Colors.white,
          centerTitle: true,
          title: Container(
            margin: EdgeInsets.only(top: 140, bottom: 140, right: 115),
            child: Image.asset('images/instagram.png', fit: BoxFit.contain),
          ),

          actions: [
            Stack(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.notifications_none,
                    color: Colors.black,
                    size: 28,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => NotificationsScreen(),
                      ),
                    );
                  },
                ),
                StreamBuilder<QuerySnapshot>(
                  stream:
                      FirebaseFirestore.instance
                          .collection('users')
                          .doc(FirebaseAuth.instance.currentUser?.uid)
                          .collection('notifications')
                          .where('isRead', isEqualTo: false)
                          .snapshots(),
                  builder: (context, snapshot) {
                    final unreadCount = snapshot.data?.docs.length ?? 0;
                    if (unreadCount == 0) return SizedBox();
                    return Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          unreadCount > 99 ? '99+' : unreadCount.toString(),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            IconButton(
              icon: Image.asset(
                'images/message.png',
                fit: BoxFit.cover,
                height: 28.h,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ChatListScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('posts')
                .orderBy('postTime', descending: true)
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            );
          }

          final posts = snapshot.data?.docs ?? [];

          return RefreshIndicator(
            onRefresh: () async {
              await Future.delayed(const Duration(milliseconds: 500));
            },
            child: ListView.builder(
              padding: EdgeInsets.symmetric(vertical: 10.h),
              itemCount: posts.isEmpty ? 2 : posts.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Container(
                    height: 140.h,
                    child: StoryBar(
                      onStoryAdded: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Đã thêm tin mới')),
                        );
                      },
                    ),
                  );
                }

                if (posts.isEmpty) {
                  return Center(
                    child: Column(
                      children: [
                        SizedBox(height: 30.h),
                        Icon(
                          Icons.photo_library_outlined,
                          size: 64.sp,
                          color: Colors.grey.shade400,
                        ),
                        SizedBox(height: 16.h),
                        Text(
                          "Chưa có bài viết nào",
                          style: TextStyle(
                            fontSize: 16.sp,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          "Hãy theo dõi ai đó để xem bài viết của họ",
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final post = posts[index - 1].data() as Map<String, dynamic>;
                final data = posts[index - 1].data() as Map<String, dynamic>;
                final timestamp = post['postTime'];

                return Padding(
                  padding: EdgeInsets.only(bottom: 12.h),
                  child: PostWidget(
                    uid: post['uid'] ?? '',
                    postId: post['postId'] ?? '',
                    username: post['username'] ?? '',
                    caption: post['caption'] ?? '',
                    imageUrls: List<String>.from(data['imageUrls'] ?? []),
                    avatarUrl: post['avatarUrl'] ?? '',
                    postTime: _getTimeAgo(timestamp),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
