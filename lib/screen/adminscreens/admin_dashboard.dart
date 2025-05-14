import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_instagram_clone/auth/auth_screen.dart';
import 'package:flutter_instagram_clone/auth/auth_wrapper.dart';
import 'package:flutter_instagram_clone/data/model/adminmodel.dart';
import 'package:flutter_instagram_clone/screen/adminscreens/post_management.dart';
import 'package:flutter_instagram_clone/screen/adminscreens/users_management.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({Key? key}) : super(key: key);

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final AdminService _adminService = AdminService();
  Map<String, dynamic> _analytics = {
    'totalUsers': 0,
    'totalPosts': 0,
    'recentPosts': 0,
  };
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final analytics = await _adminService.getAnalytics();
      if (mounted) {
        setState(() {
          _analytics = analytics;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load analytics')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Panel'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const AuthWrapper()),
                (route) => false,
              );
            },
          ),
        ],
      ),

      body:
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dashboard Overview',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 24),

                    // Analytics Cards
                    Row(
                      children: [
                        Expanded(
                          child: _buildAnalyticsCard(
                            'Total Users',
                            '${_analytics['totalUsers']}',
                            Icons.people,
                            Colors.blue,
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: _buildAnalyticsCard(
                            'Total Posts',
                            '${_analytics['totalPosts']}',
                            Icons.photo_library,
                            Colors.green,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildAnalyticsCard(
                            'Posts This Week',
                            '${_analytics['recentPosts']}',
                            Icons.trending_up,
                            Colors.orange,
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: _buildAnalyticsCard(
                            'Active Status',
                            'Online',
                            Icons.check_circle,
                            Colors.green,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 32),

                    // Management Section
                    Text(
                      'Management',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),

                    // User Management Card
                    _buildManagementCard(
                      'User Management',
                      'View, edit, and manage user accounts',
                      Icons.manage_accounts,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => UsersManagementScreen(),
                          ),
                        );
                      },
                    ),

                    SizedBox(height: 16),

                    // Post Management Card
                    _buildManagementCard(
                      'Post Management',
                      'Review, moderate, and manage user posts',
                      Icons.post_add,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PostsManagementScreen(),
                          ),
                        );
                      },
                    ),

                    SizedBox(height: 16),

                    // Refresh Button
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: _loadAnalytics,
                        icon: Icon(Icons.refresh),
                        label: Text('Refresh Data'),
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
    );
  }

  Widget _buildAnalyticsCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 32),
            SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
            SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManagementCard(
    String title,
    String description,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.blue, size: 28),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
