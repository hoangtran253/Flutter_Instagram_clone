import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';

class EditProfileScreen extends StatefulWidget {
  final String currentUsername;
  final String currentBio;
  final String currentAvatarUrl;

  const EditProfileScreen({
    super.key,
    required this.currentUsername,
    required this.currentBio,
    required this.currentAvatarUrl,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  late TextEditingController _usernameController;
  late TextEditingController _bioController;
  File? _imageFile;
  bool _isLoading = false;
  String _avatarUrl = '';

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: widget.currentUsername);
    _bioController = TextEditingController(text: widget.currentBio);
    _avatarUrl = widget.currentAvatarUrl;
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _selectImage() async {
    final XFile? selected = await _picker.pickImage(
      source: ImageSource.gallery,
    );
    if (selected != null) {
      setState(() {
        _imageFile = File(selected.path);
      });
    }
  }

  Future<String> _uploadImage() async {
    if (_imageFile == null) return _avatarUrl;

    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Người dùng chưa đăng nhập');

      final storageRef = _storage.ref().child('profile_images/${user.uid}');
      final uploadTask = storageRef.putFile(_imageFile!);
      final snapshot = await uploadTask;

      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print('Error uploading image: $e');
      throw e;
    }
  }

  Future<void> _saveProfile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Người dùng chưa đăng nhập');

      // Upload image if selected
      String avatarUrl = _avatarUrl;
      if (_imageFile != null) {
        avatarUrl = await _uploadImage();
      }

      // Update profile in Firestore
      await _firestore.collection('users').doc(user.uid).update({
        'username': _usernameController.text.trim(),
        'bio': _bioController.text.trim(),
        'avatarUrl': avatarUrl,
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cập nhật hồ sơ thành công')),
      );

      // Return to profile screen
      Navigator.pop(context);
    } catch (e) {
      print('Error saving profile: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Không thể cập nhật hồ sơ')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chỉnh sửa hồ sơ'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _isLoading ? null : _saveProfile,
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: EdgeInsets.all(16.w),
                child: Column(
                  children: [
                    // Avatar
                    GestureDetector(
                      onTap: _selectImage,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 50.r,
                            backgroundImage:
                                _imageFile != null
                                    ? FileImage(_imageFile!) as ImageProvider
                                    : (_avatarUrl.isNotEmpty
                                        ? NetworkImage(_avatarUrl)
                                        : const AssetImage('images/person.png')
                                            as ImageProvider),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: EdgeInsets.all(4.w),
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 20.w,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 20.h),

                    // Username field
                    TextField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: 'Tên người dùng',
                        hintText: 'Nhập tên người dùng',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 16.h),

                    // Bio field
                    TextField(
                      controller: _bioController,
                      decoration: const InputDecoration(
                        labelText: 'Tiểu sử',
                        hintText: 'Viết gì đó về bạn',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
    );
  }
}
