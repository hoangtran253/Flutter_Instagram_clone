import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String username = '';
  String email = '';
  String bio = '';
  String avatarUrl = '';
  int postCount = 0;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchUserData();
  }

  Future<void> fetchUserData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final postSnapshot =
          await _firestore
              .collection('posts')
              .where('uid', isEqualTo: user.uid)
              .get();

      if (userDoc.exists) {
        final data = userDoc.data()!;
        setState(() {
          username = data['username'] ?? '';
          email = data['email'] ?? '';
          bio = data['bio'] ?? '';
          avatarUrl = data['avatarUrl'] ?? '';
          postCount = postSnapshot.docs.length;
          isLoading = false;
        });
      }
    } catch (e) {
      print('Lỗi khi tải dữ liệu hồ sơ: $e');
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    if (user == null) {
      return Scaffold(body: Center(child: Text("Không tìm thấy người dùng")));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () async {
              await _auth.signOut();
            },
            child: Text(
              'Logout',
              style: TextStyle(color: Colors.blue, fontSize: 16.sp),
            ),
          ),
        ],
      ),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : SafeArea(
                child: DefaultTabController(
                  length: 3,
                  child: Column(
                    children: [
                      Padding(
                        padding: EdgeInsets.all(16.w),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 40.r,
                              backgroundImage:
                                  avatarUrl.isNotEmpty
                                      ? NetworkImage(avatarUrl)
                                      : AssetImage('images/person.png')
                                          as ImageProvider,
                            ),
                            SizedBox(width: 16.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    username,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18.sp,
                                    ),
                                  ),
                                  SizedBox(height: 6.h),
                                  Text(
                                    bio,
                                    style: TextStyle(
                                      fontSize: 14.sp,
                                      color: Colors.black54,
                                    ),
                                  ),
                                  SizedBox(height: 16.h),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      _buildStatColumn("Posts", postCount),
                                      _buildStatColumn("Followers", 0),
                                      _buildStatColumn("Following", 0),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.w),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  // TODO: điều hướng tới màn hình chỉnh sửa hồ sơ
                                },
                                child: Text("Edit Profile"),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 10.h),
                      TabBar(
                        indicatorColor: Colors.black,
                        labelColor: Colors.black,
                        unselectedLabelColor: Colors.grey,
                        tabs: const [
                          Tab(icon: Icon(Icons.grid_on)),
                          Tab(icon: Icon(Icons.video_collection_outlined)),
                          Tab(icon: Icon(Icons.person_outline)),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            _buildUserPosts(user.uid),
                            Center(child: Text("Reels")),
                            Center(child: Text("Tagged")),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _buildUserPosts(String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream:
          _firestore
              .collection('posts')
              .where('uid', isEqualTo: uid)
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('Bạn chưa đăng bài nào.'));
        }

        final posts = snapshot.data!.docs;

        return GridView.builder(
          itemCount: posts.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 2.w,
            mainAxisSpacing: 2.h,
          ),
          itemBuilder: (context, index) {
            final post = posts[index].data() as Map<String, dynamic>;
            return Image.network(post['imageUrl'] ?? '', fit: BoxFit.cover);
          },
        );
      },
    );
  }

  Widget _buildStatColumn(String label, int count) {
    return Column(
      children: [
        Text(
          '$count',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp),
        ),
        Text(label, style: TextStyle(color: Colors.grey, fontSize: 14.sp)),
      ],
    );
  }
}
