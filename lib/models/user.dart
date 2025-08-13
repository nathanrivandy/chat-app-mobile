class User {
  final int id;
  final String username;
  final String fullName;
  final String? phone;
  final String? email;
  final String? profilePhotoUrl;
  final int creditScore;
  final String? statusMessage;

  User({
    required this.id,
    required this.username,
    required this.fullName,
    this.phone,
    this.email,
    this.profilePhotoUrl,
    required this.creditScore,
    this.statusMessage,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      username: json['username'],
      fullName: json['full_name'],
      phone: json['phone'],
      email: json['email'],
      profilePhotoUrl: json['profile_photo_url'],
      creditScore: json['credit_score'],
      statusMessage: json['status_message'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'full_name': fullName,
      'phone': phone,
      'email': email,
      'profile_photo_url': profilePhotoUrl,
      'credit_score': creditScore,
      'status_message': statusMessage,
    };
  }
}