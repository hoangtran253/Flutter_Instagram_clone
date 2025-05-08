import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ProfileScreen extends StatefulWidget {
  final String? imageUrlFromRegister;

  const ProfileScreen({super.key, this.imageUrlFromRegister});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String username = '';
  String email = '';
  String bio = '';
  String imageUrl = '';
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchUserData();
  }

  Future<void> fetchUserData() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;

      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (userDoc.exists && mounted) {
        final userData = userDoc.data()!;
        setState(() {
          username = userData['username'] ?? '';
          email = userData['email'] ?? '';
          bio = userData['bio'] ?? '';
          imageUrl = widget.imageUrlFromRegister ?? userData['imageUrl'] ?? '';
          isLoading = false;
        });
      }
    } catch (e) {
      print('Lỗi khi lấy thông tin người dùng: $e');
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser?.uid ?? '';
    print('Current user uid: $uid');

    return Scaffold(
      backgroundColor: Colors.white,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: DefaultTabController(
                length: 3,
                child: Column(
                  children: [
                    // Header: avatar, username, bio
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Avatar
                          Column(
                            children: [
                              CircleAvatar(
                                radius: 40.r,
                                backgroundColor: Colors.grey.shade300,
                                backgroundImage: imageUrl.isNotEmpty
                                    ? NetworkImage(imageUrl)
                                    : const AssetImage('images/person.png')
                                        as ImageProvider,
                              ),
                              SizedBox(height: 8.h),
                              // Username
                              Text(
                                username,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16.sp,
                                ),
                              ),
                              SizedBox(height: 4.h),
                              // Bio
                              SizedBox(
                                width: 100.w,
                                child: Text(
                                  bio,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13.sp,
                                    color: Colors.black54,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(width: 20.w),
                          // Stats
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildStatColumn("Posts", 0),
                                _buildStatColumn("Followers", 0),
                                _buildStatColumn("Following", 0),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Edit Profile button
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                // TODO: edit profile
                              },
                              child: Text('Edit Your Profile'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 8.h),

                    // TabBar
                    TabBar(
                      tabs: [
                        Tab(icon: Icon(Icons.grid_on, color: Colors.grey)),
                        Tab(icon: Icon(Icons.video_collection_outlined, color: Colors.grey)),
                        Tab(icon: Icon(Icons.person, color: Colors.grey)),
                      ],
                    ),

                    // TabBar View
                    Expanded(
                      child: TabBarView(
                        children: [
                          // StreamBuilder lấy bài đăng không lọc uid để test
                          StreamBuilder<QuerySnapshot>(
                            stream: _firestore
                                .collection('posts')
                                .orderBy('postTime', descending: true)
                                .snapshots(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const Center(child: CircularProgressIndicator());
                              }
                              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                                return Center(child: Text('Chưa có bài đăng nào'));
                              }

                              final posts = snapshot.data!.docs;
                              print('Số bài đăng lấy được: ${posts.length}');

                              return GridView.count(
                                crossAxisCount: 3,
                                mainAxisSpacing: 2.w,
                                crossAxisSpacing: 2.w,
                                children: posts.map((doc) {
                                  final post = doc.data() as Map<String, dynamic>;
                                  print('Post imageUrl: ${post['imageUrl']}');
                                  return Image.network(post['imageUrl'] ?? '', fit: BoxFit.cover);
                                }).toList(),
                              );
                            },
                          ),
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

  Widget _buildStatColumn(String label, int count) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
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
