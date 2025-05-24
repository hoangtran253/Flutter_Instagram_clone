import 'dart:typed_data';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:camera/camera.dart';

class AddPostScreen extends StatefulWidget {
  final Uint8List? capturedImageData;

  const AddPostScreen({super.key, this.capturedImageData});

  @override
  State<AddPostScreen> createState() => _AddPostScreenState();
}

class _AddPostScreenState extends State<AddPostScreen> {
  List<Uint8List> _imageDataList = []; // Changed to List<Uint8List>
  TextEditingController _captionController = TextEditingController();

  final String cloudName = 'dv8bbvd5q';
  final String uploadPreset = 'instagram_image';
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _username;
  bool _isLoading = false;
  bool _isImageSelected = false;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _fetchUserData();

    // If image was captured from camera, add it to the list
    if (widget.capturedImageData != null) {
      setState(() {
        _imageDataList = [widget.capturedImageData!];
        _isImageSelected = true;
      });
    }
  }

  // Fetch user data from Firestore
  Future<void> _fetchUserData() async {
    final uid = _auth.currentUser!.uid;
    DocumentSnapshot userSnap =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();

    final userData = userSnap.data() as Map<String, dynamic>;

    setState(() {
      _username = userData['username'];
      _avatarUrl = userData['avatarUrl'];
    });
  }

  // Pick multiple images from gallery
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage(); // Use pickMultiImage

    if (pickedFiles.isNotEmpty) {
      List<Uint8List> newImages = [];
      for (var file in pickedFiles) {
        final bytes = await file.readAsBytes();
        newImages.add(bytes);
      }
      setState(() {
        _imageDataList.addAll(newImages); // Append new images
        _isImageSelected = true;
      });
    }
  }

  // Take photo directly
  Future<void> _takePicture() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No camera available')));
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) => CameraPreviewScreen(
              camera: cameras.first,
              onImageCaptured: (imageData) {
                setState(() {
                  _imageDataList.add(imageData); // Add captured image to list
                  _isImageSelected = true;
                });
              },
            ),
      ),
    );
  }

  // Upload multiple images to Cloudinary
  Future<List<String>> uploadToCloudinary(
    List<Uint8List> imageBytesList,
  ) async {
    List<String> imageUrls = [];
    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
    );

    for (int i = 0; i < imageBytesList.length; i++) {
      final request = http.MultipartRequest('POST', uri);
      request.fields['upload_preset'] = uploadPreset;
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          imageBytesList[i],
          filename: 'post_$i.jpg',
        ),
      );

      try {
        final response = await request.send();
        if (response.statusCode == 200) {
          final responseData = await response.stream.bytesToString();
          final jsonMap = json.decode(responseData);
          imageUrls.add(jsonMap['secure_url']);
        } else {
          print('Upload failed for image $i: ${response.statusCode}');
        }
      } catch (e) {
        print('Upload error for image $i: $e');
      }
    }
    return imageUrls;
  }

  // Handle post submission
  Future<void> _handlePost() async {
    if (_imageDataList.isEmpty || _username == null) return;
    setState(() {
      _isLoading = true;
    });

    List<String> imageUrls = await uploadToCloudinary(_imageDataList);

    if (imageUrls.isNotEmpty) {
      DocumentReference postRef =
          FirebaseFirestore.instance.collection('posts').doc();
      String postId = postRef.id;

      final post = {
        'postId': postId,
        'uid': _auth.currentUser!.uid,
        'username': _username,
        'caption': _captionController.text,
        'imageUrls': imageUrls, // Store list of image URLs
        'avatarUrl': _avatarUrl,
        'postTime': FieldValue.serverTimestamp(),
        'likes': [],
        'comments': [],
      };

      await postRef.set(post);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Đăng bài thành công!")));

      setState(() {
        _imageDataList.clear(); // Clear the image list
        _isImageSelected = false;
        _captionController.clear();
        _isLoading = false;
      });

      Navigator.of(context).popUntil((route) => route.isFirst);
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
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          TextButton(
            onPressed: _isImageSelected && !_isLoading ? _handlePost : null,
            child: Text(
              "Đăng",
              style: TextStyle(
                color:
                    _isImageSelected && !_isLoading ? Colors.blue : Colors.grey,
                fontWeight: FontWeight.bold,
                fontSize: 16.sp,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User info
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
              SizedBox(height: 12.h),

              // Caption
              TextField(
                controller: _captionController,
                maxLines: null,
                decoration: InputDecoration(
                  hintText: 'Viết chú thích...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 4.w,
                    vertical: 10.h,
                  ),
                ),
              ),
              SizedBox(height: 16.h),

              // Display multiple images
              Container(
                width: double.infinity,
                height: 360.h,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: Colors.grey.shade300, width: 1),
                ),
                child:
                    _imageDataList.isNotEmpty
                        ? ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _imageDataList.length,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: EdgeInsets.all(8.r),
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12.r),
                                    child: Image.memory(
                                      _imageDataList[index],
                                      width: 300.w,
                                      height: 360.h,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  Positioned(
                                    top: 8.h,
                                    right: 8.w,
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _imageDataList.removeAt(index);
                                          if (_imageDataList.isEmpty) {
                                            _isImageSelected = false;
                                          }
                                        });
                                      },
                                      child: CircleAvatar(
                                        radius: 16.r,
                                        backgroundColor: Colors.black54,
                                        child: Icon(
                                          Icons.close,
                                          color: Colors.white,
                                          size: 20.sp,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        )
                        : GestureDetector(
                          onTap: _pickImage,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_photo_alternate_outlined,
                                size: 64.sp,
                                color: Colors.grey.shade400,
                              ),
                              SizedBox(height: 12.h),
                              Text(
                                'Chọn ảnh từ thư viện',
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
              ),
              SizedBox(height: 24.h),

              // Media source options
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _mediaSourceOption(
                    icon: Icons.photo_library,
                    label: 'Thư viện',
                    onTap: _pickImage,
                  ),
                  _mediaSourceOption(
                    icon: Icons.camera_alt,
                    label: 'Chụp ảnh',
                    onTap: _takePicture,
                  ),
                ],
              ),

              SizedBox(height: 20.h),

              Divider(color: Colors.grey.shade300),

              SizedBox(height: 20.h),

              if (_isLoading)
                Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12.h),
                      Text(
                        'Đang đăng bài...',
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

// CameraPreviewScreen remains unchanged unless you want to allow multiple captures
class CameraPreviewScreen extends StatefulWidget {
  final CameraDescription camera;
  final Function(Uint8List) onImageCaptured;

  const CameraPreviewScreen({
    Key? key,
    required this.camera,
    required this.onImageCaptured,
  }) : super(key: key);

  @override
  State<CameraPreviewScreen> createState() => _CameraPreviewScreenState();
}

class _CameraPreviewScreenState extends State<CameraPreviewScreen>
    with WidgetsBindingObserver {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  bool _isRearCameraSelected = true;
  bool _isFlashOn = false;
  List<CameraDescription> cameras = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  Future<void> _initCamera() async {
    cameras = await availableCameras();
    _controller = CameraController(
      _isRearCameraSelected ? cameras.first : cameras.last,
      ResolutionPreset.high,
    );
    _initializeControllerFuture = _controller.initialize();
    setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      _controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _takePicture() async {
    try {
      await _initializeControllerFuture;
      final image = await _controller.takePicture();
      final bytes = await image.readAsBytes();
      widget.onImageCaptured(bytes);
      Navigator.pop(context);
    } catch (e) {
      print(e);
    }
  }

  void _toggleCamera() async {
    setState(() {
      _isRearCameraSelected = !_isRearCameraSelected;
    });
    await _controller.dispose();
    _controller = CameraController(
      _isRearCameraSelected ? cameras.first : cameras.last,
      ResolutionPreset.high,
    );
    _initializeControllerFuture = _controller.initialize();
  }

  void _toggleFlash() async {
    setState(() {
      _isFlashOn = !_isFlashOn;
    });
    await _controller.setFlashMode(
      _isFlashOn ? FlashMode.torch : FlashMode.off,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return Stack(
              children: [
                Positioned.fill(child: CameraPreview(_controller)),
                Positioned(
                  top: 40.h,
                  left: 16.w,
                  right: 16.w,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 28.sp,
                        ),
                      ),
                      IconButton(
                        onPressed: _toggleFlash,
                        icon: Icon(
                          _isFlashOn ? Icons.flash_on : Icons.flash_off,
                          color: Colors.white,
                          size: 28.sp,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 32.h,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.flip_camera_ios,
                          color: Colors.white,
                          size: 30.sp,
                        ),
                        onPressed: _toggleCamera,
                      ),
                      GestureDetector(
                        onTap: _takePicture,
                        child: Container(
                          height: 80.h,
                          width: 80.w,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4.w),
                          ),
                          child: Center(
                            child: Container(
                              height: 70.h,
                              width: 70.w,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 48.w),
                    ],
                  ),
                ),
              ],
            );
          } else {
            return Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}
