class IllnessModel {
  final String id;
  final String title;
  final DateTime createdAt;

  const IllnessModel({required this.id, required this.title, required this.createdAt});

  factory IllnessModel.fromMap(Map<String, dynamic> map) => IllnessModel(
        id: map['id']?.toString() ?? '',
        title: map['title']?.toString() ?? '',
        createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
      );

  Map<String, dynamic> toMap() => {'id': id, 'title': title, 'createdAt': createdAt.toIso8601String()};

  IllnessModel copyWith({String? id, String? title, DateTime? createdAt}) =>
      IllnessModel(id: id ?? this.id, title: title ?? this.title, createdAt: createdAt ?? this.createdAt);
}
