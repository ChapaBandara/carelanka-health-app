class LinkRequestModel {
  final String id;
  final String title;
  final DateTime createdAt;

  const LinkRequestModel({required this.id, required this.title, required this.createdAt});

  factory LinkRequestModel.fromMap(Map<String, dynamic> map) => LinkRequestModel(
        id: map['id']?.toString() ?? '',
        title: map['title']?.toString() ?? '',
        createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
      );

  Map<String, dynamic> toMap() => {'id': id, 'title': title, 'createdAt': createdAt.toIso8601String()};

  LinkRequestModel copyWith({String? id, String? title, DateTime? createdAt}) =>
      LinkRequestModel(id: id ?? this.id, title: title ?? this.title, createdAt: createdAt ?? this.createdAt);
}
