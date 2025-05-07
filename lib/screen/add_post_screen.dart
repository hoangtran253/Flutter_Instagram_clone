import 'dart:typed_data';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
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

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);

    if (picked != null) {
      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _imageData = bytes;
        });
      } else {
        setState(() {
          _imageData = null;
        });
      }
    }
  }

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

  Future<void> _handlePost() async {
    if (_imageData == null) return;

    final bytes = _imageData!;
    String? imageUrl = await uploadToCloudinary(bytes);

    if (imageUrl != null) {
      final post = {
        'username': 'currentUser',
        'location': 'Unknown',
        'caption': _captionController.text,
        'imageUrl': imageUrl,
        'postTime': DateTime.now().toIso8601String(), // lưu thời gian chuẩn
      };

      await FirebaseFirestore.instance.collection('posts').add(post);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Đăng bài thành công!")));

      setState(() {
        _imageData = null;
        _captionController.clear();
      });
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Tải ảnh lên thất bại.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Post', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            height: 375.h,
            width: double.infinity,
            color: Colors.grey.shade300,
            child:
                _imageData != null
                    ? Image.memory(_imageData!, fit: BoxFit.cover)
                    : const Center(child: Text('Chưa chọn ảnh')),
          ),
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
            child: TextField(
              controller: _captionController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Nhập nội dung bài viết...',
              ),
              maxLines: null,
            ),
          ),
          ElevatedButton(onPressed: _handlePost, child: const Text("Đăng bài")),
          Container(
            width: double.infinity,
            height: 40.h,
            color: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 10.w),
            alignment: Alignment.centerLeft,
            child: Text(
              'Chọn ảnh từ thiết bị',
              style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Center(
              child: ElevatedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.photo),
                label: const Text("Chọn ảnh"),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
