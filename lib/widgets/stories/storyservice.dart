// services/story_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Check if user has active stories (not expired)
  Future<bool> hasActiveStories(String userId) async {
    try {
      final now = DateTime.now();
      final twentyFourHoursAgo = now.subtract(Duration(hours: 24));
      final querySnapshot =
          await _firestore
              .collection('stories')
              .where('userId', isEqualTo: userId)
              .where(
                'timestamp',
                isGreaterThan: Timestamp.fromDate(twentyFourHoursAgo),
              )
              .get();
      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking active stories: $e');
      return false;
    }
  }

  // Get stories for a user
  Future<List<Map<String, dynamic>>> getStories(String userId) async {
    try {
      final now = DateTime.now();
      final twentyFourHoursAgo = now.subtract(Duration(hours: 24));
      final querySnapshot =
          await _firestore
              .collection('stories')
              .where('userId', isEqualTo: userId)
              .where(
                'timestamp',
                isGreaterThan: Timestamp.fromDate(twentyFourHoursAgo),
              )
              .orderBy('timestamp', descending: true)
              .get();

      return querySnapshot.docs
          .map((doc) => {'storyId': doc.id, ...doc.data()})
          .toList();
    } catch (e) {
      print('Error fetching stories: $e');
      return [];
    }
  }

  // Mark story as viewed
  Future<void> markStoryAsViewed(String storyId) async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) return;

      await _firestore.collection('stories').doc(storyId).update({
        'viewedBy': FieldValue.arrayUnion([currentUserId]),
      });
    } catch (e) {
      print('Error marking story as viewed: $e');
    }
  }

  // Check if current user has viewed the story
  Future<bool> hasViewedStory(String storyId) async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) return false;

      final storyDoc =
          await _firestore.collection('stories').doc(storyId).get();
      if (!storyDoc.exists) return false;

      final storyData = storyDoc.data() as Map<String, dynamic>;
      final viewedBy = List<String>.from(storyData['viewedBy'] ?? []);
      return viewedBy.contains(currentUserId);
    } catch (e) {
      print('Error checking if story viewed: $e');
      return false;
    }
  }
}
