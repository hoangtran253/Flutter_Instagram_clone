import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReelLikeService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<bool> isReelLiked(String? reelId) async {
    if (reelId == null || reelId.isEmpty) {
      print('Error: reelId is null or empty');
      return false;
    }
    try {
      DocumentSnapshot reelDoc =
          await _firestore.collection('reels').doc(reelId).get();
      if (reelDoc.exists) {
        final data = reelDoc.data() as Map<String, dynamic>;
        final likes = List<String>.from(data['likes'] ?? []);
        return likes.contains(_auth.currentUser?.uid);
      }
      return false;
    } catch (e) {
      print('Error checking like status: $e');
      return false;
    }
  }

  Future<int> getLikesCount(String? reelId) async {
    if (reelId == null || reelId.isEmpty) {
      print('Error: reelId is null or empty');
      return 0;
    }
    try {
      DocumentSnapshot reelDoc =
          await _firestore.collection('reels').doc(reelId).get();
      if (reelDoc.exists) {
        final data = reelDoc.data() as Map<String, dynamic>;
        final likes = List<String>.from(data['likes'] ?? []);
        return likes.length;
      }
      return 0;
    } catch (e) {
      print('Error getting likes count: $e');
      return 0;
    }
  }

  Future<List<String>> getLikedUsers(String? reelId) async {
    if (reelId == null || reelId.isEmpty) {
      print('Error: reelId is null or empty');
      return [];
    }
    try {
      DocumentSnapshot reelDoc =
          await _firestore.collection('reels').doc(reelId).get();
      if (reelDoc.exists) {
        final data = reelDoc.data() as Map<String, dynamic>;
        return List<String>.from(data['likes'] ?? []);
      }
      return [];
    } catch (e) {
      print('Error getting liked users: $e');
      return [];
    }
  }

  Future<bool> toggleLike(String? reelId) async {
    if (reelId == null || reelId.isEmpty) {
      print('Error: reelId is null or empty');
      return false;
    }
    if (_auth.currentUser == null) return false;

    try {
      final userId = _auth.currentUser!.uid;
      final reelRef = _firestore.collection('reels').doc(reelId);
      DocumentSnapshot reelDoc = await reelRef.get();

      if (reelDoc.exists) {
        final data = reelDoc.data() as Map<String, dynamic>;
        final likes = List<String>.from(data['likes'] ?? []);
        bool isCurrentlyLiked = likes.contains(userId);

        if (isCurrentlyLiked) {
          await reelRef.update({
            'likes': FieldValue.arrayRemove([userId]),
            'likesCount': FieldValue.increment(-1),
          });
          return false; // Unliked
        } else {
          await reelRef.update({
            'likes': FieldValue.arrayUnion([userId]),
            'likesCount': FieldValue.increment(1),
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
