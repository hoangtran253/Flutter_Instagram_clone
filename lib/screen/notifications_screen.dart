import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_instagram_clone/screen/authprofile_screen.dart';
import 'package:flutter_instagram_clone/screen/post_screen.dart';
import 'package:flutter_instagram_clone/screen/storyviewer_screen.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  // Lấy thông tin người dùng từ Firestore dựa trên UID
  Future<Map<String, dynamic>?> _fetchUserData(String uid) async {
    try {
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        data['uid'] = uid;
        return data;
      }
      return null;
    } catch (e) {
      print('Error fetching user data for UID $uid: $e');
      return null;
    }
  }

  // Đánh dấu tất cả thông báo là đã đọc
  Future<void> _markAllAsRead(String userId) async {
    try {
      final notifications =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('notifications')
              .where('isRead', isEqualTo: false)
              .get();

      final batch = FirebaseFirestore.instance.batch();
      for (var doc in notifications.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      print('Error marking all notifications as read: $e');
    }
  }

  // Xóa thông báo
  Future<void> _deleteNotification(DocumentReference notifRef) async {
    try {
      await notifRef.delete();
    } catch (e) {
      print('Error deleting notification: $e');
    }
  }

  String _notificationMessage(Map<String, dynamic> notif, String username) {
    final type = notif['type'] ?? 'unknown';
    final payload = notif['payload'] ?? {};
    final displayUsername = username.isNotEmpty ? username : 'Người dùng';
    switch (type) {
      case 'like':
        return '$displayUsername đã thích bài viết của bạn';
      case 'comment':
        return '$displayUsername đã bình luận: "${payload['comment'] ?? ''}"';
      case 'follow':
        return '$displayUsername đã theo dõi bạn';
      case 'share':
        return '$displayUsername đã chia sẻ bài viết của bạn';
      case 'likeStory': // Thêm case cho likeStory
        return '$displayUsername đã thích story của bạn';
      default:
        return 'Bạn có thông báo mới';
    }
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'like':
        return Icons.favorite;
      case 'comment':
        return Icons.comment;
      case 'follow':
        return Icons.person_add;
      case 'share':
        return Icons.share;
      case 'likeStory': // Thêm icon cho likeStory
        return Icons.favorite_border;
      default:
        return Icons.notifications;
    }
  }

  String _timeAgo(dynamic timestamp) {
    DateTime time;
    try {
      if (timestamp is Timestamp) {
        time = timestamp.toDate();
      } else if (timestamp is DateTime) {
        time = timestamp;
      } else {
        return 'Vừa xong'; // Fallback if timestamp is invalid
      }
    } catch (e) {
      print('Error converting timestamp: $e');
      return 'Vừa xong'; // Fallback on error
    }
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inDays > 7) return '${diff.inDays ~/ 7} tuần';
    if (diff.inDays > 0) return '${diff.inDays} ngày';
    if (diff.inHours > 0) return '${diff.inHours} giờ';
    if (diff.inMinutes > 0) return '${diff.inMinutes} phút';
    return 'Vừa xong';
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Thông báo'), centerTitle: true),
        body: const Center(child: Text('Bạn cần đăng nhập để xem thông báo')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông báo'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: 'Đánh dấu tất cả đã đọc',
            onPressed: () async {
              await _markAllAsRead(currentUser.uid);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Đã đánh dấu tất cả thông báo là đã đọc'),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('users')
                .doc(currentUser.uid)
                .collection('notifications')
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Lỗi khi tải thông báo'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Không có thông báo nào'));
          }

          final notifs = snapshot.data!.docs;

          // Sắp xếp danh sách notifs theo timestamp giảm dần (mới nhất lên đầu)
          notifs.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aTimestamp = aData['timestamp'] as Timestamp?;
            final bTimestamp = bData['timestamp'] as Timestamp?;

            // Xử lý trường hợp timestamp null
            if (aTimestamp == null && bTimestamp == null) return 0;
            if (aTimestamp == null)
              return 1; // Đẩy thông báo không có timestamp xuống dưới
            if (bTimestamp == null) return -1;

            return bTimestamp.compareTo(aTimestamp); // Sắp xếp giảm dần
          });

          return ListView.builder(
            itemCount: notifs.length,
            itemBuilder: (context, index) {
              final notif = notifs[index];
              final data = notif.data() as Map<String, dynamic>;
              final payload = data['payload'] ?? {};
              final fromUid = payload['fromUid'] ?? '';
              final isRead = data['isRead'] == true;

              return Dismissible(
                key: Key(notif.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                confirmDismiss: (direction) async {
                  return await showDialog<bool>(
                        context: context,
                        builder:
                            (context) => AlertDialog(
                              title: const Text('Xóa thông báo'),
                              content: const Text(
                                'Bạn có chắc muốn xóa thông báo này?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed:
                                      () => Navigator.pop(context, false),
                                  child: const Text('Hủy'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text(
                                    'Xóa',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                      ) ??
                      false;
                },
                onDismissed: (direction) {
                  _deleteNotification(notif.reference);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã xóa thông báo')),
                  );
                },
                child: FutureBuilder<Map<String, dynamic>?>(
                  future: _fetchUserData(fromUid),
                  builder: (context, userSnapshot) {
                    String username = 'Người dùng';
                    String avatar = '';

                    if (userSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const ListTile(
                        leading: CircularProgressIndicator(strokeWidth: 2),
                        title: Text('Đang tải...'),
                      );
                    }
                    if (userSnapshot.hasData && userSnapshot.data != null) {
                      username = userSnapshot.data!['username'] ?? 'Người dùng';
                      avatar = userSnapshot.data!['avatarUrl'] ?? '';
                    }

                    return Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 8.h,
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          radius: 20.r,
                          backgroundColor: Colors.grey.shade300,
                          child: ClipOval(
                            child:
                                avatar.isNotEmpty
                                    ? CachedNetworkImage(
                                      imageUrl: avatar,
                                      fit: BoxFit.cover,
                                      placeholder:
                                          (context, url) => const Center(
                                            child: CircularProgressIndicator(
                                              strokeWidth: 1.5,
                                            ),
                                          ),
                                      errorWidget:
                                          (context, url, error) => const Icon(
                                            Icons.account_circle,
                                            size: 40,
                                            color: Colors.grey,
                                          ),
                                    )
                                    : const Icon(
                                      Icons.account_circle,
                                      size: 40,
                                      color: Colors.grey,
                                    ),
                          ),
                        ),
                        title: Text(
                          _notificationMessage(data, username),
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight:
                                isRead ? FontWeight.normal : FontWeight.w600,
                            color: Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle:
                            data['timestamp'] != null
                                ? Text(
                                  _timeAgo(data['timestamp']),
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    color: Colors.grey.shade600,
                                  ),
                                )
                                : const Text('Vừa xong'),
                        trailing: Icon(
                          _iconForType(data['type'] ?? ''),
                          color: Colors.blue,
                          size: 24.sp,
                        ),
                        tileColor: isRead ? Colors.white : Colors.blue[50],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        onTap: () async {
                          if (!isRead) {
                            await notif.reference.update({'isRead': true});
                          }
                          // Điều hướng dựa trên loại thông báo
                          if (data['type'] == 'follow') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => OtherUserProfileScreen(
                                      userId: fromUid,
                                      username: username,
                                    ),
                              ),
                            );
                          } else if (data['type'] == 'like' ||
                              data['type'] == 'comment' ||
                              data['type'] == 'share') {
                            final postId = payload['postId'];
                            if (postId != null) {
                              final postDoc =
                                  await FirebaseFirestore.instance
                                      .collection('posts')
                                      .doc(postId)
                                      .get();
                              if (postDoc.exists) {
                                final postData =
                                    postDoc.data() as Map<String, dynamic>;
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) => PostScreen(
                                          username: postData['username'] ?? '',
                                          caption: postData['caption'] ?? '',
                                          imageUrls: List<String>.from(
                                            postData['imageUrls'] ?? [],
                                          ),
                                          postTime:
                                              postData['postTime'] is Timestamp
                                                  ? _timeAgo(
                                                    postData['postTime'],
                                                  )
                                                  : (postData['postTime']
                                                          ?.toString() ??
                                                      ''),
                                          avatarUrl:
                                              postData['avatarUrl'] ?? '',
                                          postId: postId,
                                          uid: postData['uid'] ?? '',
                                        ),
                                  ),
                                );
                              }
                            }
                          } else if (data['type'] == 'likeStory') {
                            final storyId = payload['storyId'];
                            if (storyId != null) {
                              final storyDoc =
                                  await FirebaseFirestore.instance
                                      .collection('stories')
                                      .doc(storyId)
                                      .get();
                              if (storyDoc.exists) {
                                final storyData =
                                    storyDoc.data() as Map<String, dynamic>;
                                final expirationTime =
                                    storyData['expirationTime'] as Timestamp?;
                                if (expirationTime != null &&
                                    expirationTime.toDate().isBefore(
                                      DateTime.now(),
                                    )) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Story này đã hết hạn'),
                                    ),
                                  );
                                  return;
                                }

                                final userId = storyData['userId'];
                                final storiesSnapshot =
                                    await FirebaseFirestore.instance
                                        .collection('stories')
                                        .where(
                                          'expirationTime',
                                          isGreaterThan: Timestamp.now(),
                                        )
                                        .get();

                                List<Map<String, dynamic>> allUsers = [];
                                Map<String, List<Map<String, dynamic>>>
                                userStoriesMap = {};

                                for (var doc in storiesSnapshot.docs) {
                                  final story = doc.data();
                                  final userId = story['userId'];
                                  if (!userStoriesMap.containsKey(userId)) {
                                    userStoriesMap[userId] = [];
                                  }
                                  userStoriesMap[userId]!.add({
                                    'storyId': doc.id,
                                    ...story,
                                  });
                                }

                                for (var userId in userStoriesMap.keys) {
                                  final userDoc =
                                      await FirebaseFirestore.instance
                                          .collection('users')
                                          .doc(userId)
                                          .get();
                                  if (userDoc.exists) {
                                    final userData =
                                        userDoc.data() as Map<String, dynamic>;
                                    allUsers.add({
                                      'userId': userId,
                                      'username': userData['username'] ?? '',
                                      'avatarUrl': userData['avatarUrl'] ?? '',
                                      'stories': userStoriesMap[userId]!,
                                    });
                                  }
                                }

                                final initialUserData = allUsers.firstWhere(
                                  (user) => user['userId'] == userId,
                                  orElse: () => {},
                                );

                                if (initialUserData.isNotEmpty) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (context) => StoryViewerScreen(
                                            initialUserData: initialUserData,
                                            allUsers: allUsers,
                                          ),
                                    ),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Không tìm thấy story'),
                                    ),
                                  );
                                }
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Story không tồn tại'),
                                  ),
                                );
                              }
                            }
                          }
                        },
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
