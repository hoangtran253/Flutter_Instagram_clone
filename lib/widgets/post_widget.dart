import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class PostWidget extends StatelessWidget {
  final String username;
  final String location;
  final String caption;
  final String imageUrl;
  final String postTime;

  const PostWidget({
    super.key,
    required this.username,
    required this.location,
    required this.caption,
    required this.imageUrl,
    required this.postTime,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 375.w,
          height: 54.h,
          color: Colors.white,
          child: Center(
            child: ListTile(
              leading: ClipOval(
                child: SizedBox(
                  width: 35.w,
                  height: 35.h,
                  child: Image.asset('images/person.png'), // avatar tạm
                ),
              ),
              title: Text(username, style: TextStyle(fontSize: 13.sp)),
              subtitle: Text(location, style: TextStyle(fontSize: 11.sp)),
              trailing: Icon(Icons.more_horiz),
            ),
          ),
        ),
        SizedBox(height: 20),
        Container(
          width: 375.w,
          height: 375.h,
          child: Image.network(
            imageUrl.trim(),
            fit: BoxFit.cover,
          ), // fix trim()
        ),
        Container(
          width: 375.w,
          color: Colors.white,
          child: Column(
            children: [
              SizedBox(width: 10, height: 15),
              Row(
                children: [
                  SizedBox(width: 14.w),
                  Icon(Icons.favorite_outlined, size: 25.w),
                  SizedBox(width: 17.w),
                  Image.asset('images/comment.webp', height: 28.h),
                  SizedBox(width: 14.w),
                  Image.asset('images/send.jpg', height: 28.h),
                  const Spacer(),
                  Padding(
                    padding: EdgeInsets.only(right: 15.w),
                    child: Image.asset('images/save.png', height: 28.h),
                  ),
                ],
              ),
              SizedBox(height: 15),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    SizedBox(width: 10),
                    Text(
                      username,
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 5),
                    Text(caption, style: TextStyle(fontSize: 13.sp)),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.only(left: 15.w, top: 5.h, bottom: 8.h),
                child: Text(
                  postTime,
                  style: TextStyle(fontSize: 11.sp, color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
