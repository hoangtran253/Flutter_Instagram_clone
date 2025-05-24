import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReelCommentService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<Map<String, dynamic>>> getComments(String? reelId) async {
    if (reelId == null || reelId.isEmpty) {
      print('Error: reelId is null or empty');
      return [];
    }
    try {
      DocumentSnapshot reelDoc =
          await _firestore.collection('reels').doc(reelId).get();
      if (reelDoc.exists) {
        final data = reelDoc.data() as Map<String, dynamic>;
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

  Future<int> getCommentsCount(String? reelId) async {
    if (reelId == null || reelId.isEmpty) {
      print('Error: reelId is null or empty');
      return 0;
    }
    try {
      DocumentSnapshot reelDoc =
          await _firestore.collection('reels').doc(reelId).get();
      if (reelDoc.exists) {
        final data = reelDoc.data() as Map<String, dynamic>;
        final comments = List.from(data['comments'] ?? []);
        return comments.length;
      }
      return 0;
    } catch (e) {
      print('Error getting comments count: $e');
      return 0;
    }
  }

  Future<void> addComment(String? reelId, String commentText) async {
    if (reelId == null || reelId.isEmpty) {
      print('Error: reelId is null or empty');
      throw Exception('Invalid reelId');
    }
    if (_auth.currentUser == null || commentText.trim().isEmpty) return;

    try {
      final userId = _auth.currentUser!.uid;
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data() as Map<String, dynamic>;

      final comment = {
        'uid': userId,
        'username': userData['username'] ?? 'Unknown User',
        'avatarUrl': userData['avatarUrl'] ?? '',
        'comment': commentText.trim(),
        'timestamp': Timestamp.now(),
        'likes': [],
        'replies': [],
      };

      await _firestore.collection('reels').doc(reelId).update({
        'comments': FieldValue.arrayUnion([comment]),
        'commentsCount': FieldValue.increment(1),
      });
    } catch (e) {
      print('Error adding comment: $e');
      throw Exception('Error adding comment');
    }
  }

  Future<void> editComment(
    String? reelId,
    String commentUid,
    Timestamp commentTimestamp,
    String newCommentText,
  ) async {
    if (reelId == null || reelId.isEmpty) {
      print('Error: reelId is null or empty');
      throw Exception('Invalid reelId');
    }
    if (_auth.currentUser == null || newCommentText.trim().isEmpty) {
      print('Error: User not authenticated or empty comment text');
      throw Exception('Invalid user or comment text');
    }
    if (_auth.currentUser!.uid != commentUid) {
      print('Error: User not authorized to edit this comment');
      throw Exception('Unauthorized');
    }

    try {
      final reelRef = _firestore.collection('reels').doc(reelId);
      final reelDoc = await reelRef.get();

      if (reelDoc.exists) {
        final reelData = reelDoc.data() as Map<String, dynamic>;
        final comments = List<Map<String, dynamic>>.from(
          reelData['comments'] ?? [],
        );

        bool updated = false;
        for (int i = 0; i < comments.length; i++) {
          if (comments[i]['timestamp'] == commentTimestamp &&
              comments[i]['uid'] == commentUid) {
            comments[i]['comment'] = newCommentText.trim();
            updated = true;
            break;
          }
        }

        if (!updated) {
          print('Error: Comment not found for editing');
          throw Exception('Comment not found');
        }

        await reelRef.update({'comments': comments});
      } else {
        print('Error: Reel not found');
        throw Exception('Reel not found');
      }
    } catch (e) {
      print('Error editing comment: $e');
      throw Exception('Error editing comment');
    }
  }

  Future<void> deleteComment(
    String? reelId,
    String commentUid,
    Timestamp commentTimestamp,
  ) async {
    if (reelId == null || reelId.isEmpty) {
      print('Error: reelId is null or empty');
      throw Exception('Invalid reelId');
    }
    if (_auth.currentUser == null) {
      print('Error: User not authenticated');
      throw Exception('Invalid user');
    }
    if (_auth.currentUser!.uid != commentUid) {
      print('Error: User not authorized to delete this comment');
      throw Exception('Unauthorized');
    }

    try {
      final reelRef = _firestore.collection('reels').doc(reelId);
      final reelDoc = await reelRef.get();

      if (reelDoc.exists) {
        final reelData = reelDoc.data() as Map<String, dynamic>;
        final comments = List<Map<String, dynamic>>.from(
          reelData['comments'] ?? [],
        );

        final originalLength = comments.length;
        final updatedComments =
            comments.where((comment) {
              return !(comment['timestamp'] == commentTimestamp &&
                  comment['uid'] == commentUid);
            }).toList();

        // Only update if a comment was actually removed
        if (updatedComments.length < originalLength) {
          await reelRef.update({
            'comments': updatedComments,
            'commentsCount': FieldValue.increment(-1),
          });
        }
      } else {
        print('Error: Reel not found');
        throw Exception('Reel not found');
      }
    } catch (e) {
      print('Error deleting comment: $e');
      throw Exception('Error deleting comment');
    }
  }

  Future<void> addReply(
    String? reelId,
    String commentUid,
    Timestamp commentTimestamp,
    String replyText,
  ) async {
    if (reelId == null || reelId.isEmpty) {
      print('Error: reelId is null or empty');
      throw Exception('Invalid reelId');
    }
    if (_auth.currentUser == null || replyText.trim().isEmpty) {
      print('Error: User not authenticated or empty reply text');
      throw Exception('Invalid user or reply text');
    }

    try {
      final userId = _auth.currentUser!.uid;
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data() as Map<String, dynamic>;

      final reply = {
        'uid': userId,
        'username': userData['username'] ?? 'Unknown User',
        'avatarUrl': userData['avatarUrl'] ?? '',
        'comment': replyText.trim(),
        'timestamp': Timestamp.now(),
        'likes': [],
        'replies': [],
      };

      final reelRef = _firestore.collection('reels').doc(reelId);
      final reelDoc = await reelRef.get();

      if (reelDoc.exists) {
        final reelData = reelDoc.data() as Map<String, dynamic>;
        final comments = List<Map<String, dynamic>>.from(
          reelData['comments'] ?? [],
        );

        bool updated = false;
        for (int i = 0; i < comments.length; i++) {
          if (comments[i]['timestamp'] == commentTimestamp &&
              comments[i]['uid'] == commentUid) {
            comments[i]['replies'] = [...(comments[i]['replies'] ?? []), reply];
            updated = true;
            break;
          }
        }

        if (!updated) {
          print('Error: Comment not found for adding reply');
          throw Exception('Comment not found');
        }

        await reelRef.update({'comments': comments});
      } else {
        print('Error: Reel not found');
        throw Exception('Reel not found');
      }
    } catch (e) {
      print('Error adding reply: $e');
      throw Exception('Error adding reply');
    }
  }
}
