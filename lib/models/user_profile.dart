class UserProfile {
  final String fullName;
  final String email;
  final String phone;
  final DateTime? dateOfBirth;
  final String? gender;
  final String? bloodType;
  final String? profileImageUrl;
  final String? emergencyContactName;
  final String? emergencyContactPhone;
  final bool isDependent;
  final String? guardianName;

  const UserProfile({
    required this.fullName,
    required this.email,
    required this.phone,
    this.dateOfBirth,
    this.gender,
    this.bloodType,
    this.profileImageUrl,
    this.emergencyContactName,
    this.emergencyContactPhone,
    this.isDependent = false,
    this.guardianName,
  });

  String get firstName {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    return parts.isEmpty ? 'there' : parts.first;
  }

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  Map<String, dynamic> toJson() => {
        'fullName': fullName,
        'email': email,
        'phone': phone,
        'dateOfBirth': dateOfBirth?.toIso8601String(),
        'gender': gender,
        'bloodType': bloodType,
        'profileImageUrl': profileImageUrl,
        'emergencyContactName': emergencyContactName,
        'emergencyContactPhone': emergencyContactPhone,
        'isDependent': isDependent,
        'guardianName': guardianName,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        fullName: json['fullName'] as String? ?? '',
        email: json['email'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        dateOfBirth: json['dateOfBirth'] != null ? DateTime.tryParse(json['dateOfBirth'] as String) : null,
        gender: json['gender'] as String?,
        bloodType: json['bloodType'] as String?,
        profileImageUrl: json['profileImageUrl'] as String?,
        emergencyContactName: json['emergencyContactName'] as String?,
        emergencyContactPhone: json['emergencyContactPhone'] as String?,
        isDependent: json['isDependent'] as bool? ?? false,
        guardianName: json['guardianName'] as String?,
      );

  UserProfile copyWith({
    String? fullName,
    String? email,
    String? phone,
    DateTime? dateOfBirth,
    String? gender,
    String? bloodType,
    String? profileImageUrl,
    String? emergencyContactName,
    String? emergencyContactPhone,
    bool? isDependent,
    String? guardianName,
  }) =>
      UserProfile(
        fullName: fullName ?? this.fullName,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        dateOfBirth: dateOfBirth ?? this.dateOfBirth,
        gender: gender ?? this.gender,
        bloodType: bloodType ?? this.bloodType,
        profileImageUrl: profileImageUrl ?? this.profileImageUrl,
        emergencyContactName: emergencyContactName ?? this.emergencyContactName,
        emergencyContactPhone: emergencyContactPhone ?? this.emergencyContactPhone,
        isDependent: isDependent ?? this.isDependent,
        guardianName: guardianName ?? this.guardianName,
      );
}
