import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AddReelScreen extends StatefulWidget {
  final Function(Map<String, dynamic>)? onUpload; // callback dữ liệu post

  const AddReelScreen({super.key, this.onUpload});

  @override
  State<AddReelScreen> createState() => _AddReelScreenState();
}

class _AddReelScreenState extends State<AddReelScreen> {
  final TextEditingController _captionController = TextEditingController();
  XFile? _videoFile;
  VideoPlayerController? _videoController;
  bool _isUploading = false;
  String? _username;
  String? _avatarUrl;

  final ImagePicker _picker = ImagePicker();

  // Thay bằng thông tin cloudinary của bạn
  final String cloudName = 'dv8bbvd5q';
  final String uploadPreset = 'instagram_video';

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .get();

      if (userDoc.exists) {
        final data = userDoc.data()!;
        setState(() {
          _username = data['username'];
          _avatarUrl = data['avatarUrl'];
        });
      }
    }
  }

  Future<void> _pickVideo() async {
    final pickedFile = await _picker.pickVideo(source: ImageSource.gallery);

    if (pickedFile != null) {
      _videoFile = pickedFile;

      _videoController?.dispose();
      _videoController = VideoPlayerController.network(_videoFile!.path)
        ..initialize().then((_) {
          setState(() {});
          _videoController!.setLooping(true);
          _videoController!.play();
        });
    }
  }

  Future<String?> uploadVideoToCloudinary(XFile videoFile) async {
    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$cloudName/video/upload',
    );
    final request = http.MultipartRequest('POST', uri);

    request.fields['upload_preset'] = uploadPreset;
    request.files.add(
      await http.MultipartFile.fromBytes(
        'file',
        await videoFile.readAsBytes(),
        filename: videoFile.name,
      ),
    );

    try {
      final response = await request.send();
      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final jsonMap = json.decode(responseData);
        return jsonMap['secure_url'];
      } else {
        print('Upload failed with status: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Upload error: $e');
      return null;
    }
  }

  void _uploadReel() async {
    if (_videoFile == null || _captionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Vui lòng chọn video và nhập caption')),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    String? videoUrl = await uploadVideoToCloudinary(_videoFile!);

    if (videoUrl != null) {
      final currentUser = FirebaseAuth.instance.currentUser;

      final reelData = {
        'caption': _captionController.text.trim(),
        'videoUrl': videoUrl,
        'postTime': DateTime.now(),
        'uid': currentUser!.uid,
        'username': _username,
        'avatarUrl': _avatarUrl,
        'likes': [],
        'comments': 0,
      };

      // ➕ Lưu vào Firestore
      await FirebaseFirestore.instance.collection('reels').add(reelData);

      // Gửi về ReelsScreen nếu muốn
      widget.onUpload?.call(reelData);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Reel đã được đăng thành công')));
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Upload video thất bại')));
    }

    setState(() {
      _isUploading = false;
    });
  }

  @override
  void dispose() {
    _captionController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Tạo Reels mới'),
        actions: [
          TextButton(
            onPressed: _isUploading ? null : _uploadReel,
            child: Text(
              'Đăng',
              style: TextStyle(
                color: _isUploading ? Colors.grey : Colors.blue,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              _videoFile == null
                  ? GestureDetector(
                    onTap: _pickVideo,
                    child: Container(
                      height: 250,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.grey.shade200,
                      ),
                      child: Center(
                        child: Text(
                          'Chọn video từ thư viện',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      ),
                    ),
                  )
                  : AspectRatio(
                    aspectRatio: _videoController!.value.aspectRatio,
                    child: VideoPlayer(_videoController!),
                  ),
              SizedBox(height: 20),
              TextField(
                controller: _captionController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Viết chú thích',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              if (_isUploading)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: CircularProgressIndicator(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
