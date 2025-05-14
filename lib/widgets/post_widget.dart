import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class PostWidget extends StatelessWidget {
  final String username;
  final String caption;
  final String imageUrl;
  final String postTime;
  final String avatarUrl;

  const PostWidget({
    super.key,
    required this.username,
    required this.caption,
    required this.imageUrl,
    required this.postTime,
    required this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 375.w,
          height: 54.h,
          color: Colors.white,
          child: ListTile(
            leading: ClipOval(
              child: SizedBox(
                width: 35.w,
                height: 35.h,
                child:
                    avatarUrl.isNotEmpty
                        ? CachedNetworkImage(
                          imageUrl: avatarUrl,
                          fit: BoxFit.cover,
                          placeholder:
                              (context, url) => CircularProgressIndicator(),
                          errorWidget:
                              (context, url, error) => Icon(Icons.error),
                        )
                        : Icon(
                          Icons.account_circle,
                          size: 35.w,
                        ), // Hình ảnh mặc định nếu avatarUrl không có
              ),
            ),
            title: Text(username, style: TextStyle(fontSize: 13.sp)),
            trailing: Icon(Icons.more_horiz),
          ),
        ),
        SizedBox(height: 8.h),
        Container(
          width: 375.w,
          height: 375.h,
          child: CachedNetworkImage(
            imageUrl: imageUrl.trim(),
            fit: BoxFit.cover,
            placeholder: (context, url) => CircularProgressIndicator(),
            errorWidget: (context, url, error) => Icon(Icons.error),
          ),
        ),
        Container(
          width: 375.w,
          color: Colors.white,
          child: Column(
            children: [
              SizedBox(height: 15),
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
              SizedBox(height: 8.h),
              Padding(
                padding: const EdgeInsets.all(5),
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
                padding: EdgeInsets.only(top: 5.h, bottom: 8.h),
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
