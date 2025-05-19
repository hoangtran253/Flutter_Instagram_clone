import 'package:flutter/material.dart';
import 'package:flutter_instagram_clone/screen/add_post_screen.dart';
import 'package:flutter_instagram_clone/screen/add_reels_screen.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AddScreen extends StatefulWidget {
  const AddScreen({super.key});

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
      body: SafeArea(
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            PageView(
              controller: pageController,
              onPageChanged: onPageChanged,
              children: const [AddPostScreen(), AddReelScreen()],
            ),
            Positioned(
              bottom: 10.h,
              child: Container(
                width: 200.w,
                height: 40.h,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Stack(
                  children: [
                    // Indicator
                    AnimatedAlign(
                      duration: const Duration(milliseconds: 300),
                      alignment:
                          _currentIndex == 0
                              ? Alignment.centerLeft
                              : Alignment.centerRight,
                      child: Container(
                        width: 100.w,
                        height: 40.h,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20.r),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => navigationTapped(0),
                            child: Center(
                              child: Text(
                                'Post',
                                style: TextStyle(
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.w500,
                                  color:
                                      _currentIndex == 0
                                          ? Colors.white
                                          : Colors.grey,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => navigationTapped(1),
                            child: Center(
                              child: Text(
                                'Reels',
                                style: TextStyle(
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.w500,
                                  color:
                                      _currentIndex == 1
                                          ? Colors.white
                                          : Colors.grey,
                                ),
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
          ],
        ),
      ),
    );
  }
}
