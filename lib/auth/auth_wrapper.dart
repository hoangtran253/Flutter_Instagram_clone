import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_instagram_clone/auth/admin_auth.dart';
import 'package:flutter_instagram_clone/auth/auth_screen.dart';
import 'package:flutter_instagram_clone/screen/adminscreens/admin_dashboard.dart';
import 'package:flutter_instagram_clone/screen/login_screen.dart';
import 'package:flutter_instagram_clone/widgets/navigation.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Chưa có dữ liệu (đang loading)
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;

        if (user == null) {
          return const AuthScreen(); // hoặc màn hình welcome
        }

        // Kiểm tra quyền admin
        return FutureBuilder<bool>(
          future: AdminAuth().isUserAdmin(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (!snapshot.hasData) {
              return const Scaffold(
                body: Center(child: Text('Error loading admin status')),
              );
            }

            final isAdmin = snapshot.data ?? false;
            return isAdmin ? AdminDashboard() : const Navigations_Screen();
          },
        );
      },
    );
  }
}
