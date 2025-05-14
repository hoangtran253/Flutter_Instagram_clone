import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_instagram_clone/data/model/usermodel.dart';

class UserService {
  final CollectionReference usersCollection = FirebaseFirestore.instance
      .collection('users');

  // Thêm người dùng mới
  Future<void> createUser(Usermodel user) async {
    await usersCollection.doc(user.email).set(user.toMap());
  }

  // Lấy người dùng theo email (hoặc bạn có thể dùng uid nếu lưu theo uid)
  Future<Usermodel?> getUserByEmail(String email) async {
    final doc = await usersCollection.doc(email).get();
    if (doc.exists) {
      return Usermodel.fromMap(doc.data() as Map<String, dynamic>);
    }
    return null;
  }

  // Lấy người dùng theo ID (nếu bạn dùng uid làm document ID)
  Future<Usermodel?> getUserById(String id) async {
    final doc = await usersCollection.doc(id).get();
    if (doc.exists) {
      return Usermodel.fromMap(doc.data() as Map<String, dynamic>);
    }
    return null;
  }

  // Cập nhật thông tin người dùng
  Future<void> updateUser(String email, Map<String, dynamic> data) async {
    await usersCollection.doc(email).update(data);
  }

  // Lấy tất cả người dùng (ví dụ cho admin dashboard)
  Future<List<Usermodel>> getAllUsers() async {
    final snapshot = await usersCollection.get();
    return snapshot.docs
        .map((doc) => Usermodel.fromMap(doc.data() as Map<String, dynamic>))
        .toList();
  }
}
