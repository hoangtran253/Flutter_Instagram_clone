import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CommentService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<Map<String, dynamic>>> getComments(String? postId) async {
    if (postId == null || postId.isEmpty) {
      print('Error: postId is null or empty');
      return [];
    }
    try {
      DocumentSnapshot postDoc =
          await _firestore.collection('posts').doc(postId).get();
      if (postDoc.exists) {
        final data = postDoc.data() as Map<String, dynamic>;
        return List<Map<String, dynamic>>.from(
          data['comments'] ?? [],
        ).reversed.toList();
      }
      return [];
    } catch (e) {
      print('Error loading comments: $e');
      return [];
    }
  }

  Future<int> getCommentsCount(String? postId) async {
    if (postId == null || postId.isEmpty) {
      print('Error: postId is null or empty');
      return 0;
    }
    try {
      DocumentSnapshot postDoc =
          await _firestore.collection('posts').doc(postId).get();
      if (postDoc.exists) {
        final data = postDoc.data() as Map<String, dynamic>;
        final comments = List.from(data['comments'] ?? []);
        return comments.length;
      }
      return 0;
    } catch (e) {
      print('Error getting comments count: $e');
      return 0;
    }
  }

  Future<void> addComment(String? postId, String commentText) async {
    if (postId == null || postId.isEmpty) {
      print('Error: postId is null or empty');
      throw Exception('Invalid postId');
    }
    if (_auth.currentUser == null || commentText.trim().isEmpty) return;

    try {
      final userId = _auth.currentUser!.uid;
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data() as Map<String, dynamic>;

      final comment = {
        'uid': userId,
        'username': userData['username'],
        'avatarUrl': userData['avatarUrl'] ?? '',
        'comment': commentText.trim(),
        'timestamp':
            Timestamp.now(), // Use Timestamp.now() instead of serverTimestamp()
      };

      await _firestore.collection('posts').doc(postId).update({
        'comments': FieldValue.arrayUnion([comment]),
      });
    } catch (e) {
      print('Error adding comment: $e');
      throw Exception('Error adding comment');
    }
  }
}
