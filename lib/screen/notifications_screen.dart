import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_instagram_clone/widgets/notifications.dart';
import 'package:flutter_instagram_clone/screen/post_screen.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final NotificationService _notificationService = NotificationService();

  String _getTimeAgo(dynamic timestamp) {
    if (timestamp == null) return '';

    DateTime notificationTime;
    if (timestamp is Timestamp) {
      notificationTime = timestamp.toDate();
    } else if (timestamp is DateTime) {
      notificationTime = timestamp;
    } else {
      return '';
    }

    final now = DateTime.now();
    final difference = now.difference(notificationTime);

    if (difference.inDays > 7) {
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

  Widget _getNotificationIcon(String type) {
    switch (type) {
      case NotificationService.LIKE_POST:
      case NotificationService.LIKE_COMMENT:
        return Icon(Icons.favorite, color: Colors.red, size: 24.sp);
      case NotificationService.COMMENT_POST:
      case NotificationService.REPLY_COMMENT:
        return Icon(Icons.comment, color: Colors.blue, size: 24.sp);
      case NotificationService.FOLLOW_USER:
        return Icon(Icons.person_add, color: Colors.green, size: 24.sp);
      default:
        return Icon(Icons.notifications, color: Colors.grey, size: 24.sp);
    }
  }

  Future<void> _navigateToPost(String? postId) async {
    if (postId == null || postId.isEmpty) return;

    try {
      final postDoc =
          await FirebaseFirestore.instance
              .collection('posts')
              .doc(postId)
              .get();

      if (postDoc.exists && mounted) {
        final postData = postDoc.data() as Map<String, dynamic>;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => PostScreen(
                  uid: postData['uid'],
                  postId: postId,
                  username: postData['username'] ?? '',
                  caption: postData['caption'] ?? '',
                  imageUrls: postData['imageUrl'] ?? '',
                  postTime: _getTimeAgo(postData['postTime']),
                  avatarUrl: postData['avatarUrl'] ?? '',
                ),
          ),
        );
      }
    } catch (e) {
      print('Error navigating to post: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không thể mở bài viết')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Thông báo',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => _notificationService.markAllAsRead(),
            child: Text(
              'Đánh dấu tất cả',
              style: TextStyle(color: Colors.blue, fontSize: 14.sp),
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _notificationService.getNotifications(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 64.sp,
                    color: Colors.grey.shade400,
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    'Chưa có thông báo nào',
                    style: TextStyle(
                      fontSize: 16.sp,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            );
          }

          final notifications = snapshot.data!.docs;

          return ListView.separated(
            padding: EdgeInsets.symmetric(vertical: 8.h),
            itemCount: notifications.length,
            separatorBuilder: (_, __) => Divider(height: 1),
            itemBuilder: (context, index) {
              final notification = notifications[index];
              final data = notification.data() as Map<String, dynamic>;
              final isRead = data['isRead'] ?? false;

              return Container(
                color: isRead ? Colors.white : Colors.blue.shade50,
                child: ListTile(
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 8.h,
                  ),
                  leading: Stack(
                    children: [
                      CircleAvatar(
                        radius: 24.r,
                        backgroundColor: Colors.grey.shade300,
                        backgroundImage:
                            data['senderAvatarUrl'] != null &&
                                    data['senderAvatarUrl'].isNotEmpty
                                ? CachedNetworkImageProvider(
                                  data['senderAvatarUrl'],
                                )
                                : null,
                        child:
                            data['senderAvatarUrl'] == null ||
                                    data['senderAvatarUrl'].isEmpty
                                ? Icon(Icons.account_circle, size: 32.sp)
                                : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: EdgeInsets.all(2.w),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: _getNotificationIcon(data['type'] ?? ''),
                        ),
                      ),
                    ],
                  ),
                  title: RichText(
                    text: TextSpan(
                      style: TextStyle(color: Colors.black, fontSize: 14.sp),
                      children: [
                        TextSpan(
                          text: data['senderUsername'] ?? 'Unknown User',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        TextSpan(text: ' ${data['message'] ?? ''}'),
                      ],
                    ),
                  ),
                  subtitle: Text(
                    _getTimeAgo(data['timestamp']),
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  trailing:
                      !isRead
                          ? Container(
                            width: 8.w,
                            height: 8.w,
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                            ),
                          )
                          : null,
                  onTap: () async {
                    // Mark as read
                    if (!isRead) {
                      await _notificationService.markAsRead(notification.id);
                    }

                    // Navigate based on notification type
                    final type = data['type'] ?? '';
                    final postId = data['postId'];

                    if (type == NotificationService.LIKE_POST ||
                        type == NotificationService.COMMENT_POST ||
                        type == NotificationService.LIKE_COMMENT ||
                        type == NotificationService.REPLY_COMMENT) {
                      await _navigateToPost(postId);
                    }
                    // For follow notifications, you might want to navigate to user profile
                  },
                  onLongPress: () {
                    showModalBottomSheet(
                      context: context,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(16.r),
                        ),
                      ),
                      builder:
                          (context) => Padding(
                            padding: EdgeInsets.all(16.w),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ListTile(
                                  leading: Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  title: Text('Xóa thông báo'),
                                  onTap: () async {
                                    Navigator.pop(context);
                                    await _notificationService
                                        .deleteNotification(notification.id);
                                  },
                                ),
                                if (!isRead)
                                  ListTile(
                                    leading: Icon(Icons.mark_email_read),
                                    title: Text('Đánh dấu đã đọc'),
                                    onTap: () async {
                                      Navigator.pop(context);
                                      await _notificationService.markAsRead(
                                        notification.id,
                                      );
                                    },
                                  ),
                              ],
                            ),
                          ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
