import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Notification types
  static const String LIKE_POST = 'like_post';
  static const String COMMENT_POST = 'comment_post';
  static const String REPLY_COMMENT = 'reply_comment';
  static const String LIKE_COMMENT = 'like_comment';
  static const String FOLLOW_USER = 'follow_user';

  // Add notification
  Future<void> addNotification({
    required String recipientId,
    required String type,
    required String message,
    String? postId,
    String? commentId,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null || currentUser.uid == recipientId) {
        return; // Don't send notification to self
      }

      // Get current user data
      final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      final userData = userDoc.data() as Map<String, dynamic>? ?? {};

      await _firestore.collection('notifications').add({
        'recipientId': recipientId,
        'senderId': currentUser.uid,
        'senderUsername': userData['username'] ?? 'Unknown User',
        'senderAvatarUrl': userData['avatarUrl'] ?? '',
        'type': type,
        'message': message,
        'postId': postId,
        'commentId': commentId,
        'additionalData': additionalData ?? {},
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error adding notification: $e');
    }
  }

  // Get notifications for current user
  Stream<QuerySnapshot> getNotifications() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return const Stream.empty();
    }

    return _firestore
        .collection('notifications')
        .where('recipientId', isEqualTo: currentUser.uid)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'isRead': true,
      });
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  // Mark all notifications as read
  Future<void> markAllAsRead() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      final batch = _firestore.batch();
      final notifications = await _firestore
          .collection('notifications')
          .where('recipientId', isEqualTo: currentUser.uid)
          .where('isRead', isEqualTo: false)
          .get();

      for (final doc in notifications.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();
    } catch (e) {
      print('Error marking all notifications as read: $e');
    }
  }

  // Get unread notifications count
  Stream<int> getUnreadCount() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return Stream.value(0);
    }

    return _firestore
        .collection('notifications')
        .where('recipientId', isEqualTo: currentUser.uid)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Delete notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).delete();
    } catch (e) {
      print('Error deleting notification: $e');
    }
  }

  // Helper method to get post owner ID
  Future<String?> _getPostOwnerId(String postId) async {
    try {
      final postDoc = await _firestore.collection('posts').doc(postId).get();
      if (!postDoc.exists) return null;
      final postData = postDoc.data() as Map<String, dynamic>;
      return postData['uid'] as String?;
    } catch (e) {
      print('Error getting post owner: $e');
      return null;
    }
  }

  // Helper methods for specific notification types
  Future<void> addLikeNotification(String postOwnerId, String postId) async {
    await addNotification(
      recipientId: postOwnerId,
      type: LIKE_POST,
      message: 'đã thích bài viết của bạn',
      postId: postId,
    );
  }

  Future<void> addCommentNotification(
      String postOwnerId,
      String postId,
      String comment,
      ) async {
    await addNotification(
      recipientId: postOwnerId,
      type: COMMENT_POST,
      message: 'đã bình luận: "${comment.length > 50 ? comment.substring(0, 47) + '...' : comment}"',
      postId: postId,
      additionalData: {'comment': comment},
    );
  }

  Future<void> addReplyNotification(
      String commentOwnerId,
      String postId,
      String reply,
      ) async {
    final postOwnerId = await _getPostOwnerId(postId);
    if (postOwnerId != null && postOwnerId != _auth.currentUser?.uid) {
      // Notify post owner
      await addNotification(
        recipientId: postOwnerId,
        type: REPLY_COMMENT,
        message: 'đã trả lời một bình luận trong bài viết của bạn: "${reply.length > 50 ? reply.substring(0, 47) + '...' : reply}"',
        postId: postId,
        additionalData: {'reply': reply},
      );
    }

    if (commentOwnerId != _auth.currentUser?.uid && commentOwnerId != postOwnerId) {
      // Notify comment owner (if different from post owner)
      await addNotification(
        recipientId: commentOwnerId,
        type: REPLY_COMMENT,
        message: 'đã trả lời bình luận của bạn: "${reply.length > 50 ? reply.substring(0, 47) + '...' : reply}"',
        postId: postId,
        additionalData: {'reply': reply},
      );
    }
  }

  Future<void> addCommentLikeNotification(
      String commentOwnerId,
      String postId,
      String? commentId,
      ) async {
    final postOwnerId = await _getPostOwnerId(postId);
    if (postOwnerId != null && postOwnerId != _auth.currentUser?.uid) {
      // Notify post owner
      await addNotification(
        recipientId: postOwnerId,
        type: LIKE_COMMENT,
        message: 'đã thích một bình luận trong bài viết của bạn',
        postId: postId,
        commentId: commentId,
      );
    }

    if (commentOwnerId != _auth.currentUser?.uid && commentOwnerId != postOwnerId) {
      // Notify comment owner (if different from post owner)
      await addNotification(
        recipientId: commentOwnerId,
        type: LIKE_COMMENT,
        message: 'đã thích bình luận của bạn',
        postId: postId,
        commentId: commentId,
      );
    }
  }

  Future<void> addFollowNotification(String followedUserId) async {
    await addNotification(
      recipientId: followedUserId,
      type: FOLLOW_USER,
      message: 'đã bắt đầu theo dõi bạn',
    );
  }
}