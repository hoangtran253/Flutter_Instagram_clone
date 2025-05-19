import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class PostWidget extends StatefulWidget {
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
  State<PostWidget> createState() => _PostWidgetState();
}

class _PostWidgetState extends State<PostWidget>
    with SingleTickerProviderStateMixin {
  bool _isLiked = false;
  bool _showHeart = false;
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _animation = Tween<double>(
      begin: 1.5,
      end: 0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _showHeart = false;
        });
        _controller.reset();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDoubleTap() {
    setState(() {
      _isLiked = true;
      _showHeart = true;
    });
    _controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            child: Row(
              children: [
                Container(
                  width: 40.w,
                  height: 40.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade300, width: 1),
                  ),
                  child: ClipOval(
                    child:
                        widget.avatarUrl.isNotEmpty
                            ? CachedNetworkImage(
                              imageUrl: widget.avatarUrl,
                              fit: BoxFit.cover,
                              placeholder:
                                  (context, url) => Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1.5,
                                    ),
                                  ),
                              errorWidget:
                                  (context, url, error) => Icon(Icons.error),
                            )
                            : Icon(Icons.account_circle, size: 35.w),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    widget.username,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(Icons.more_horiz),
              ],
            ),
          ),

          // Post Image with double tap
          Stack(
            alignment: Alignment.center,
            children: [
              GestureDetector(
                onDoubleTap: _onDoubleTap,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12.r),
                  child: CachedNetworkImage(
                    imageUrl: widget.imageUrl.trim(),
                    width: double.infinity,
                    height: 375.h,
                    fit: BoxFit.cover,
                    placeholder:
                        (context, url) => Container(
                          color: Colors.grey.shade200,
                          child: Center(child: CircularProgressIndicator()),
                        ),
                    errorWidget: (context, url, error) => Icon(Icons.error),
                  ),
                ),
              ),

              // Heart animation
              if (_showHeart)
                ScaleTransition(
                  scale: _animation,
                  child: Icon(
                    Icons.favorite,
                    color: Colors.red.withOpacity(0.8),
                    size: 120.sp,
                  ),
                ),
            ],
          ),

          // Action Buttons
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            child: Row(
              children: [
                Icon(
                  _isLiked ? Icons.favorite : Icons.favorite_border,
                  color: _isLiked ? Colors.red : Colors.black,
                  size: 26.sp,
                ),
                SizedBox(width: 15.w),
                Image.asset('images/comment.webp', height: 26.h),
                SizedBox(width: 15.w),
                Image.asset('images/send.jpg', height: 24.h),
                Spacer(),
                Image.asset('images/save.png', height: 24.h),
              ],
            ),
          ),

          // Caption
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w),
            child: RichText(
              text: TextSpan(
                style: TextStyle(color: Colors.black, fontSize: 13.sp),
                children: [
                  TextSpan(
                    text: widget.username + " ",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: widget.caption),
                ],
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Time
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            child: Text(
              widget.postTime,
              style: TextStyle(fontSize: 11.sp, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}
