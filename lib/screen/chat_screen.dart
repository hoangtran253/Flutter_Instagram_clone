import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_instagram_clone/screen/authprofile_screen.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String otherUserId;
  final String otherUsername;
  final String otherAvatarUrl;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.otherUserId,
    required this.otherUsername,
    required this.otherAvatarUrl,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _editMessageController = TextEditingController();
  bool _showEmojiPicker = false;
  String? _editingMessageId;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _editMessageController.dispose();
    super.dispose();
  }

  Future<void> sendMessage() async {
    final user = _auth.currentUser;
    if (user == null || _messageController.text.trim().isEmpty) return;

    final message = _messageController.text.trim();
    _messageController.clear();
    _toggleEmojiPicker(false);

    try {
      await _firestore
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .add({
            'senderId': user.uid,
            'receiverId': widget.otherUserId,
            'message': message,
            'timestamp': FieldValue.serverTimestamp(),
            'isRead': false,
            'reactions': [], // Sử dụng mảng rỗng
            'edited': false,
            'deleted': false,
          });

      await _firestore.collection('chats').doc(widget.chatId).set({
        'participants': [user.uid, widget.otherUserId],
        'lastMessage': message,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': user.uid,
      }, SetOptions(merge: true));

      _scrollToBottom();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không thể gửi tin nhắn: $e')));
    }
  }

  Future<void> _editMessage(String messageId, String newText) async {
    if (newText.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Tin nhắn không được để trống')));
      return;
    }

    try {
      await _firestore
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .doc(messageId)
          .update({'message': newText.trim(), 'edited': true});

      final message =
          await _firestore
              .collection('chats')
              .doc(widget.chatId)
              .collection('messages')
              .doc(messageId)
              .get();

      if (message.exists) {
        final lastMessage =
            await _firestore.collection('chats').doc(widget.chatId).get();

        if (lastMessage.exists &&
            lastMessage.data()?['lastMessageSenderId'] ==
                _auth.currentUser?.uid &&
            lastMessage.data()?['lastMessageTime'] ==
                message.data()?['timestamp']) {
          await _firestore.collection('chats').doc(widget.chatId).update({
            'lastMessage': newText.trim(),
          });
        }
      }

      setState(() {
        _editingMessageId = null;
        _editMessageController.clear();
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Tin nhắn đã được chỉnh sửa')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể chỉnh sửa tin nhắn: $e')),
      );
    }
  }

  Future<void> _deleteMessage(String messageId) async {
    try {
      await _firestore
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .doc(messageId)
          .update({'deleted': true, 'message': 'Tin nhắn đã được thu hồi'});

      final message =
          await _firestore
              .collection('chats')
              .doc(widget.chatId)
              .collection('messages')
              .doc(messageId)
              .get();

      if (message.exists) {
        final lastMessage =
            await _firestore.collection('chats').doc(widget.chatId).get();

        if (lastMessage.exists &&
            lastMessage.data()?['lastMessageSenderId'] ==
                _auth.currentUser?.uid &&
            lastMessage.data()?['lastMessageTime'] ==
                message.data()?['timestamp']) {
          await _firestore.collection('chats').doc(widget.chatId).update({
            'lastMessage': 'Tin nhắn đã được thu hồi',
          });
        }
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Tin nhắn đã được thu hồi')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không thể thu hồi tin nhắn: $e')));
    }
  }

  Future<void> _addReaction(String messageId, String emoji) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final messageRef = _firestore
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .doc(messageId);
      final messageSnap = await messageRef.get();
      final reactions = List<Map<String, String>>.from(
        (messageSnap.data()?['reactions'] is List)
            ? (messageSnap.data()?['reactions'] as List<dynamic>?)?.map(
                  (r) => Map<String, String>.from(r as Map),
                ) ??
                []
            : [],
      );

      // Kiểm tra xem người dùng đã có phản ứng chưa
      final existingReactionIndex = reactions.indexWhere(
        (r) => r['userId'] == user.uid,
      );
      if (existingReactionIndex != -1) {
        reactions[existingReactionIndex]['emoji'] =
            emoji; // Cập nhật emoji nếu đã tồn tại
      } else {
        reactions.add({
          'userId': user.uid,
          'emoji': emoji,
        }); // Thêm phản ứng mới
      }

      await messageRef.update({'reactions': reactions});

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Đã thêm biểu tượng cảm xúc')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể thêm biểu tượng cảm xúc: $e')),
      );
    }
  }

  Future<void> _removeReaction(String messageId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final messageRef = _firestore
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .doc(messageId);
      final messageSnap = await messageRef.get();
      final reactions = List<Map<String, String>>.from(
        (messageSnap.data()?['reactions'] is List)
            ? (messageSnap.data()?['reactions'] as List<dynamic>?)?.map(
                  (r) => Map<String, String>.from(r as Map),
                ) ??
                []
            : [],
      );

      // Xóa phản ứng của người dùng
      final updatedReactions =
          reactions.where((r) => r['userId'] != user.uid).toList();

      await messageRef.update({'reactions': updatedReactions});

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Đã xóa biểu tượng cảm xúc')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể xóa biểu tượng cảm xúc: $e')),
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _toggleEmojiPicker(bool show) {
    setState(() {
      _showEmojiPicker = show;
      if (show) {
        FocusScope.of(context).unfocus();
      }
    });
  }

  void _showMessageOptions(
    BuildContext context,
    String messageId,
    String messageText,
    bool isCurrentUser,
  ) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder:
          (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 8.h),
                // Edit option (for sender only)
                if (isCurrentUser && messageText != 'Tin nhắn đã được thu hồi')
                  ListTile(
                    leading: Icon(Icons.edit, size: 20),
                    title: Text('Chỉnh sửa'),
                    onTap: () {
                      Navigator.pop(context);
                      _startEditingMessage(messageId, messageText);
                    },
                  ),
                // Delete option (for sender only)
                if (isCurrentUser && messageText != 'Tin nhắn đã được thu hồi')
                  ListTile(
                    leading: Icon(Icons.delete, size: 20, color: Colors.red),
                    title: Text('Thu hồi', style: TextStyle(color: Colors.red)),
                    onTap: () {
                      Navigator.pop(context);
                      _showDeleteConfirmationDialog(messageId);
                    },
                  ),
                // Copy option
                ListTile(
                  leading: Icon(Icons.copy, size: 20),
                  title: Text('Sao chép'),
                  onTap: () {
                    Navigator.pop(context);
                    Clipboard.setData(ClipboardData(text: messageText));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Đã sao chép tin nhắn')),
                    );
                  },
                ),
                SizedBox(height: 8.h),
              ],
            ),
          ),
    );
  }

  void _showReactionOptions(
    BuildContext context,
    String messageId,
    Map<String, String> reactions,
  ) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder:
          (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 8.h),
                SizedBox(
                  height: 60.h,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(horizontal: 8.w),
                    children:
                        ['❤️', '😂', '😮', '😢', '👍', '👎'].map((emoji) {
                          final isSelected =
                              reactions[_auth.currentUser?.uid] == emoji;
                          return Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4.w),
                            child: GestureDetector(
                              onTap: () {
                                if (isSelected) {
                                  _removeReaction(messageId);
                                } else {
                                  _addReaction(messageId, emoji);
                                }
                                Navigator.pop(context);
                              },
                              child: Container(
                                padding: EdgeInsets.all(8.w),
                                decoration: BoxDecoration(
                                  color: isSelected ? Colors.grey[200] : null,
                                  borderRadius: BorderRadius.circular(20.r),
                                ),
                                child: Text(
                                  emoji,
                                  style: TextStyle(fontSize: 24.sp),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                  ),
                ),
                SizedBox(height: 8.h),
              ],
            ),
          ),
    );
  }

  void _showDeleteConfirmationDialog(String messageId) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Xác nhận thu hồi'),
            content: Text('Bạn có chắc muốn thu hồi tin nhắn này?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Hủy'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _deleteMessage(messageId);
                },
                child: Text('Thu hồi', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );
  }

  void _startEditingMessage(String messageId, String messageText) {
    setState(() {
      _editingMessageId = messageId;
      _editMessageController.text = messageText;
    });
    FocusScope.of(context).requestFocus(FocusNode());
    _scrollToBottom();
  }

  void _cancelEditing() {
    setState(() {
      _editingMessageId = null;
      _editMessageController.clear();
    });
  }

  Future<void> _markMessagesAsRead() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final unreadMessages =
          await _firestore
              .collection('chats')
              .doc(widget.chatId)
              .collection('messages')
              .where('receiverId', isEqualTo: user.uid)
              .where('isRead', isEqualTo: false)
              .get();

      final batch = _firestore.batch();
      for (final doc in unreadMessages.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      if (unreadMessages.docs.isNotEmpty) {
        await batch.commit();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể đánh dấu tin nhắn đã đọc: $e')),
      );
    }
  }

  String _formatTimestamp(Timestamp timestamp) {
    final DateTime dateTime = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${dateTime.day}/${dateTime.month}';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h trước';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m trước';
    } else {
      return 'Vừa xong';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1.5,
        iconTheme: IconThemeData(color: Colors.black),
        title: Row(
          children: [
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => OtherUserProfileScreen(
                          userId: widget.otherUserId,
                          username: widget.otherUsername,
                        ),
                  ),
                );
              },
              child: CircleAvatar(
                radius: 16.r,
                backgroundImage:
                    widget.otherAvatarUrl.isNotEmpty
                        ? NetworkImage(widget.otherAvatarUrl)
                        : AssetImage('images/person.png') as ImageProvider,
              ),
            ),
            SizedBox(width: 8.w),
            Text(
              widget.otherUsername,
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                _toggleEmojiPicker(false);
                FocusScope.of(context).unfocus();
              },
              child: StreamBuilder<QuerySnapshot>(
                stream:
                    _firestore
                        .collection('chats')
                        .doc(widget.chatId)
                        .collection('messages')
                        .orderBy('timestamp', descending: false)
                        .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Text(
                        'Chưa có tin nhắn nào. Hãy bắt đầu cuộc trò chuyện!',
                      ),
                    );
                  }

                  final messages = snapshot.data!.docs;
                  _markMessagesAsRead();

                  return ListView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.all(8.w),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final messageDoc = messages[index];
                      final message = messageDoc.data() as Map<String, dynamic>;
                      final isCurrentUser =
                          message['senderId'] == _auth.currentUser?.uid;
                      final timestamp = message['timestamp'] as Timestamp?;
                      final isDeleted = message['deleted'] == true;
                      final isEdited = message['edited'] == true;

                      // Xử lý reactions: có thể là List hoặc Map
                      List<Map<String, String>> reactions;
                      if (message['reactions'] is List) {
                        reactions =
                            (message['reactions'] as List<dynamic>?)
                                ?.map((r) => Map<String, String>.from(r as Map))
                                .toList() ??
                            [];
                      } else if (message['reactions'] is Map) {
                        reactions =
                            (message['reactions'] as Map<String, dynamic>?)
                                ?.entries
                                .map(
                                  (e) => {
                                    'userId': e.key,
                                    'emoji': e.value as String,
                                  },
                                )
                                .toList() ??
                            [];
                      } else {
                        reactions = [];
                      }

                      final userReaction = reactions.firstWhere(
                        (r) => r['userId'] == _auth.currentUser?.uid,
                        orElse: () => {'userId': '', 'emoji': ''},
                      );

                      return _buildMessageBubble(
                        messageDoc.id,
                        isDeleted
                            ? 'Tin nhắn đã được thu hồi'
                            : message['message'] ?? '',
                        isCurrentUser,
                        timestamp,
                        reactions,
                        isEdited && !isDeleted,
                        () => _showMessageOptions(
                          context,
                          messageDoc.id,
                          message['message'] ?? '',
                          isCurrentUser,
                        ),
                        () => _showReactionOptions(
                          context,
                          messageDoc.id,
                          Map.fromEntries(
                            reactions.map(
                              (r) => MapEntry(r['userId']!, r['emoji']!),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
          if (_editingMessageId != null) _buildEditMessageInput(),
          _buildMessageInput(),
          if (_showEmojiPicker)
            SizedBox(
              height: 250,
              child: EmojiPicker(
                onEmojiSelected: (category, emoji) {
                  _messageController.text += emoji.emoji;
                },
                config: Config(
                  emojiViewConfig: EmojiViewConfig(
                    emojiSizeMax: 32,
                    columns: 7,
                    verticalSpacing: 0,
                    horizontalSpacing: 0,
                    backgroundColor: const Color(0xFFF2F2F2),
                    noRecents: const Text(
                      'Không có gần đây',
                      style: TextStyle(fontSize: 20, color: Colors.black26),
                    ),
                  ),
                  categoryViewConfig: CategoryViewConfig(
                    indicatorColor: Colors.blue,
                    iconColor: Colors.grey,
                    iconColorSelected: Colors.blue,
                    tabIndicatorAnimDuration: kTabScrollDuration,
                  ),
                  skinToneConfig: SkinToneConfig(
                    dialogBackgroundColor: Colors.white,
                    indicatorColor: Colors.grey,
                  ),
                  bottomActionBarConfig: BottomActionBarConfig(
                    backgroundColor: Colors.blue,
                    showBackspaceButton: true,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(
    String messageId,
    String message,
    bool isCurrentUser,
    Timestamp? timestamp,
    List<Map<String, String>> reactions,
    bool isEdited,
    VoidCallback onMorePressed,
    VoidCallback onReactionPressed,
  ) {
    return Column(
      crossAxisAlignment:
          isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment:
              isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isCurrentUser)
              SizedBox(width: 32.w), // Space for avatar or alignment
            Flexible(
              child: Container(
                margin: EdgeInsets.symmetric(vertical: 4.h, horizontal: 8.w),
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: isCurrentUser ? Colors.blue : Colors.grey[300],
                  borderRadius: BorderRadius.circular(16.r),
                ),
                constraints: BoxConstraints(maxWidth: 250.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message,
                      style: TextStyle(
                        color: isCurrentUser ? Colors.white : Colors.black,
                        fontSize: 14.sp,
                        fontStyle:
                            message == 'Tin nhắn đã được thu hồi'
                                ? FontStyle.italic
                                : FontStyle.normal,
                      ),
                    ),
                    if (timestamp != null) ...[
                      SizedBox(height: 4.h),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatTimestamp(timestamp),
                            style: TextStyle(
                              color:
                                  isCurrentUser
                                      ? Colors.white70
                                      : Colors.grey[600],
                              fontSize: 10.sp,
                            ),
                          ),
                          if (isEdited) ...[
                            SizedBox(width: 4.w),
                            Text(
                              'đã chỉnh sửa',
                              style: TextStyle(
                                color:
                                    isCurrentUser
                                        ? Colors.white70
                                        : Colors.grey[600],
                                fontSize: 10.sp,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (isCurrentUser)
              IconButton(
                icon: Icon(
                  Icons.more_vert,
                  size: 20.sp,
                  color: isCurrentUser ? Colors.blue : Colors.grey,
                ),
                onPressed: onMorePressed,
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(),
              ),
          ],
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Row(
            mainAxisAlignment:
                isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (reactions.isNotEmpty)
                Wrap(
                  spacing: 4.w,
                  runSpacing: 4.h,
                  children:
                      reactions.map((r) {
                        return Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6.w,
                            vertical: 2.h,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Text(
                            r['emoji']!,
                            style: TextStyle(fontSize: 12.sp),
                          ),
                        );
                      }).toList(),
                ),
              IconButton(
                icon: Icon(
                  Icons.add_reaction_outlined,
                  size: 20.sp,
                  color: Colors.grey,
                ),
                onPressed: onReactionPressed,
                padding: EdgeInsets.symmetric(horizontal: 4.w),
                constraints: BoxConstraints(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: EdgeInsets.all(8.w),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              _showEmojiPicker ? Icons.keyboard : Icons.emoji_emotions,
              color: Colors.grey,
            ),
            onPressed: () {
              _toggleEmojiPicker(!_showEmojiPicker);
            },
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Nhập tin nhắn...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20.r),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20.r),
                  borderSide: BorderSide(color: Colors.blue),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16.w,
                  vertical: 8.h,
                ),
              ),
              maxLines: null,
              onSubmitted: (_) => sendMessage(),
            ),
          ),
          SizedBox(width: 8.w),
          CircleAvatar(
            backgroundColor: Colors.blue,
            child: IconButton(
              icon: Icon(Icons.send, color: Colors.white),
              onPressed: sendMessage,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditMessageInput() {
    return Container(
      padding: EdgeInsets.all(8.w),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _editMessageController,
              decoration: InputDecoration(
                hintText: 'Chỉnh sửa tin nhắn...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20.r),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20.r),
                  borderSide: BorderSide(color: Colors.blue),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16.w,
                  vertical: 8.h,
                ),
              ),
              maxLines: null,
            ),
          ),
          SizedBox(width: 8.w),
          IconButton(
            icon: Icon(Icons.check, color: Colors.green),
            onPressed: () {
              if (_editingMessageId != null) {
                _editMessage(_editingMessageId!, _editMessageController.text);
              }
            },
          ),
          IconButton(
            icon: Icon(Icons.close, color: Colors.red),
            onPressed: _cancelEditing,
          ),
        ],
      ),
    );
  }
}
