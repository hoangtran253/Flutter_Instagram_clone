import 'package:flutter/material.dart';
import 'package:flutter_instagram_clone/data/model/adminmodel.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

class UsersManagementPage extends StatefulWidget {
  final AdminService adminService;

  const UsersManagementPage({Key? key, required this.adminService})
    : super(key: key);

  @override
  _UsersManagementPageState createState() => _UsersManagementPageState();
}

class _UsersManagementPageState extends State<UsersManagementPage> {
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  bool _isLoading = true;
  String _searchQuery = '';
  bool _showOnlyActive = false;
  bool _showOnlyInactive = false;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final users = await widget.adminService.getAllUsers();
      setState(() {
        _users = users;
        _filterUsers();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading users: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load users')));
    }
  }

  void _filterUsers() {
    setState(() {
      _filteredUsers =
          _users.where((user) {
            // Filter by search query
            final matchesSearch =
                user['username'].toString().toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ) ||
                user['email'].toString().toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ) ||
                user['uid'].toString().toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                );

            // Filter by status
            final matchesStatus =
                (_showOnlyActive && user['isActive'] == true) ||
                (_showOnlyInactive && user['isActive'] == false) ||
                (!_showOnlyActive && !_showOnlyInactive);

            return matchesSearch && matchesStatus;
          }).toList();
    });
  }

  Future<void> _deleteUser(String uid, String username) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Delete User'),
            content: Text(
              'Are you sure you want to delete $username? This will also delete all associated posts and reels.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('CANCEL'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text('DELETE'),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      setState(() {
        _isLoading = true;
      });
      try {
        await widget.adminService.deleteUser(uid);
        await _loadUsers();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('User deleted successfully')));
      } catch (e) {
        print('Error deleting user: $e');
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to delete user')));
      }
    }
  }

  Future<void> _toggleUserStatus(
    String uid,
    bool currentStatus,
    String username,
  ) async {
    final newStatus = !currentStatus;
    final statusText = newStatus ? 'activate' : 'deactivate';

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('${newStatus ? 'Activate' : 'Deactivate'} User'),
            content: Text('Are you sure you want to $statusText $username?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('CANCEL'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(newStatus ? 'ACTIVATE' : 'DEACTIVATE'),
                style: TextButton.styleFrom(
                  foregroundColor: newStatus ? Colors.green : Colors.orange,
                ),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      setState(() {
        _isLoading = true;
      });
      try {
        await widget.adminService.updateUserInfo(uid: uid, isActive: newStatus);
        await _loadUsers();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'User ${newStatus ? 'activated' : 'deactivated'} successfully',
            ),
          ),
        );
      } catch (e) {
        print('Error updating user status: $e');
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update user status')));
      }
    }
  }

  void _showEditUserDialog(Map<String, dynamic> user) {
    final formKey = GlobalKey<FormState>();
    String username = user['username'];
    String bio = user['bio'] ?? '';

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Edit User'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    initialValue: username,
                    decoration: InputDecoration(labelText: 'Username'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Username cannot be empty';
                      }
                      return null;
                    },
                    onChanged: (value) {
                      username = value;
                    },
                  ),
                  TextFormField(
                    initialValue: bio,
                    decoration: InputDecoration(labelText: 'Bio'),
                    maxLines: 3,
                    onChanged: (value) {
                      bio = value;
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('CANCEL'),
              ),
              TextButton(
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    Navigator.of(context).pop();
                    setState(() {
                      _isLoading = true;
                    });
                    try {
                      await widget.adminService.updateUserInfo(
                        uid: user['uid'],
                        username: username,
                        bio: bio,
                      );
                      await _loadUsers();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('User updated successfully')),
                      );
                    } catch (e) {
                      print('Error updating user: $e');
                      setState(() {
                        _isLoading = false;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to update user')),
                      );
                    }
                  }
                },
                child: Text('SAVE'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'User Management',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 16),
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by username, email or UID',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                      _filterUsers();
                    });
                  },
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    FilterChip(
                      label: Text('Active Users'),
                      selected: _showOnlyActive,
                      onSelected: (selected) {
                        setState(() {
                          _showOnlyActive = selected;
                          if (selected) {
                            _showOnlyInactive = false;
                          }
                          _filterUsers();
                        });
                      },
                      avatar: Icon(
                        Icons.check_circle,
                        color: _showOnlyActive ? Colors.white : Colors.green,
                        size: 18,
                      ),
                    ),
                    SizedBox(width: 8),
                    FilterChip(
                      label: Text('Inactive Users'),
                      selected: _showOnlyInactive,
                      onSelected: (selected) {
                        setState(() {
                          _showOnlyInactive = selected;
                          if (selected) {
                            _showOnlyActive = false;
                          }
                          _filterUsers();
                        });
                      },
                      avatar: Icon(
                        Icons.cancel,
                        color: _showOnlyInactive ? Colors.white : Colors.red,
                        size: 18,
                      ),
                    ),
                    Spacer(),
                    Text(
                      '${_filteredUsers.length} users',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child:
                _isLoading
                    ? Center(child: CircularProgressIndicator())
                    : _filteredUsers.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.person_off,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No users found',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                    : RefreshIndicator(
                      onRefresh: _loadUsers,
                      child: ListView.builder(
                        itemCount: _filteredUsers.length,
                        itemBuilder: (context, index) {
                          final user = _filteredUsers[index];
                          return Card(
                            margin: EdgeInsets.symmetric(
                              horizontal: 16.h,
                              vertical: 4.w,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundImage:
                                    user['avatarUrl'] != null
                                        ? NetworkImage(user['avatarUrl'])
                                        : null,
                                child:
                                    user['avatarUrl'] == null
                                        ? Text(
                                          user['username'][0].toUpperCase(),
                                        )
                                        : null,
                              ),
                              title: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    Text(user['username']),
                                    SizedBox(width: 8),
                                    Icon(
                                      user['isActive'] == true
                                          ? Icons.check_circle
                                          : Icons.cancel,
                                      color:
                                          user['isActive'] == true
                                              ? Colors.green
                                              : Colors.red,
                                      size: 12,
                                    ),
                                  ],
                                ),
                              ),
                              subtitle: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Text(user['email']),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.edit),
                                    onPressed: () => _showEditUserDialog(user),
                                    tooltip: 'Edit User',
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      user['isActive'] == true
                                          ? Icons.block
                                          : Icons.check_circle_outline,
                                      color:
                                          user['isActive'] == true
                                              ? Colors.orange
                                              : Colors.green,
                                    ),
                                    onPressed:
                                        () => _toggleUserStatus(
                                          user['uid'],
                                          user['isActive'] == true,
                                          user['username'],
                                        ),
                                    tooltip:
                                        user['isActive'] == true
                                            ? 'Deactivate User'
                                            : 'Activate User',
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete, color: Colors.red),
                                    onPressed:
                                        () => _deleteUser(
                                          user['uid'],
                                          user['username'],
                                        ),
                                    tooltip: 'Delete User',
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadUsers,
        child: Icon(Icons.refresh),
        tooltip: 'Refresh',
      ),
    );
  }
}
