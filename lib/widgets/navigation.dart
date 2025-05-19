import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_instagram_clone/screen/add_screen.dart';
import 'package:flutter_instagram_clone/screen/explor_screen.dart';
import 'package:flutter_instagram_clone/screen/home.dart';
import 'package:flutter_instagram_clone/screen/profile_screen.dart';
import 'package:flutter_instagram_clone/screen/reelsScreen.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class Navigations_Screen extends StatefulWidget {
  const Navigations_Screen({super.key});

  @override
  State<Navigations_Screen> createState() => _Navigations_ScreenState();
}

int _currentIndex = 0;

class _Navigations_ScreenState extends State<Navigations_Screen> {
  late PageController pageController;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  late String userName;
  late String imageUrl; // Để lưu URL của ảnh người dùng

  @override
  void initState() {
    super.initState();
    pageController = PageController();

    // Lấy thông tin người dùng từ Firebase Auth
    final user = _auth.currentUser;
    if (user != null) {
      userName = user.displayName ?? 'Unknown';
      imageUrl =
          user.photoURL ??
          'default_profile_image_url'; // Đặt ảnh mặc định nếu không có ảnh
    } else {
      userName = 'Unknown';
      imageUrl = 'default_profile_image_url';
    }
  }

  @override
  void dispose() {
    super.dispose();
    pageController.dispose();
  }

  onPageChanged(int page) {
    setState(() {
      _currentIndex = page;
    });
  }

  navigationTapped(int page) {
    pageController.jumpToPage(page);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: Container(
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Colors.black,
          unselectedItemColor: Colors.grey,
          currentIndex: _currentIndex,
          onTap: navigationTapped,
          items: [
            const BottomNavigationBarItem(icon: Icon(Icons.home), label: ''),
            const BottomNavigationBarItem(icon: Icon(Icons.search), label: ''),
            const BottomNavigationBarItem(icon: Icon(Icons.camera), label: ''),
            BottomNavigationBarItem(
              icon: Image.asset(
                'images/instagram-reels-icon.png',
                height: 20.h,
              ),
              label: '',
            ),
            const BottomNavigationBarItem(icon: Icon(Icons.person), label: ''),
          ],
        ),
      ),
      body: PageView(
        controller: pageController,
        onPageChanged: onPageChanged,
        children: [
          HomeScreen(),
          ExplorScreen(),
          AddScreen(),
          ReelsScreen(),
          ProfileScreen(),
        ],
      ),
    );
  }
}
