import 'package:cloud_firestore/cloud_firestore.dart';

class AdminService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Fetch all users
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      final snapshot = await _firestore.collection('users').get();
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'uid': doc.id,
          'email': data['email'],
          'username': data['username'],
          'bio': data['bio'],
          'avatarUrl': data['avatarUrl'],
          'isActive': data['isActive'] ?? true,
        };
      }).toList();
    } catch (e) {
      print('Error fetching users: $e');
      return [];
    }
  }

  // Fetch all posts
  Future<List<Map<String, dynamic>>> getAllPosts() async {
    try {
      final snapshot = await _firestore.collection('posts').get();
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'postId': doc.id,
          'uid': data['uid'],
          'username': data['username'],
          'caption': data['caption'],
          'imageUrls': data['imageUrls'],
          'avatarUrl': data['avatarUrl'],
          'postTime': data['postTime'],
        };
      }).toList();
    } catch (e) {
      print('Error fetching posts: $e');
      return [];
    }
  }

  // Fetch all reels
  Future<List<Map<String, dynamic>>> getAllReels() async {
    try {
      final snapshot = await _firestore.collection('reels').get();
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'reelId': doc.id,
          'uid': data['uid'],
          'username': data['username'],
          'caption': data['caption'],
          'videoUrl': data['videoUrl'],
          'thumbnailUrl': data['thumbnailUrl'],
          'avatarUrl': data['avatarUrl'],
          'postTime': data['postTime'],
          'likes': data['likes'] ?? [],
          'comments': data['comments'] ?? 0,
        };
      }).toList();
    } catch (e) {
      print('Error fetching reels: $e');
      return [];
    }
  }

  // Delete user and related posts & reels
  Future<void> deleteUser(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).delete();

      final posts =
          await _firestore
              .collection('posts')
              .where('uid', isEqualTo: uid)
              .get();
      for (var doc in posts.docs) {
        await _firestore.collection('posts').doc(doc.id).delete();
      }

      final reels =
          await _firestore
              .collection('reels')
              .where('uid', isEqualTo: uid)
              .get();
      for (var doc in reels.docs) {
        await _firestore.collection('reels').doc(doc.id).delete();
      }
    } catch (e) {
      print('Error deleting user: $e');
      throw Exception('Failed to delete user');
    }
  }

  // Delete post and comments
  Future<void> deletePost(String postId) async {
    try {
      await _firestore.collection('posts').doc(postId).delete();

      final comments =
          await _firestore
              .collection('comments')
              .where('postId', isEqualTo: postId)
              .get();

      for (var doc in comments.docs) {
        await _firestore.collection('comments').doc(doc.id).delete();
      }
    } catch (e) {
      print('Error deleting post: $e');
      throw Exception('Failed to delete post');
    }
  }

  // Delete reel and comments
  Future<void> deleteReel(String reelId) async {
    try {
      await _firestore.collection('reels').doc(reelId).delete();

      final comments =
          await _firestore
              .collection('comments')
              .where('reelId', isEqualTo: reelId)
              .get();

      for (var doc in comments.docs) {
        await _firestore.collection('comments').doc(doc.id).delete();
      }
    } catch (e) {
      print('Error deleting reel: $e');
      throw Exception('Failed to delete reel');
    }
  }

  // Update user info (username, bio, avatar, isActive)
  Future<void> updateUserInfo({
    required String uid,
    String? username,
    String? bio,
    String? avatarUrl,
    bool? isActive,
  }) async {
    try {
      Map<String, dynamic> updateData = {};

      if (username != null && username.isNotEmpty) {
        updateData['username'] = username;
      }

      if (bio != null) {
        updateData['bio'] = bio;
      }

      if (avatarUrl != null) {
        updateData['avatarUrl'] = avatarUrl;
      }

      if (isActive != null) {
        updateData['isActive'] = isActive;
      }

      if (updateData.isNotEmpty) {
        await _firestore.collection('users').doc(uid).update(updateData);
      }
    } catch (e) {
      print('Error updating user: $e');
      throw Exception('Failed to update user');
    }
  }

  // Analytics
  Future<Map<String, dynamic>> getAnalytics() async {
    try {
      final userCount = await _firestore.collection('users').count().get();
      final postCount = await _firestore.collection('posts').count().get();
      final reelCount = await _firestore.collection('reels').count().get();

      final activeUsersSnapshot =
          await _firestore
              .collection('users')
              .where('isActive', isEqualTo: true)
              .count()
              .get();

      final inactiveUsersSnapshot =
          await _firestore
              .collection('users')
              .where('isActive', isEqualTo: false)
              .count()
              .get();

      final sevenDaysAgo = DateTime.now().subtract(Duration(days: 7));

      final recentPosts =
          await _firestore
              .collection('posts')
              .where('postTime', isGreaterThan: sevenDaysAgo)
              .count()
              .get();

      final recentReels =
          await _firestore
              .collection('reels')
              .where('postTime', isGreaterThan: sevenDaysAgo)
              .count()
              .get();

      return {
        'totalUsers': userCount.count,
        'totalPosts': postCount.count,
        'totalReels': reelCount.count,
        'recentPosts': recentPosts.count,
        'recentReels': recentReels.count,
        'activeUsers': activeUsersSnapshot.count,
        'inactiveUsers': inactiveUsersSnapshot.count,
      };
    } catch (e) {
      print('Error getting analytics: $e');
      return {
        'totalUsers': 0,
        'totalPosts': 0,
        'totalReels': 0,
        'recentPosts': 0,
        'recentReels': 0,
        'activeUsers': 0,
        'inactiveUsers': 0,
      };
    }
  }
}
