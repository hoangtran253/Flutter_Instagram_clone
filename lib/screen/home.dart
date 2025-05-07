import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_instagram_clone/screen/add_post_screen.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_instagram_clone/widgets/post_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> posts = [
    {
      'username': 'johndoe',
      'location': 'New York',
      'caption': 'Chilling with coffee ☕',
      'imageUrl':
          'https://res.cloudinary.com/dv8bbvd5q/image/upload/v1746603352/yhv4dqsl5rezbdvs86mm.png',
      'postTime': '2 hours ago',
    },
    {
      'username': 'janedoe',
      'location': 'Tokyo',
      'caption': 'Sunset vibes 🌇',
      'imageUrl':
          'https://res.cloudinary.com/dv8bbvd5q/image/upload/v1746603352/yhv4dqsl5rezbdvs86mm.png',
      'postTime': '5 hours ago',
    },
    // thêm bài viết khác nếu muốn
  ];

  // Hàm này sẽ được gọi khi quay lại từ AddPostScreen với dữ liệu mới
  void _addNewPost(Map<String, dynamic> newPost) {
    setState(() {
      posts.insert(0, newPost); // Thêm bài viết mới vào đầu danh sách
    });
  }

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
          child: Image.asset('images/instagram.png', fit: BoxFit.contain),
        ),
        leading: Padding(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 15.h),
          child: Image.asset('images/camera.png', fit: BoxFit.contain),
        ),
        actions: [
          Icon(Icons.favorite_border_outlined, color: Colors.black, size: 25),
          SizedBox(width: 8),
          Image.asset('images/send.png', width: 30.w, fit: BoxFit.contain),
        ],
        actionsPadding: EdgeInsets.symmetric(horizontal: 10.w),
        backgroundColor: const Color(0xffFAFAFA),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('posts')
                .orderBy('postTime', descending: true)
                .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final posts = snapshot.data!.docs;

          return ListView.builder(
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index].data() as Map<String, dynamic>;
              return PostWidget(
                username: post['username'] ?? '',
                location: post['location'] ?? '',
                caption: post['caption'] ?? '',
                imageUrl: post['imageUrl'] ?? '',
                postTime: post['postTime'] ?? '',
              );
            },
          );
        },
      ),
    );
  }
}
