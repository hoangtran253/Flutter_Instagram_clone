import 'dart:typed_data';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

class AddPostScreen extends StatefulWidget {
  const AddPostScreen({super.key});

  @override
  State<AddPostScreen> createState() => _AddPostScreenState();
}

class _AddPostScreenState extends State<AddPostScreen> {
  Uint8List? _imageData;
  TextEditingController _captionController = TextEditingController();

  final String cloudName = 'dv8bbvd5q';
  final String uploadPreset = 'instagram_image';
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _username;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  // Lấy thông tin người dùng từ Firestore
  String? _avatarUrl;

  Future<void> _fetchUserData() async {
    final uid = _auth.currentUser!.uid;
    DocumentSnapshot userSnap =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();

    final userData = userSnap.data() as Map<String, dynamic>;

    setState(() {
      _username = userData['username'];
      _avatarUrl = userData['avatarUrl']; // Lấy avatar
    });
  }

  // Chọn ảnh từ thiết bị
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);

    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _imageData = bytes;
      });
    }
  }

  // Tải ảnh lên Cloudinary
  Future<String?> uploadToCloudinary(Uint8List imageBytes) async {
    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
    );

    final request = http.MultipartRequest('POST', uri);
    request.fields['upload_preset'] = uploadPreset;
    request.files.add(
      http.MultipartFile.fromBytes('file', imageBytes, filename: 'post.jpg'),
    );

    try {
      final response = await request.send();
      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final jsonMap = json.decode(responseData);
        return jsonMap['secure_url'];
      } else {
        print('Upload failed: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Upload error: $e');
      return null;
    }
  }

  // Xử lý khi người dùng đăng bài
  Future<void> _handlePost() async {
    if (_imageData == null || _username == null) return;
    setState(() {
      _isLoading = true;
    });

    final bytes = _imageData!;
    String? imageUrl = await uploadToCloudinary(bytes);

    if (imageUrl != null) {
      final post = {
        'uid': _auth.currentUser!.uid,
        'username': _username,
        'caption': _captionController.text,
        'imageUrl': imageUrl,
        'avatarUrl': _avatarUrl,
        'postTime': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection('posts').add(post);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Đăng bài thành công!")));

      setState(() {
        _imageData = null;
        _captionController.clear();
        _isLoading = false;
      });
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Tải ảnh lên thất bại.")));

      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Tạo bài viết',
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hiển thị ảnh
              AspectRatio(
                aspectRatio: 1,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child:
                        _imageData != null
                            ? ClipRRect(
                              borderRadius: BorderRadius.circular(12.r),
                              child: Image.memory(
                                _imageData!,
                                key: ValueKey(_imageData),
                                fit: BoxFit.cover,
                              ),
                            )
                            : Center(
                              child: Text(
                                'Chưa chọn ảnh',
                                style: TextStyle(fontSize: 16.sp),
                              ),
                            ),
                  ),
                ),
              ),
              SizedBox(height: 16.h),

              // Thông tin người dùng
              if (_username != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundImage:
                        _avatarUrl != null
                            ? NetworkImage(_avatarUrl!)
                            : const AssetImage('assets/default_avatar.png')
                                as ImageProvider,
                  ),
                  title: Text(
                    _username!,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16.sp,
                    ),
                  ),
                ),
              SizedBox(height: 10.h),

              // Caption
              TextField(
                controller: _captionController,
                maxLines: null,
                decoration: InputDecoration(
                  hintText: 'Bạn đang nghĩ gì?',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 10.h,
                  ),
                ),
              ),
              SizedBox(height: 16.h),

              // Nút đăng bài
              SizedBox(
                width: double.infinity,
                height: 45.h,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handlePost,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                  ),
                  child:
                      _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                            "Đăng bài",
                            style: TextStyle(color: Colors.white),
                          ),
                ),
              ),
              SizedBox(height: 24.h),

              // Chọn ảnh
              Text(
                "Ảnh từ thiết bị",
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15.sp),
              ),
              SizedBox(height: 8.h),
              Center(
                child: OutlinedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.photo),
                  label: const Text("Chọn ảnh"),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      horizontal: 20.w,
                      vertical: 10.h,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 70.h),
            ],
          ),
        ),
      ),
    );
  }
}
