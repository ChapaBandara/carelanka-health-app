class AllergyModel {
  final String id;
  final String title;
  final DateTime createdAt;

  const AllergyModel({required this.id, required this.title, required this.createdAt});

  factory AllergyModel.fromMap(Map<String, dynamic> map) => AllergyModel(
        id: map['id']?.toString() ?? '',
        title: map['title']?.toString() ?? '',
        createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
      );

  Map<String, dynamic> toMap() => {'id': id, 'title': title, 'createdAt': createdAt.toIso8601String()};

  AllergyModel copyWith({String? id, String? title, DateTime? createdAt}) =>
      AllergyModel(id: id ?? this.id, title: title ?? this.title, createdAt: createdAt ?? this.createdAt);
}
