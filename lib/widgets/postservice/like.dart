import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LikeService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<bool> isPostLiked(String? postId) async {
    if (postId == null || postId.isEmpty) {
      print('Error: postId is null or empty');
      return false;
    }
    try {
      DocumentSnapshot postDoc =
          await _firestore.collection('posts').doc(postId).get();
      if (postDoc.exists) {
        final data = postDoc.data() as Map<String, dynamic>;
        final likes = List<String>.from(data['likes'] ?? []);
        return likes.contains(_auth.currentUser?.uid);
      }
      return false;
    } catch (e) {
      print('Error checking like status: $e');
      return false;
    }
  }

  Future<int> getLikesCount(String? postId) async {
    if (postId == null || postId.isEmpty) {
      print('Error: postId is null or empty');
      return 0;
    }
    try {
      DocumentSnapshot postDoc =
          await _firestore.collection('posts').doc(postId).get();
      if (postDoc.exists) {
        final data = postDoc.data() as Map<String, dynamic>;
        final likes = List<String>.from(data['likes'] ?? []);
        return likes.length;
      }
      return 0;
    } catch (e) {
      print('Error getting likes count: $e');
      return 0;
    }
  }

  Future<List<String>> getLikedUsers(String? postId) async {
    if (postId == null || postId.isEmpty) {
      print('Error: postId is null or empty');
      return [];
    }
    try {
      DocumentSnapshot postDoc =
          await _firestore.collection('posts').doc(postId).get();
      if (postDoc.exists) {
        final data = postDoc.data() as Map<String, dynamic>;
        return List<String>.from(data['likes'] ?? []);
      }
      return [];
    } catch (e) {
      print('Error getting liked users: $e');
      return [];
    }
  }

  Future<bool> toggleLike(String? postId) async {
    if (postId == null || postId.isEmpty) {
      print('Error: postId is null or empty');
      return false;
    }
    if (_auth.currentUser == null) return false;

    try {
      final userId = _auth.currentUser!.uid;
      final postRef = _firestore.collection('posts').doc(postId);
      DocumentSnapshot postDoc = await postRef.get();

      if (postDoc.exists) {
        final data = postDoc.data() as Map<String, dynamic>;
        final likes = List<String>.from(data['likes'] ?? []);
        bool isCurrentlyLiked = likes.contains(userId);

        if (isCurrentlyLiked) {
          await postRef.update({
            'likes': FieldValue.arrayRemove([userId]),
          });
          return false; // Unliked
        } else {
          await postRef.update({
            'likes': FieldValue.arrayUnion([userId]),
          });
          return true; // Liked
        }
      }
      return false;
    } catch (e) {
      print('Error toggling like: $e');
      return false;
    }
  }
}
