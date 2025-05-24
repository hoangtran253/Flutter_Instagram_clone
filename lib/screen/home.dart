import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_instagram_clone/screen/chatlist_screen.dart';
import 'package:flutter_instagram_clone/widgets/post_widget.dart';
import 'package:flutter_instagram_clone/screen/notifications_screen.dart';
import 'package:flutter_instagram_clone/widgets/notifications.dart';
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
          elevation: 0,
          backgroundColor: Colors.white,
          centerTitle: true,
          title: Container(
            margin: EdgeInsets.only(top: 130, bottom: 130, right: 100),
            child: Image.asset('images/instagram.png', fit: BoxFit.contain),
          ),

          actions: [
            Stack(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.notifications_none,
                    color: Colors.black,
                    size: 26,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => NotificationScreen(),
                      ),
                    );
                  },
                ),
                StreamBuilder<int>(
                  stream: _notificationService.getUnreadCount(),
                  builder: (context, snapshot) {
                    final unreadCount = snapshot.data ?? 0;
                    if (unreadCount == 0) return SizedBox();

                    return Positioned(
                      right: 8.w,
                      top: 8.h,
                      child: Container(
                        padding: EdgeInsets.all(2.w),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        constraints: BoxConstraints(
                          minWidth: 16.w,
                          minHeight: 16.h,
                        ),
                        child: Text(
                          unreadCount > 99 ? '99+' : unreadCount.toString(),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10.sp,
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
              icon: Image.asset('images/message.png', fit: BoxFit.cover),
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

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
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

          final posts = snapshot.data!.docs;

          return RefreshIndicator(
            onRefresh: () async {
              // Refresh will be handled automatically by StreamBuilder
              await Future.delayed(Duration(milliseconds: 500));
            },
            child: ListView.separated(
              padding: EdgeInsets.symmetric(vertical: 10.h),
              itemCount: posts.length,
              separatorBuilder: (_, __) => SizedBox(height: 12.h),
              itemBuilder: (context, index) {
                final post = posts[index].data() as Map<String, dynamic>;
                final Timestamp? timestamp = post['postTime'];
                final doc = snapshot.data!.docs[index];
                final data = doc.data() as Map<String, dynamic>;

                return PostWidget(
                  uid: post['uid'] ?? '',
                  postId: post['postId'] ?? '',
                  username: post['username'] ?? '',
                  caption: post['caption'] ?? '',
                  imageUrls: List<String>.from(data['imageUrls'] ?? []),
                  avatarUrl: post['avatarUrl'] ?? '',
                  postTime: _getTimeAgo(timestamp),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
