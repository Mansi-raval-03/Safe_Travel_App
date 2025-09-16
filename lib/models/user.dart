class User {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String? profileImage;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    this.profileImage,
  });

  User copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? profileImage,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      profileImage: profileImage ?? this.profileImage,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'profileImage': profileImage,
    };
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      phone: json['phone'],
      profileImage: json['profileImage'],
    );
  }
}