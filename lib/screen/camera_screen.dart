import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;

class CameraScreen extends StatefulWidget {
  final Function(dynamic, bool) onMediaCaptured;

  const CameraScreen({Key? key, required this.onMediaCaptured})
    : super(key: key);

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  List<CameraDescription> cameras = [];
  bool _isRearCameraSelected = true;
  bool _isRecording = false;
  bool _isVideoMode = false;
  bool _isFlashOn = false;
  Timer? _recordingTimer;
  int _recordingSeconds = 0;
  bool _isCameraInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _recordingTimer?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      if (_cameraController != null) {
        _initializeCamera();
      }
    }
  }

  Future<void> _initializeCamera() async {
    cameras = await availableCameras();
    int cameraIndex = _isRearCameraSelected ? 0 : 1;

    if (cameras.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No camera available')));
      return;
    }

    if (cameraIndex >= cameras.length) {
      cameraIndex = 0;
    }

    await _setupCamera(cameras[cameraIndex]);
  }

  Future<void> _setupCamera(CameraDescription camera) async {
    if (_cameraController != null) {
      await _cameraController!.dispose();
    }

    _cameraController = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: true,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await _cameraController!.initialize();
      await _cameraController!.setFlashMode(
        _isFlashOn ? FlashMode.torch : FlashMode.off,
      );

      setState(() {
        _isCameraInitialized = true;
      });
    } catch (e) {
      print('Error initializing camera: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error initializing camera: $e')));
    }
  }

  Future<void> _takePicture() async {
    if (!_cameraController!.value.isInitialized) {
      return;
    }

    try {
      final XFile file = await _cameraController!.takePicture();
      final Uint8List bytes = await file.readAsBytes();

      Uint8List finalBytes = bytes;
      if (!_isRearCameraSelected) {
        final img.Image? decodedImage = img.decodeImage(bytes);
        if (decodedImage != null) {
          final img.Image flippedImage = img.flipHorizontal(decodedImage);
          finalBytes = Uint8List.fromList(img.encodeJpg(flippedImage));
        }
      }

      File(file.path).deleteSync();

      widget.onMediaCaptured(finalBytes, false);
    } catch (e) {
      print('Error taking picture: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error taking picture: $e')));
    }
  }

  Future<void> _startVideoRecording() async {
    if (!_cameraController!.value.isInitialized || _isRecording) {
      return;
    }

    try {
      await _cameraController!.startVideoRecording();
      setState(() {
        _isRecording = true;
        _recordingSeconds = 0;
      });

      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _recordingSeconds++;
        });

        if (_recordingSeconds >= 60) {
          _stopVideoRecording();
        }
      });
    } catch (e) {
      print('Error starting video recording: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error starting video recording: $e')),
      );
    }
  }

  Future<void> _stopVideoRecording() async {
    if (!_isRecording) return;

    _recordingTimer?.cancel();
    _recordingTimer = null;

    try {
      final XFile file = await _cameraController!.stopVideoRecording();
      setState(() {
        _isRecording = false;
      });

      String finalVideoPath = file.path;
      print(
        'Video gốc: $finalVideoPath, exists: ${File(finalVideoPath).existsSync()}',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sử dụng video gốc để kiểm tra trên Instagram')),
      );

      widget.onMediaCaptured(finalVideoPath, true);
    } catch (e) {
      print('Lỗi dừng quay video: $e');
      setState(() {
        _isRecording = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi dừng quay video: $e')));
    }
  }

  void _toggleCameraMode() {
    setState(() {
      _isVideoMode = !_isVideoMode;
    });
  }

  void _toggleCamera() async {
    setState(() {
      _isRearCameraSelected = !_isRearCameraSelected;
      _isCameraInitialized = false;
    });

    int cameraIndex = _isRearCameraSelected ? 0 : 1;

    if (cameras.length > cameraIndex) {
      await _setupCamera(cameras[cameraIndex]);
    }
  }

  void _toggleFlash() async {
    setState(() {
      _isFlashOn = !_isFlashOn;
    });

    await _cameraController!.setFlashMode(
      _isFlashOn ? FlashMode.torch : FlashMode.off,
    );
  }

  String _formatDuration() {
    final minutes = (_recordingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_recordingSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: Container(
                height: 600.h,
                width: double.infinity,
                color: Colors.black,
                child: AspectRatio(
                  aspectRatio: _cameraController!.value.aspectRatio,
                  child: CameraPreview(_cameraController!),
                ),
              ),
            ),
            Positioned(
              top: 16.h,
              left: 16.w,
              right: 16.w,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: Colors.white, size: 28.sp),
                  ),
                  if (_isRecording)
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 6.h,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.fiber_manual_record,
                            color: Colors.white,
                            size: 14.sp,
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            _formatDuration(),
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14.sp,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Row(
                      children: [
                        IconButton(
                          onPressed: _toggleFlash,
                          icon: Icon(
                            _isFlashOn ? Icons.flash_on : Icons.flash_off,
                            color: Colors.white,
                            size: 24.sp,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            Positioned(
              bottom: 32.h,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  if (!_isRecording)
                    Container(
                      margin: EdgeInsets.only(bottom: 24.h),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton(
                            onPressed: _isVideoMode ? _toggleCameraMode : null,
                            child: Text(
                              'Photo',
                              style: TextStyle(
                                color:
                                    !_isVideoMode
                                        ? Colors.white
                                        : Colors.grey.shade400,
                                fontWeight:
                                    !_isVideoMode
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                fontSize: 16.sp,
                              ),
                            ),
                          ),
                          SizedBox(width: 24.w),
                          TextButton(
                            onPressed: !_isVideoMode ? _toggleCameraMode : null,
                            child: Text(
                              'Video',
                              style: TextStyle(
                                color:
                                    _isVideoMode
                                        ? Colors.white
                                        : Colors.grey.shade400,
                                fontWeight:
                                    _isVideoMode
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                fontSize: 16.sp,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        onPressed: () {},
                        icon: Icon(Icons.circle, color: Colors.transparent),
                      ),
                      GestureDetector(
                        onTap:
                            _isVideoMode
                                ? (_isRecording
                                    ? _stopVideoRecording
                                    : _startVideoRecording)
                                : _takePicture,
                        onLongPress: _isVideoMode ? _startVideoRecording : null,
                        onLongPressUp:
                            _isVideoMode && _isRecording
                                ? _stopVideoRecording
                                : null,
                        child: Container(
                          height: 80.h,
                          width: 80.w,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4.w),
                            color:
                                _isRecording ? Colors.red : Colors.transparent,
                          ),
                          child: Center(
                            child: AnimatedContainer(
                              duration: Duration(milliseconds: 300),
                              height: _isRecording ? 30.h : 70.h,
                              width: _isRecording ? 30.w : 70.w,
                              decoration: BoxDecoration(
                                color: _isRecording ? Colors.red : Colors.white,
                                shape:
                                    _isRecording
                                        ? BoxShape.rectangle
                                        : BoxShape.circle,
                                borderRadius:
                                    _isRecording
                                        ? BorderRadius.circular(8.r)
                                        : null,
                              ),
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _toggleCamera,
                        icon: Icon(
                          Icons.flip_camera_ios_outlined,
                          color: Colors.white,
                          size: 30.sp,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
