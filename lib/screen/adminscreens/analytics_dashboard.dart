import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AnalyticsPage extends StatelessWidget {
  final Map<String, dynamic> analytics;
  final Function onRefresh;

  const AnalyticsPage({
    Key? key,
    required this.analytics,
    required this.onRefresh,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        await onRefresh();
      },
      child: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dashboard Analytics',
              style: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 24.h),
            _buildSummarySection(context),
            SizedBox(height: 24.h),
            _buildUsersSection(context),
            SizedBox(height: 24.h),
            _buildContentSection(context),
          ],
        ),
      ),
    );
  }

  Widget _buildSummarySection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Summary',
          style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 16.h),
        GridView.count(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 10.w,
          crossAxisSpacing: 10.w,
          childAspectRatio: 1.5,
          children: [
            _buildStatCard(
              context,
              'Total Users',
              analytics['totalUsers'] ?? 0,
              Colors.blue,
              Icons.people,
            ),
            _buildStatCard(
              context,
              'Total Posts',
              analytics['totalPosts'] ?? 0,
              Colors.green,
              Icons.photo_library,
            ),
            _buildStatCard(
              context,
              'Total Reels',
              analytics['totalReels'] ?? 0,
              Colors.purple,
              Icons.video_library,
            ),
            _buildStatCard(
              context,
              'Recent Content',
              (analytics['recentPosts'] ?? 0) + (analytics['recentReels'] ?? 0),
              Colors.orange,
              Icons.new_releases,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUsersSection(BuildContext context) {
    final activeUsers = analytics['activeUsers'] ?? 0;
    final inactiveUsers = analytics['inactiveUsers'] ?? 0;
    final totalUsers = activeUsers + inactiveUsers;
    final activePercentage =
        totalUsers > 0 ? (activeUsers / totalUsers) * 100 : 0.0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'User Status',
              style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16.h),
            Row(
              children: [
                _buildUserStatusIndicator('Active', activeUsers, Colors.green),
                SizedBox(width: 24.w),
                _buildUserStatusIndicator(
                  'Inactive',
                  inactiveUsers,
                  Colors.red,
                ),
              ],
            ),
            SizedBox(height: 16.h),
            LinearProgressIndicator(
              value: activePercentage / 100,
              backgroundColor: Colors.red.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
              minHeight: 8.h,
              borderRadius: BorderRadius.circular(4.r),
            ),
            SizedBox(height: 8.h),
            Text(
              '${activePercentage.toStringAsFixed(1)}% active users',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentSection(BuildContext context) {
    final recentPosts = analytics['recentPosts'] ?? 0;
    final recentReels = analytics['recentReels'] ?? 0;
    final totalPosts = analytics['totalPosts'] ?? 0;
    final totalReels = analytics['totalReels'] ?? 0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Content Activity (Last 7 Days)',
              style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16.h),
            _buildContentActivityBar(
              'Posts',
              recentPosts,
              totalPosts,
              Colors.blue,
              Icons.photo,
            ),
            SizedBox(height: 16.h),
            _buildContentActivityBar(
              'Reels',
              recentReels,
              totalReels,
              Colors.purple,
              Icons.video_file,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    int value,
    Color color,
    IconData icon,
  ) {
    return Container(
      width: 300.w,
      height: 450.h,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5.r)),
        child: Padding(
          padding: EdgeInsets.all(10.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 28.w),
              SizedBox(height: 5.h),
              Text(
                value.toString(),
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                title,
                style: TextStyle(fontSize: 11.sp, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserStatusIndicator(String label, int count, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12.w,
                height: 12.h,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              SizedBox(width: 8.w),
              Text(
                label,
                style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          Text(
            count.toString(),
            style: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildContentActivityBar(
    String label,
    int recent,
    int total,
    Color color,
    IconData icon,
  ) {
    final percentage = total > 0 ? (recent / total) * 100 : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20.w),
            SizedBox(width: 8.w),
            Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
            Spacer(),
            Text(
              '$recent of $total',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
        SizedBox(height: 8.h),
        LinearProgressIndicator(
          value: percentage / 100,
          backgroundColor: color.withOpacity(0.2),
          valueColor: AlwaysStoppedAnimation<Color>(color),
          minHeight: 8.h,
          borderRadius: BorderRadius.circular(4.r),
        ),
        SizedBox(height: 4.h),
        Text(
          '${percentage.toStringAsFixed(1)}% in the last 7 days',
          style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
        ),
      ],
    );
  }
}
