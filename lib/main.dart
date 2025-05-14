import 'package:flutter/material.dart';
import 'package:flutter_instagram_clone/auth/auth_wrapper.dart';
import 'package:flutter_instagram_clone/auth/mainpage.dart';
import 'package:flutter_instagram_clone/screen/adminscreens/admin_dashboard.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_instagram_clone/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ScreenUtilInit(designSize: Size(375, 812), child: AuthWrapper()),
    );
  }
}
