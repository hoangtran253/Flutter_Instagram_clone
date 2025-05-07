import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_instagram_clone/data/firebase_service/firestore.dart';
import 'package:flutter_instagram_clone/util/exception.dart';

class Authentication {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> login({required String email, required String password}) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
    } on FirebaseAuthException catch (e) {
      throw exceptions(e.message ?? 'Login failed');
    }
  }

  Future<void> signup({
    required String email,
    required String password,
    required String passwordConfirm,
    required String username,
    required String bio,
    String? imageUrl,
  }) async {
    try {
      if (email.isEmpty ||
          password.isEmpty ||
          username.isEmpty ||
          bio.isEmpty) {
        throw exceptions('Please fill in all the fields.');
      }

      if (password != passwordConfirm) {
        throw exceptions('Password and Confirm Password must match.');
      }

      // Tạo tài khoản
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      final uid = userCredential.user!.uid;

      // Lưu người dùng vào Firestore
      await FirebaseFirestoreService().createUser(
        uid: uid,
        email: email,
        username: username,
        bio: bio,
        imageUrl: imageUrl ?? '', // Lưu ảnh vào Firestore
      );
    } on FirebaseAuthException catch (e) {
      throw exceptions(e.message ?? 'Signup failed');
    }
  }
}
