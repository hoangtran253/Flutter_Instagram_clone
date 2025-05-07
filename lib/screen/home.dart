import 'package:flutter/material.dart';
import 'package:flutter_instagram_clone/widgets/post_widget.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
        elevation: 0,
        title: SizedBox(
          width: 105.w,
          child: Image.asset(
            'images/instagram.png',
            width: 50.w,
            height: 50.h,
            fit: BoxFit.contain,
          ),
        ),
        leading: Padding(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 15.h),
          child: Image.asset(
            'images/camera.png',
            width: 25.w,
            height: 25.h,
            fit: BoxFit.contain,
          ),
        ),
        actions: [
          Icon(Icons.favorite_border_outlined, color: Colors.black, size: 25),
          SizedBox(width: 8),
          Image.asset(
            'images/send.png',
            width: 30.w,
            height: 30.h,
            fit: BoxFit.contain,
          ),
        ],
        actionsPadding: EdgeInsets.symmetric(horizontal: 10.w),
        backgroundColor: const Color(0xffFAFAFA),
      ),
      body: CustomScrollView(
        slivers: [
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              return PostWidget();
            }, childCount: 5),
          ),
        ],
      ),
    );
  }
}
