import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_instagram_clone/widgets/post_widget.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(55.h),
        child: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          centerTitle: true,
          leading: IconButton(
            icon: Image.asset('images/camera.png', width: 25.w),
            onPressed: () {},
          ),
          title: Image.asset('images/instagram.png', height: 30.h),
          actions: [
            IconButton(
              icon: Icon(Icons.favorite_border, color: Colors.black),
              onPressed: () {},
            ),
            IconButton(
              icon: Image.asset('images/send.png', width: 24.w),
              onPressed: () {},
            ),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('posts')
                .orderBy('postTime', descending: true)
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                "Chưa có bài viết nào",
                style: TextStyle(fontSize: 16.sp, color: Colors.grey),
              ),
            );
          }

          final posts = snapshot.data!.docs;

          return ListView.separated(
            padding: EdgeInsets.symmetric(vertical: 10.h),
            itemCount: posts.length,
            separatorBuilder: (_, __) => SizedBox(height: 12.h),
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
                uid: post['uid'] ?? '',
                postId: post['postId'] ?? '',
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
