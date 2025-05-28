// screen/add_story_screen.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_instagram_clone/screen/camera_screen.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:path_provider/path_provider.dart';

class AddStoryScreen extends StatefulWidget {
  final Function(Map<String, dynamic>)? onUpload; // Callback for story data

  const AddStoryScreen({super.key, this.onUpload});

  @override
  State<AddStoryScreen> createState() => _AddStoryScreenState();
}

class _AddStoryScreenState extends State<AddStoryScreen> {
  XFile? _mediaFile; // Can be image or video
  VideoPlayerController? _videoController;
  bool _isUploading = false;
  bool _isMediaSelected = false;
  bool _isVideo = false; // Track if selected media is video
  String? _username;
  String? _avatarUrl;
  File? _mediaFileFromBytes;
  Uint8List? _webMediaBytes;

  final ImagePicker _picker = ImagePicker();

  // Cloudinary configuration
  final String cloudName = 'dv8bbvd5q';
  final String imageUploadPreset = 'instagram_image'; // Preset for images
  final String videoUploadPreset = 'instagram_video'; // Preset for videos

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

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      if (kIsWeb) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _webMediaBytes = bytes;
          _mediaFile = pickedFile;
          _isMediaSelected = true;
          _isVideo = false;
          _videoController?.dispose();
          _videoController = null;
        });
      } else {
        setState(() {
          _mediaFile = pickedFile;
          _isMediaSelected = true;
          _isVideo = false;
          _videoController?.dispose();
          _videoController = null;
        });
      }
    }
  }

  Future<void> _pickVideo() async {
    final pickedFile = await _picker.pickVideo(source: ImageSource.gallery);
    if (pickedFile != null) {
      if (kIsWeb) {
        final bytes = await pickedFile.readAsBytes();
        final tempDir = await getTemporaryDirectory();
        final tempPath = '${tempDir.path}/temp_video.mp4';
        final file = File(tempPath);
        await file.writeAsBytes(bytes);
        _mediaFile = XFile(tempPath);
      } else {
        _mediaFile = pickedFile;
      }

      _initializeVideoController(_mediaFile!.path);
      setState(() {
        _webMediaBytes = null;
        _isMediaSelected = true;
        _isVideo = true;
      });
    }
  }

  Future<void> _recordMedia() async {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) => CameraScreen(
              onMediaCaptured: (mediaData, isVideo) async {
                if (mediaData is String) {
                  _mediaFile = XFile(mediaData);
                  if (isVideo) {
                    _initializeVideoController(_mediaFile!.path);
                    setState(() {
                      _isMediaSelected = true;
                      _isVideo = true;
                    });
                  } else {
                    setState(() {
                      _isMediaSelected = true;
                      _isVideo = false;
                      _videoController?.dispose();
                      _videoController = null;
                    });
                  }
                } else if (mediaData is Uint8List) {
                  final tempDir = await getTemporaryDirectory();
                  final tempPath =
                      '${tempDir.path}/${isVideo ? 'temp_video.mp4' : 'temp_image.jpg'}';
                  final file = File(tempPath);
                  await file.writeAsBytes(mediaData);
                  _mediaFile = XFile(tempPath);
                  _mediaFileFromBytes = file;
                  if (isVideo) {
                    _initializeVideoController(tempPath);
                    setState(() {
                      _isMediaSelected = true;
                      _isVideo = true;
                    });
                  } else {
                    setState(() {
                      _isMediaSelected = true;
                      _isVideo = false;
                      _videoController?.dispose();
                      _videoController = null;
                    });
                  }
                }
              },
            ),
      ),
    );
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

  Future<String?> _uploadMediaToCloudinary(
    XFile mediaFile,
    bool isVideo,
  ) async {
    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$cloudName/${isVideo ? 'video' : 'image'}/upload',
    );
    final request = http.MultipartRequest('POST', uri);

    request.fields['upload_preset'] =
        isVideo ? videoUploadPreset : imageUploadPreset;

    final bytes = kIsWeb ? _webMediaBytes! : await mediaFile.readAsBytes();

    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: mediaFile.name),
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

  String _getThumbnailUrlFromVideoUrl(String videoUrl) {
    if (!videoUrl.contains('/video/upload/')) return '';
    final parts = videoUrl.split('/video/upload/');
    final prefix = parts[0];
    final suffix = parts[1];
    final segments = suffix.split('/');
    if (segments.length < 2) return '';
    final version = segments[0];
    final fileName = segments[1];
    final fileNameWithoutExt = fileName.split('.').first;
    return '$prefix/video/upload/so_0/$version/$fileNameWithoutExt.jpg';
  }

  Future<void> _uploadStory() async {
    if (_mediaFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Vui lòng chọn hoặc quay hình ảnh/video')),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    String? mediaUrl = await _uploadMediaToCloudinary(_mediaFile!, _isVideo);
    if (mediaUrl != null) {
      final currentUser = FirebaseAuth.instance.currentUser;
      final storyData = {
        'userId': currentUser!.uid,
        'username': _username,
        'avatarUrl': _avatarUrl,
        'imageUrls':
            _isVideo ? [_getThumbnailUrlFromVideoUrl(mediaUrl)] : [mediaUrl],
        'videoUrl': _isVideo ? mediaUrl : null,
        'timestamp': FieldValue.serverTimestamp(),
        'viewedBy': [],
      };

      await FirebaseFirestore.instance.collection('stories').add(storyData);

      widget.onUpload?.call(storyData);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Story đã được đăng thành công')));

      // Clean up temp file if needed
      if (_mediaFileFromBytes != null) {
        await _mediaFileFromBytes!.delete();
      }
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Upload story thất bại')));
    }

    setState(() {
      _isUploading = false;
    });
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _mediaFileFromBytes?.delete().ignore();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Tạo Story mới',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.black),
        actions: [
          TextButton(
            onPressed: _isMediaSelected && !_isUploading ? _uploadStory : null,
            child: Text(
              'Đăng',
              style: TextStyle(
                color:
                    _isMediaSelected && !_isUploading
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
              // User Info
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
                      fontWeight: FontWeight.w600,
                      fontSize: 16.sp,
                    ),
                  ),
                ),
              SizedBox(height: 16.h),

              // Media Preview
              Container(
                width: double.infinity,
                height: 350.h,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.all(Radius.circular(8.r)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.all(Radius.circular(8.r)),
                  child:
                      _mediaFile == null
                          ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.camera_alt,
                                  size: 64.sp,
                                  color: Colors.white.withOpacity(0.7),
                                ),
                                SizedBox(height: 12.h),
                                Text(
                                  'Chọn hoặc quay hình ảnh/video',
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    color: Colors.white.withOpacity(0.7),
                                  ),
                                ),
                              ],
                            ),
                          )
                          : _isVideo &&
                              _videoController != null &&
                              _videoController!.value.isInitialized
                          ? AspectRatio(
                            aspectRatio: _videoController!.value.aspectRatio,
                            child: VideoPlayer(_videoController!),
                          )
                          : kIsWeb && _webMediaBytes != null
                          ? Image.memory(_webMediaBytes!, fit: BoxFit.cover)
                          : Image.file(
                            File(_mediaFile!.path),
                            fit: BoxFit.cover,
                            errorBuilder:
                                (context, error, stackTrace) => Icon(
                                  Icons.error,
                                  color: Colors.white,
                                  size: 50.sp,
                                ),
                          ),
                ),
              ),
              SizedBox(height: 24.h),

              // Media Source Options
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _mediaSourceOption(
                    icon: Icons.image,
                    label: 'Hình ảnh',
                    onTap: _pickImage,
                  ),
                  _mediaSourceOption(
                    icon: Icons.video_library,
                    label: 'Video',
                    onTap: _pickVideo,
                  ),
                  _mediaSourceOption(
                    icon: Icons.camera_alt,
                    label: 'Camera',
                    onTap: _recordMedia,
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
                        'Đang đăng Story...',
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              SizedBox(height: 20.h),
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
        width: 100.w,
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
