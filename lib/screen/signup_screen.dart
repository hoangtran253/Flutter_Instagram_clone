import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_instagram_clone/data/cloudinary_service.dart';
import 'package:flutter_instagram_clone/data/firebase_service/firebase_auth.dart';
import 'package:flutter_instagram_clone/screen/profile_screen.dart';
import 'package:flutter_instagram_clone/util/dialog.dart';
import 'package:flutter_instagram_clone/util/exception.dart';
import 'package:flutter_instagram_clone/util/imagepicker.dart';
import 'package:flutter_instagram_clone/widgets/navigation.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class SignupScreen extends StatefulWidget {
  final VoidCallback show;
  SignupScreen(this.show, {super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final email = TextEditingController();
  FocusNode email_F = FocusNode();
  final password = TextEditingController();
  FocusNode password_F = FocusNode();
  final passwordConfirme = TextEditingController();
  FocusNode passwordConfirme_F = FocusNode();
  final username = TextEditingController();
  FocusNode username_F = FocusNode();
  final bio = TextEditingController();
  FocusNode bio_F = FocusNode();
  Uint8List? _imageBytes;

  @override
  void dispose() {
    super.dispose();
    email.dispose();
    password.dispose();
    passwordConfirme.dispose();
    username.dispose();
    bio.dispose();
  }

  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(width: 96.w, height: 10.h),
            Center(child: Image.asset('images/logo.jpg')),
            SizedBox(width: 96.w, height: 70.h),
            InkWell(
              onTap: () async {
                final pickedBytes = await ImagePickerr().pickImageAsBytes(
                  'gallery',
                );
                if (pickedBytes != null) {
                  setState(() {
                    _imageBytes = pickedBytes;
                  });
                }
              },
              child: CircleAvatar(
                radius: 36.r,
                backgroundColor: Colors.grey,
                child:
                    _imageBytes == null
                        ? CircleAvatar(
                          radius: 34.r,
                          backgroundImage: AssetImage('images/person.png'),
                          backgroundColor: Colors.grey.shade200,
                        )
                        : CircleAvatar(
                          radius: 34.r,
                          backgroundImage:
                              Image.memory(
                                _imageBytes!,
                                fit: BoxFit.cover,
                              ).image,
                          backgroundColor: Colors.grey.shade200,
                        ),
              ),
            ),
            SizedBox(height: 40.h),
            Textfild(email, email_F, 'Email', Icons.email),
            SizedBox(height: 15.h),
            Textfild(username, username_F, 'username', Icons.person),
            SizedBox(height: 15.h),
            Textfild(bio, bio_F, 'bio', Icons.abc),
            SizedBox(height: 15.h),
            Textfild(password, password_F, 'Password', Icons.lock),
            SizedBox(height: 15.h),
            Textfild(
              passwordConfirme,
              passwordConfirme_F,
              'Password Confirm',
              Icons.lock,
            ),
            SizedBox(height: 15.h),
            Signup(),
            SizedBox(height: 15.h),
            Have(),
          ],
        ),
      ),
    );
  }

  Widget Have() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 10.w),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            "Don you have account?  ",
            style: TextStyle(fontSize: 14.sp, color: Colors.grey),
          ),
          GestureDetector(
            onTap: widget.show,
            child: Text(
              "Login ",
              style: TextStyle(
                fontSize: 15.sp,
                color: Colors.blue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget Signup() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 10.w),
      child: InkWell(
        onTap: () async {
          try {
            String? avatarUrl;
            if (_imageBytes != null) {
              avatarUrl = await CloudinaryService.uploadImage(
                _imageBytes!,
                fileName: 'avatar.jpg',
              );
            }

            await Authentication().signup(
              email: email.text,
              password: password.text,
              passwordConfirm: passwordConfirme.text,
              username: username.text,
              bio: bio.text,
              avatarUrl: avatarUrl ?? '',
            );

            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => Navigations_Screen()),
            );
          } on exceptions catch (e) {
            dialogBuilder(context, e.message);
          }
        },

        child: Container(
          alignment: Alignment.center,
          width: double.infinity,
          height: 44.h,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(10.r),
          ),
          child: Text(
            'Sign up',
            style: TextStyle(
              fontSize: 23.sp,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Padding Textfild(
    TextEditingController controll,
    FocusNode focusNode,
    String typename,
    IconData icon,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 10.w),
      child: Container(
        height: 44.h,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(5.r),
        ),
        child: TextField(
          style: TextStyle(fontSize: 18.sp, color: Colors.black),
          controller: controll,
          focusNode: focusNode,
          decoration: InputDecoration(
            hintText: typename,
            prefixIcon: Icon(
              icon,
              color: focusNode.hasFocus ? Colors.black : Colors.grey[600],
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 15.w,
              vertical: 15.h,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(5.r),
              borderSide: BorderSide(width: 2.w, color: Colors.grey),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(5.r),
              borderSide: BorderSide(width: 2.w, color: Colors.black),
            ),
          ),
        ),
      ),
    );
  }
}
