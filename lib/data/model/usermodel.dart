class Usermodel {
  String email;
  String username;
  String bio;
  List following;
  List followers;
  String imageUrl; // ảnh bài viết
  String avatarUrl; // ảnh đại diện

  Usermodel({
    required this.bio,
    required this.email,
    required this.followers,
    required this.following,
    required this.username,
    required this.imageUrl,
    required this.avatarUrl,
  });

  factory Usermodel.fromMap(Map<String, dynamic> data) {
    return Usermodel(
      bio: data['bio'] ?? '',
      email: data['email'] ?? '',
      followers: List<String>.from(data['followers'] ?? []),
      following: List<String>.from(data['following'] ?? []),
      username: data['username'] ?? '',
      avatarUrl: data['avatarUrl'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'bio': bio,
      'email': email,
      'followers': followers,
      'following': following,
      'username': username,
      'imageUrl': imageUrl,
      'avatarUrl': avatarUrl,
    };
  }
}
