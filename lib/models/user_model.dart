class UserModel {
  final String id;
  final String username;
  final dynamic faceEncoding;

  UserModel({required this.id, required this.username, required this.faceEncoding});

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      username: json['username'],
      faceEncoding: json['face_encoding'],
    );
  }
}