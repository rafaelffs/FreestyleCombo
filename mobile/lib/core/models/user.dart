class ProfileDto {
  final String id;
  final String userName;
  final String email;
  final bool isAdmin;

  const ProfileDto({
    required this.id,
    required this.userName,
    required this.email,
    required this.isAdmin,
  });

  factory ProfileDto.fromJson(Map<String, dynamic> json) => ProfileDto(
        id: json['id'] as String,
        userName: json['userName'] as String,
        email: json['email'] as String,
        isAdmin: json['isAdmin'] as bool? ?? false,
      );
}

class PublicProfileDto {
  final String id;
  final String userName;
  final String email;

  const PublicProfileDto({
    required this.id,
    required this.userName,
    required this.email,
  });

  factory PublicProfileDto.fromJson(Map<String, dynamic> json) =>
      PublicProfileDto(
        id: json['id'] as String,
        userName: json['userName'] as String,
        email: json['email'] as String,
      );
}

class AdminUserDto {
  final String id;
  final String userName;
  final String email;
  final bool isAdmin;
  final int comboCount;

  const AdminUserDto({
    required this.id,
    required this.userName,
    required this.email,
    required this.isAdmin,
    required this.comboCount,
  });

  factory AdminUserDto.fromJson(Map<String, dynamic> json) => AdminUserDto(
        id: json['id'] as String,
        userName: json['userName'] as String,
        email: json['email'] as String,
        isAdmin: json['isAdmin'] as bool? ?? false,
        comboCount: json['comboCount'] as int? ?? 0,
      );
}
