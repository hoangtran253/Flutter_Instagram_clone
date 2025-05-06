class Usermodel {
  String email;
  String username;
  String bio;
  List following;
  List followers;
  Usermodel(
    this.bio,
    this.email,
    this.followers,
    this.following,
    this.username,
  );
}
