import 'package:flutter/material.dart';
import 'package:flutter_instagram_clone/screen/add_post_screen.dart';
import 'package:flutter_instagram_clone/screen/add_reels_screen.dart';
import 'package:flutter_instagram_clone/screen/camera_screen.dart'; // New import for camera screen
import 'package:flutter_instagram_clone/widgets/navigation.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AddScreen extends StatefulWidget {
  final VoidCallback? onBackToHome;

  const AddScreen({super.key, this.onBackToHome}); // cập nhật constructor

  @override
  State<AddScreen> createState() => _AddScreenState();
}

class _AddScreenState extends State<AddScreen> {
  late PageController pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    pageController = PageController();
  }

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }

  void onPageChanged(int page) {
    setState(() {
      _currentIndex = page;
    });
  }

  void navigationTapped(int page) {
    pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // PageView toàn màn hình
          PageView(
            controller: pageController,
            onPageChanged: onPageChanged,
            children: const [AddPostScreen(), AddReelScreen()],
          ),

          // Nút quay lại, đặt trong SafeArea và Positioned
          Positioned(
            top: 10,
            left: 10,
            child: SafeArea(
              child: GestureDetector(
                onTap: () {
                  if (widget.onBackToHome != null) {
                    widget.onBackToHome!();
                  }
                },
                child: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.arrow_back, color: Colors.white),
                ),
              ),
            ),
          ),

          // Nút chuyển Post / Reels như cũ
          Positioned(
            bottom: 20.h,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 230.w,
                height: 48.h,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(24.r),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    AnimatedAlign(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCirc,
                      alignment:
                          _currentIndex == 0
                              ? Alignment.centerLeft
                              : Alignment.centerRight,
                      child: Container(
                        width: 115.w,
                        height: 48.h,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(24.r),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => navigationTapped(0),
                            child: Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.grid_on,
                                    size: 18.sp,
                                    color:
                                        _currentIndex == 0
                                            ? Colors.white
                                            : Colors.grey.shade300,
                                  ),
                                  SizedBox(width: 6.w),
                                  Text(
                                    'Post',
                                    style: TextStyle(
                                      fontSize: 15.sp,
                                      fontWeight: FontWeight.w600,
                                      color:
                                          _currentIndex == 0
                                              ? Colors.white
                                              : Colors.grey.shade300,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => navigationTapped(1),
                            child: Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.play_circle_outline,
                                    size: 18.sp,
                                    color:
                                        _currentIndex == 1
                                            ? Colors.white
                                            : Colors.grey.shade300,
                                  ),
                                  SizedBox(width: 6.w),
                                  Text(
                                    'Reels',
                                    style: TextStyle(
                                      fontSize: 15.sp,
                                      fontWeight: FontWeight.w600,
                                      color:
                                          _currentIndex == 1
                                              ? Colors.white
                                              : Colors.grey.shade300,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
