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

      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists && mounted) {
        final data = doc.data()!;
        setState(() {
          username = data['username'] ?? '';
          email = data['email'] ?? '';
          bio = data['bio'] ?? '';
          imageUrl = widget.imageUrlFromRegister ?? data['imageUrl'] ?? '';
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
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child:
            isLoading
                ? const Center(child: CircularProgressIndicator())
                : Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 20.w,
                      vertical: 30.h,
                    ),
                    child: Column(
                      children: [
                        // Avatar section
                        CircleAvatar(
                          radius: 60.r,
                          backgroundColor: Colors.grey.shade300,
                          backgroundImage:
                              imageUrl.isNotEmpty
                                  ? NetworkImage(imageUrl)
                                  : const AssetImage('images/person.png')
                                      as ImageProvider,
                        ),
                        SizedBox(height: 20.h),
                        // Username
                        Text(
                          username,
                          style: TextStyle(
                            fontSize: 24.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        SizedBox(height: 10.h),
                        // Email
                        Text(
                          email,
                          style: TextStyle(fontSize: 16.sp, color: Colors.grey),
                        ),
                        SizedBox(height: 15.h),
                        // Bio
                        Text(
                          bio,
                          style: TextStyle(
                            fontSize: 16.sp,
                            color: Colors.black54,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 30.h),
                        // Edit Profile button
                        ElevatedButton(
                          onPressed: () {
                            // TODO: Handle profile editing logic
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            padding: EdgeInsets.symmetric(
                              horizontal: 30.w,
                              vertical: 12.h,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30.r),
                            ),
                          ),
                          child: Text(
                            'Edit Profile',
                            style: TextStyle(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        SizedBox(height: 20.h),
                        // Logout button
                        OutlinedButton(
                          onPressed: () async {
                            // TODO: Handle logout functionality
                            await _auth.signOut();
                            // Navigate to login screen after logout
                          },
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.blueAccent),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30.r),
                            ),
                          ),
                          child: Text(
                            'Logout',
                            style: TextStyle(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.blueAccent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
      ),
    );
  }
}
