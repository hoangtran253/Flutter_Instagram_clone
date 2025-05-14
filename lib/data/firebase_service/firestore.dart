import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseFirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> createUser({
    required String uid,
    required String email,
    required String username,
    required String bio,
    required String avatarUrl,
  }) async {
    try {
      await _firestore.collection('users').doc(uid).set({
        'email': email,
        'username': username,
        'bio': bio,
        'avatarUrl': avatarUrl, // Lưu ảnh đại diện vào Firestore
      });
    } catch (e) {
      print("Error creating user in Firestore: $e");
    }
  }
}
