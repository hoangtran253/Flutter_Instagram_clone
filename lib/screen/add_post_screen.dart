import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';

class AddPostScreen extends StatefulWidget {
  const AddPostScreen({super.key});

  @override
  State<AddPostScreen> createState() => _AddPostScreenState();
}

class _AddPostScreenState extends State<AddPostScreen> {
  Uint8List? _imageData;
  File? _imageFile;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);

    if (picked != null) {
      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _imageData = bytes;
          _imageFile = null;
        });
      } else {
        setState(() {
          _imageFile = File(picked.path);
          _imageData = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedImage =
        _imageFile != null
            ? Image.file(_imageFile!, fit: BoxFit.cover)
            : _imageData != null
            ? Image.memory(_imageData!, fit: BoxFit.cover)
            : const Center(child: Text('Chưa chọn ảnh'));

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('New Post', style: TextStyle(color: Colors.black)),
        actions: [
          if (_imageData != null || _imageFile != null)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 10.w),
              child: TextButton(
                onPressed: () {
                  // TODO: Gọi hàm upload bài viết ở đây
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Đã đăng bài thành công!")),
                  );
                },
                child: Text(
                  'Đăng',
                  style: TextStyle(fontSize: 15.sp, color: Colors.blue),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Container(
            height: 375.h,
            width: double.infinity,
            color: Colors.grey.shade300,
            child: selectedImage,
          ),
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
