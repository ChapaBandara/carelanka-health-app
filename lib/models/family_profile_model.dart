class FamilyProfileModel {
  final String id;
  final String title;
  final DateTime createdAt;

  const FamilyProfileModel({required this.id, required this.title, required this.createdAt});

  factory FamilyProfileModel.fromMap(Map<String, dynamic> map) => FamilyProfileModel(
        id: map['id']?.toString() ?? '',
        title: map['title']?.toString() ?? '',
        createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
      );

  Map<String, dynamic> toMap() => {'id': id, 'title': title, 'createdAt': createdAt.toIso8601String()};

  FamilyProfileModel copyWith({String? id, String? title, DateTime? createdAt}) =>
      FamilyProfileModel(id: id ?? this.id, title: title ?? this.title, createdAt: createdAt ?? this.createdAt);
}
