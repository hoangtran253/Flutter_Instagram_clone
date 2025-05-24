import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_instagram_clone/screen/chat_screen.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("Không tìm thấy người dùng")),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1.5,
        title: const Text(
          'Tin nhắn',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            _firestore
                .collection('chats')
                .where('participants', arrayContains: user.uid)
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
                  Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Chưa có tin nhắn nào',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Hãy follow và bắt đầu trò chuyện với bạn bè!',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }
          final chats = snapshot.data!.docs;

          chats.sort((a, b) {
            final aTime = a['lastMessageTime'] as Timestamp?;
            final bTime = b['lastMessageTime'] as Timestamp?;
            if (aTime == null || bTime == null) return 0;
            return bTime.compareTo(aTime);
          });

          return ListView.builder(
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final chat = chats[index].data() as Map<String, dynamic>;
              final chatId = chats[index].id;
              final participants = List<String>.from(
                chat['participants'] ?? [],
              );
              final otherUserId = participants.firstWhere(
                (id) => id != user.uid,
                orElse: () => '',
              );

              if (otherUserId.isEmpty) return const SizedBox.shrink();

              return FutureBuilder<DocumentSnapshot>(
                future: _firestore.collection('users').doc(otherUserId).get(),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData) {
                    return const ListTile(
                      leading: CircleAvatar(child: Icon(Icons.person)),
                      title: Text('Đang tải...'),
                    );
                  }

                  final userData =
                      userSnapshot.data!.data() as Map<String, dynamic>?;
                  final otherUsername = userData?['username'] ?? 'Unknown';
                  final otherAvatarUrl = userData?['avatarUrl'] ?? '';
                  final lastMessage = chat['lastMessage'] ?? '';
                  final lastMessageTime = chat['lastMessageTime'] as Timestamp?;
                  final lastMessageSenderId = chat['lastMessageSenderId'] ?? '';

                  return FutureBuilder<int>(
                    future: _getUnreadCount(chatId, user.uid),
                    builder: (context, unreadSnapshot) {
                      final unreadCount = unreadSnapshot.data ?? 0;

                      return ListTile(
                        leading: CircleAvatar(
                          radius: 24.r,
                          backgroundImage:
                              otherAvatarUrl.isNotEmpty
                                  ? NetworkImage(otherAvatarUrl)
                                  : const AssetImage('images/person.png')
                                      as ImageProvider,
                        ),
                        title: Text(
                          otherUsername,
                          style: TextStyle(
                            fontWeight:
                                unreadCount > 0
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                            fontSize: 16.sp,
                          ),
                        ),
                        subtitle: Row(
                          children: [
                            if (lastMessageSenderId == user.uid)
                              Icon(
                                Icons.done_outline,
                                size: 16.r,
                                color: Colors.grey,
                              ),
                            if (lastMessageSenderId == user.uid)
                              SizedBox(width: 4.w),
                            Expanded(
                              child: Text(
                                lastMessage,
                                style: TextStyle(
                                  color:
                                      unreadCount > 0
                                          ? Colors.black
                                          : Colors.grey,
                                  fontWeight:
                                      unreadCount > 0
                                          ? FontWeight.w500
                                          : FontWeight.normal,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (lastMessageTime != null)
                              Text(
                                _formatTimestamp(lastMessageTime),
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12.sp,
                                ),
                              ),
                            if (unreadCount > 0) ...[
                              SizedBox(height: 4.h),
                              Container(
                                padding: EdgeInsets.all(6.r),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  unreadCount > 99 ? '99+' : '$unreadCount',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => ChatScreen(
                                    chatId: chatId,
                                    otherUserId: otherUserId,
                                    otherUsername: otherUsername,
                                    otherAvatarUrl: otherAvatarUrl,
                                  ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<int> _getUnreadCount(String chatId, String userId) async {
    try {
      final unreadMessages =
          await _firestore
              .collection('chats')
              .doc(chatId)
              .collection('messages')
              .where('receiverId', isEqualTo: userId)
              .where('isRead', isEqualTo: false)
              .get();

      return unreadMessages.docs.length;
    } catch (e) {
      print('Lỗi khi đếm tin nhắn chưa đọc: $e');
      return 0;
    }
  }

  String _formatTimestamp(Timestamp timestamp) {
    final DateTime dateTime = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      if (difference.inDays == 1) return 'Hôm qua';
      if (difference.inDays < 7) return '${difference.inDays} ngày trước';
      return '${dateTime.day}/${dateTime.month}';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'Vừa xong';
    }
  }
}
