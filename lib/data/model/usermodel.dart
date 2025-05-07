class Usermodel {
  String email;
  String username;
  String bio;
  List following;
  List followers;
  String imageUrl;

  // Constructor
  Usermodel({
    required this.bio,
    required this.email,
    required this.followers,
    required this.following,
    required this.username,
    required this.imageUrl, // Thêm imageUrl
  });

  // Chuyển đổi từ Firestore (Map) về đối tượng Usermodel
  factory Usermodel.fromMap(Map<String, dynamic> data) {
    return Usermodel(
      bio: data['bio'] ?? '',
      email: data['email'] ?? '',
      followers: List<String>.from(data['followers'] ?? []),
      following: List<String>.from(data['following'] ?? []),
      username: data['username'] ?? '',
      imageUrl: data['imageUrl'] ?? '', // lấy imageUrl từ Firestore
    );
  }

  // Chuyển đổi từ Usermodel về Map (để lưu vào Firestore)
  Map<String, dynamic> toMap() {
    return {
      'bio': bio,
      'email': email,
      'followers': followers,
      'following': following,
      'username': username,
      'imageUrl': imageUrl, // Lưu imageUrl vào Firestore
    };
  }
}
