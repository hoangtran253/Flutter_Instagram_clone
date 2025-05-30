import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  Future<void> addNotification({
    required String receiverUid,
    required String type,
    required Map<String, dynamic> payload,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      // Lấy dữ liệu người dùng từ Firestore
      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .get();
      final userData = userDoc.data() as Map<String, dynamic>?;

      // Cập nhật payload với username và avatarUrl từ Firestore
      final updatedPayload = {
        ...payload,
        'fromUid': currentUser.uid,
        'fromUsername': userData?['username'] ?? 'Người dùng',
        'fromAvatar': userData?['avatarUrl'] ?? '',
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(receiverUid)
          .collection('notifications')
          .add({
            'type': type,
            'payload': updatedPayload,
            'timestamp': FieldValue.serverTimestamp(),
            'isRead': false,
          });
    } catch (e) {
      print('Error adding notification: $e');
    }
  }
}
