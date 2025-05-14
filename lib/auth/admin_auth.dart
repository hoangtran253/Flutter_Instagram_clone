import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_instagram_clone/util/exception.dart';

class AdminAuth {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Check if current user is admin based on field `isAdmin` in `users` collection
  Future<bool> isUserAdmin() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final doc =
          await FirebaseFirestore.instance
              .collection('admins')
              .doc(user.uid)
              .get();

      // Kiểm tra nếu document tồn tại và isAdmin == true
      if (doc.exists && doc.data()?['isAdmin'] == true) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      print('Error checking admin status: $e');
      return false;
    }
  }

  /// Admin login check (đăng nhập và kiểm tra isAdmin trong users)
  Future<bool> adminLogin({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      return await isUserAdmin();
    } on FirebaseAuthException catch (e) {
      throw exceptions(e.message ?? 'Login failed');
    }
  }

  /// Set user as admin (by updating isAdmin = true)
  Future<void> setAdmin(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).update({'isAdmin': true});
    } catch (e) {
      throw exceptions('Failed to grant admin role: $e');
    }
  }

  /// Revoke admin rights
  Future<void> removeAdmin(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).update({'isAdmin': false});
    } catch (e) {
      throw exceptions('Failed to remove admin role: $e');
    }
  }
}
