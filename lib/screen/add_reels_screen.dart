import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_instagram_clone/screen/camera_screen.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:path_provider/path_provider.dart';

class AddReelScreen extends StatefulWidget {
  final Function(Map<String, dynamic>)? onUpload; // callback dữ liệu post
  final dynamic capturedVideoData; // Can be a file path (String) or Uint8List

  const AddReelScreen({super.key, this.onUpload, this.capturedVideoData});

  @override
  State<AddReelScreen> createState() => _AddReelScreenState();
}

class _AddReelScreenState extends State<AddReelScreen> {
  final TextEditingController _captionController = TextEditingController();
  XFile? _videoFile;
  VideoPlayerController? _videoController;
  bool _isUploading = false;
  bool _isVideoSelected = false;
  String? _username;
  String? _avatarUrl;
  File? _videoFileFromBytes;

  final ImagePicker _picker = ImagePicker();

  // Thay bằng thông tin cloudinary của bạn
  final String cloudName = 'dv8bbvd5q';
  final String uploadPreset = 'instagram_video';

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _handleCapturedVideo();
  }

  Future<void> _handleCapturedVideo() async {
    if (widget.capturedVideoData != null) {
      if (widget.capturedVideoData is String) {
        // If it's a file path from camera
        _videoFile = XFile(widget.capturedVideoData);
        _initializeVideoController(_videoFile!.path);
        setState(() {
          _isVideoSelected = true;
        });
      } else if (widget.capturedVideoData is Uint8List) {
        // If it's binary data, save to a temp file
        final tempDir = await getTemporaryDirectory();
        final tempPath = '${tempDir.path}/temp_video.mp4';

        final file = File(tempPath);
        await file.writeAsBytes(widget.capturedVideoData);

        _videoFile = XFile(tempPath);
        _videoFileFromBytes = file;
        _initializeVideoController(tempPath);
        setState(() {
          _isVideoSelected = true;
        });
      }
    }
  }

  void _initializeVideoController(String videoPath) {
    _videoController?.dispose();
    _videoController = VideoPlayerController.file(File(videoPath))
      ..initialize().then((_) {
        setState(() {});
        _videoController!.setLooping(true);
        _videoController!.play();
      });
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
      _initializeVideoController(_videoFile!.path);
      setState(() {
        _isVideoSelected = true;
      });
    }
  }

  // New method to record video directly
  Future<void> _recordVideo() async {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) => CameraScreen(
              onMediaCaptured: (mediaData, isVideo) {
                if (isVideo) {
                  _videoFile = XFile(mediaData);
                  _initializeVideoController(_videoFile!.path);
                  setState(() {
                    _isVideoSelected = true;
                  });
                } else {
                  // If a photo was taken instead of video, show an error
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Vui lòng quay video cho Reels')),
                  );
                }
              },
            ),
      ),
    );
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

  // Hàm tạo thumbnail URL từ video URL Cloudinary
  String getThumbnailUrlFromVideoUrl(String videoUrl) {
    if (!videoUrl.contains('/video/upload/')) return '';

    final parts = videoUrl.split('/video/upload/');
    final prefix = parts[0];
    final suffix = parts[1]; // v1234567890/sample_video.mp4

    final segments = suffix.split('/');
    if (segments.length < 2) return ''; // tránh lỗi index

    final version = segments[0]; // v1234567890
    final fileName = segments[1]; // sample_video.mp4

    final fileNameWithoutExt = fileName.split('.').first; // sample_video

    final thumbnailUrl =
        '$prefix/video/upload/so_0/$version/$fileNameWithoutExt.jpg';

    return thumbnailUrl;
  }

  void _uploadReel() async {
    if (_videoFile == null || _captionController.text.trim().isEmpty) {
      print("Video URL rỗng sau khi upload");
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

      // Tạo thumbnail URL
      final thumbnailUrl = getThumbnailUrlFromVideoUrl(videoUrl);

      final reelData = {
        'caption': _captionController.text.trim(),
        'videoUrl': videoUrl,
        'thumbnailUrl': thumbnailUrl,
        'postTime': FieldValue.serverTimestamp(),
        'uid': currentUser!.uid,
        'username': _username,
        'avatarUrl': _avatarUrl,
        'likes': [], // Initialize empty likes array
        'comments': [], // Initialize empty comments array
        'commentsCount': 0,
        'likesCount': 0,
      };

      // Lưu vào Firestore collection 'reels' thay vì 'posts'
      await FirebaseFirestore.instance.collection('reels').add(reelData);

      // Gửi dữ liệu về ReelsScreen nếu cần
      widget.onUpload?.call(reelData);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Reel đã được đăng thành công')));

      // Clean up temp file if needed
      if (_videoFileFromBytes != null) {
        await _videoFileFromBytes!.delete();
      }

      // Return to home screen
      Navigator.of(context).popUntil((route) => route.isFirst);
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
    // Cleanup temp file if exists and was not already deleted
    _videoFileFromBytes?.delete().ignore();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Tạo Reels mới',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.black),
        actions: [
          TextButton(
            onPressed: _isVideoSelected && !_isUploading ? _uploadReel : null,
            child: Text(
              'Đăng',
              style: TextStyle(
                color:
                    _isVideoSelected && !_isUploading
                        ? Colors.blue
                        : Colors.grey,
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(15.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thông tin người dùng
              if (_username != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 20.r,
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
              SizedBox(height: 8.h),

              // Caption
              TextField(
                controller: _captionController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Viết chú thích...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 4.w),
                ),
              ),
              SizedBox(height: 10.h),

              // Video preview
              Container(
                width: double.infinity,
                height: 350.h,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12.r),
                  child:
                      _videoFile == null
                          ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.videocam_outlined,
                                  size: 64.sp,
                                  color: Colors.white.withOpacity(0.7),
                                ),
                                SizedBox(height: 12.h),
                                Text(
                                  'Chọn hoặc quay video',
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    color: Colors.white.withOpacity(0.7),
                                  ),
                                ),
                              ],
                            ),
                          )
                          : _videoController != null &&
                              _videoController!.value.isInitialized
                          ? AspectRatio(
                            aspectRatio: _videoController!.value.aspectRatio,
                            child: VideoPlayer(_videoController!),
                          )
                          : Center(child: CircularProgressIndicator()),
                ),
              ),
              SizedBox(height: 24.h),

              // Video source options
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _mediaSourceOption(
                    icon: Icons.video_library,
                    label: 'Thư viện',
                    onTap: _pickVideo,
                  ),
                  _mediaSourceOption(
                    icon: Icons.videocam,
                    label: 'Quay video',
                    onTap: _recordVideo,
                  ),
                ],
              ),

              SizedBox(height: 20.h),

              if (_isUploading)
                Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12.h),
                      Text(
                        'Đang đăng Reels...',
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mediaSourceOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 150.w,
        padding: EdgeInsets.symmetric(vertical: 16.h),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32.sp, color: Colors.black87),
            SizedBox(height: 8.h),
            Text(
              label,
              style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
