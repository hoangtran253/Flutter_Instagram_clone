import 'package:firebase_auth/firebase_auth.dart';
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

class _Navigations_ScreenState extends State<Navigations_Screen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late PageController pageController;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late AnimationController _animationController;
  late List<Animation<double>> _iconScales;

  late String userName;
  late String imageUrl;

  @override
  void initState() {
    super.initState();
    pageController = PageController(
      initialPage: _currentIndex,
      viewportFraction: 1.0, // Ensures full-screen pages
    );

    // Initialize animation controller for icon scaling
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    // Create scale animations for each bottom navigation icon
    _iconScales = List.generate(
      5,
      (index) => Tween<double>(begin: 1.0, end: 1.2).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
      ),
    );

    // Initialize user data
    final user = _auth.currentUser;
    if (user != null) {
      userName = user.displayName ?? 'Unknown';
      imageUrl = user.photoURL ?? '';
    } else {
      userName = 'Unknown';
      imageUrl = '';
    }
  }

  @override
  void dispose() {
    pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void onPageChanged(int page) {
    setState(() {
      _currentIndex = page;
    });
    // Trigger animation for the selected icon
    _animationController.forward().then((_) => _animationController.reverse());
  }

  void navigationTapped(int page) {
    if (_currentIndex == page) return; // Prevent redundant navigation
    pageController.jumpToPage(page);
    // Optionally, use animateToPage for smooth scrolling:
    // pageController.animateToPage(
    //   page,
    //   duration: const Duration(milliseconds: 300),
    //   curve: Curves.easeInOut,
    // );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: AnimatedOpacity(
        opacity: _currentIndex == 2 ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 300),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Colors.black,
          unselectedItemColor: Colors.grey,
          currentIndex: _currentIndex,
          onTap: navigationTapped,
          elevation: 10,
          backgroundColor: Colors.white,
          showSelectedLabels: false,
          showUnselectedLabels: false,
          items: [
            BottomNavigationBarItem(
              icon: _buildAnimatedIcon(Icons.home, 0),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: _buildAnimatedIcon(Icons.search, 1),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: _buildAnimatedIcon(Icons.camera, 2),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: _buildAnimatedReelsIcon(3),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: _buildAnimatedProfileIcon(4),
              label: '',
            ),
          ],
        ),
      ),
      body: PageView(
        controller: pageController,
        onPageChanged: onPageChanged,
        physics: const BouncingScrollPhysics(), // Smooth scrolling effect
        children: [
          const HomeScreen(),
          const ExploreScreen(),
          AddScreen(onBackToHome: () => navigationTapped(0)),
          const ReelsScreen(),
          const ProfileScreen(),
        ],
      ),
    );
  }

  Widget _buildAnimatedIcon(IconData icon, int index) {
    return AnimatedBuilder(
      animation: _iconScales[index],
      builder:
          (context, child) => Transform.scale(
            scale: _currentIndex == index ? _iconScales[index].value : 1.0,
            child: Icon(
              icon,
              size: 24.sp,
              color: _currentIndex == index ? Colors.black : Colors.grey,
            ),
          ),
    );
  }

  Widget _buildAnimatedReelsIcon(int index) {
    return AnimatedBuilder(
      animation: _iconScales[index],
      builder:
          (context, child) => Transform.scale(
            scale: _currentIndex == index ? _iconScales[index].value : 1.0,
            child: Image.asset(
              'images/instagram-reels-icon.png',
              height: 20.h,
              color: _currentIndex == index ? Colors.black : Colors.grey,
            ),
          ),
    );
  }

  Widget _buildAnimatedProfileIcon(int index) {
    return AnimatedBuilder(
      animation: _iconScales[index],
      builder:
          (context, child) => Transform.scale(
            scale: _currentIndex == index ? _iconScales[index].value : 1.0,
            child: CircleAvatar(
              radius: 12.sp,
              backgroundImage:
                  imageUrl.isNotEmpty
                      ? NetworkImage(imageUrl)
                      : const AssetImage('images/person.png') as ImageProvider,
              backgroundColor: Colors.grey[300],
              child:
                  _currentIndex == index
                      ? Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black, width: 1.5),
                        ),
                      )
                      : null,
            ),
          ),
    );
  }
}
