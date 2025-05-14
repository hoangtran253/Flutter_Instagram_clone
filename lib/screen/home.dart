import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_instagram_clone/screen/add_post_screen.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_instagram_clone/widgets/post_widget.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> posts = [];

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
              final Timestamp? timestamp = post['postTime'];
              String formattedTime = '';

              if (timestamp != null) {
                formattedTime = DateFormat(
                  'dd/MM/yyyy HH:mm',
                ).format(timestamp.toDate());
              }

              return PostWidget(
                username: post['username'] ?? '',
                caption: post['caption'] ?? '',
                imageUrl: post['imageUrl'] ?? '',
                avatarUrl: post['avatarUrl'] ?? '',
                postTime: formattedTime,
              );
            },
          );
        },
      ),
    );
  }
}
