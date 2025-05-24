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
        'username': userData['username'] ?? 'Unknown User',
        'avatarUrl': userData['avatarUrl'] ?? '',
        'comment': commentText.trim(),
        'timestamp': Timestamp.now(),
        'likes': [],
        'replies': [],
      };

      await _firestore.collection('posts').doc(postId).update({
        'comments': FieldValue.arrayUnion([comment]),
      });
    } catch (e) {
      print('Error adding comment: $e');
      throw Exception('Error adding comment');
    }
  }

  Future<void> editComment(
    String? postId,
    String commentUid,
    Timestamp commentTimestamp,
    String newCommentText,
  ) async {
    if (postId == null || postId.isEmpty) {
      print('Error: postId is null or empty');
      throw Exception('Invalid postId');
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
      final postRef = _firestore.collection('posts').doc(postId);
      final postDoc = await postRef.get();

      if (postDoc.exists) {
        final postData = postDoc.data() as Map<String, dynamic>;
        final comments = List<Map<String, dynamic>>.from(
          postData['comments'] ?? [],
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

        await postRef.update({'comments': comments});
      } else {
        print('Error: Post not found');
        throw Exception('Post not found');
      }
    } catch (e) {
      print('Error editing comment: $e');
      throw Exception('Error editing comment');
    }
  }

  Future<void> deleteComment(
    String? postId,
    String commentUid,
    Timestamp commentTimestamp,
  ) async {
    if (postId == null || postId.isEmpty) {
      print('Error: postId is null or empty');
      throw Exception('Invalid postId');
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
      final postRef = _firestore.collection('posts').doc(postId);
      final postDoc = await postRef.get();

      if (postDoc.exists) {
        final postData = postDoc.data() as Map<String, dynamic>;
        final comments = List<Map<String, dynamic>>.from(
          postData['comments'] ?? [],
        );

        final updatedComments =
            comments.where((comment) {
              return !(comment['timestamp'] == commentTimestamp &&
                  comment['uid'] == commentUid);
            }).toList();

        await postRef.update({'comments': updatedComments});
      } else {
        print('Error: Post not found');
        throw Exception('Post not found');
      }
    } catch (e) {
      print('Error deleting comment: $e');
      throw Exception('Error deleting comment');
    }
  }

  Future<void> addReply(
    String? postId,
    String commentUid,
    Timestamp commentTimestamp,
    String replyText,
  ) async {
    if (postId == null || postId.isEmpty) {
      print('Error: postId is null or empty');
      throw Exception('Invalid postId');
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

      final postRef = _firestore.collection('posts').doc(postId);
      final postDoc = await postRef.get();

      if (postDoc.exists) {
        final postData = postDoc.data() as Map<String, dynamic>;
        final comments = List<Map<String, dynamic>>.from(
          postData['comments'] ?? [],
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

        await postRef.update({'comments': comments});
      } else {
        print('Error: Post not found');
        throw Exception('Post not found');
      }
    } catch (e) {
      print('Error adding reply: $e');
      throw Exception('Error adding reply');
    }
  }
}
