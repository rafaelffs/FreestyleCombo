class ProfileDto {
  final String id;
  final String userName;
  final String email;
  final bool isAdmin;
  // Every combo this user has personally landed, regardless of who owns it
  // or its current visibility — not just landed combos among their own.
  final int landedCount;

  const ProfileDto({
    required this.id,
    required this.userName,
    required this.email,
    required this.isAdmin,
    required this.landedCount,
  });

  factory ProfileDto.fromJson(Map<String, dynamic> json) => ProfileDto(
        id: json['id'] as String,
        userName: json['userName'] as String,
        email: json['email'] as String,
        isAdmin: json['isAdmin'] as bool? ?? false,
        landedCount: json['landedCount'] as int? ?? 0,
      );
}

// No email — GET /account/{id} is unauthenticated (anyone can look up any
// user's profile by id), so the API no longer includes it here.
class PublicProfileDto {
  final String id;
  final String userName;

  const PublicProfileDto({
    required this.id,
    required this.userName,
  });

  factory PublicProfileDto.fromJson(Map<String, dynamic> json) =>
      PublicProfileDto(
        id: json['id'] as String,
        userName: json['userName'] as String,
      );
}

class AdminUserDto {
  final String id;
  final String userName;
  final String email;
  final bool isAdmin;
  final int comboCount;
  final DateTime createdAt;
  final String? authProvider;

  const AdminUserDto({
    required this.id,
    required this.userName,
    required this.email,
    required this.isAdmin,
    required this.comboCount,
    required this.createdAt,
    this.authProvider,
  });

  factory AdminUserDto.fromJson(Map<String, dynamic> json) => AdminUserDto(
        id: json['id'] as String,
        userName: json['userName'] as String,
        email: json['email'] as String,
        isAdmin: json['isAdmin'] as bool? ?? false,
        comboCount: json['comboCount'] as int? ?? 0,
        createdAt: DateTime.parse(json['createdAt'] as String),
        authProvider: json['authProvider'] as String?,
      );
}
