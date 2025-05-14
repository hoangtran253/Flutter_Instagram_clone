import 'package:flutter/material.dart';
import 'package:flutter_instagram_clone/data/model/adminmodel.dart';

class UserDetailScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const UserDetailScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  final AdminService _adminService = AdminService();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _usernameController;
  late TextEditingController _bioController;
  late bool _isActive;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: widget.user['username']);
    _bioController = TextEditingController(text: widget.user['bio']);
    _isActive = widget.user['isActive'] ?? true;
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _adminService.updateUserInfo(
        uid: widget.user['uid'],
        username: _usernameController.text,
        bio: _bioController.text,
        isActive: _isActive,
      );

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('User updated successfully')));

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update user')));
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
        title: Text('User Details'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveChanges,
            child:
                _isLoading
                    ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                    : Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User avatar and basic info
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundImage:
                          widget.user['imageUrl'] != null &&
                                  widget.user['imageUrl'].isNotEmpty
                              ? NetworkImage(widget.user['imageUrl'])
                              : null,
                      child:
                          widget.user['imageUrl'] == null ||
                                  widget.user['imageUrl'].isEmpty
                              ? Icon(Icons.person, size: 50)
                              : null,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'User ID: ${widget.user['uid']}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Email: ${widget.user['email']}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 32),

              Text(
                'User Profile',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),

              // Username
              TextFormField(
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: 'Username',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Username cannot be empty';
                  }
                  return null;
                },
              ),

              SizedBox(height: 16),

              // Bio
              TextFormField(
                controller: _bioController,
                decoration: InputDecoration(
                  labelText: 'Bio',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                maxLines: 3,
              ),

              SizedBox(height: 16),

              // Active status switch
              Row(
                children: [
                  Text('Account Status', style: TextStyle(fontSize: 16)),
                  Spacer(),
                  Text(_isActive ? 'Active' : 'Inactive'),
                  Switch(
                    value: _isActive,
                    onChanged: (value) {
                      setState(() {
                        _isActive = value;
                      });
                    },
                  ),
                ],
              ),

              SizedBox(height: 24),

              // Delete Account Button
              Center(
                child: ElevatedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder:
                          (context) => AlertDialog(
                            title: Text('Delete User'),
                            content: Text(
                              'Are you sure you want to delete this user? This action cannot be undone.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () async {
                                  Navigator.pop(context);
                                  try {
                                    await _adminService.deleteUser(
                                      widget.user['uid'],
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'User deleted successfully',
                                        ),
                                      ),
                                    );
                                    Navigator.pop(
                                      context,
                                    ); // Go back to user list
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Failed to delete user'),
                                      ),
                                    );
                                  }
                                },
                                child: Text(
                                  'Delete',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                    );
                  },
                  icon: Icon(Icons.delete_forever, color: Colors.white),
                  label: Text('Delete User Account'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
