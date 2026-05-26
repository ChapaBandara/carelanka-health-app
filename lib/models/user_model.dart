class UserModel {
  final String id;
  final String title;
  final DateTime createdAt;

  const UserModel({required this.id, required this.title, required this.createdAt});

  factory UserModel.fromMap(Map<String, dynamic> map) => UserModel(
        id: map['id']?.toString() ?? '',
        title: map['title']?.toString() ?? '',
        createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
      );

  Map<String, dynamic> toMap() => {'id': id, 'title': title, 'createdAt': createdAt.toIso8601String()};

  UserModel copyWith({String? id, String? title, DateTime? createdAt}) =>
      UserModel(id: id ?? this.id, title: title ?? this.title, createdAt: createdAt ?? this.createdAt);
}
