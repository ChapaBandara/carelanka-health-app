class AlertModel {
  final String id;
  final String title;
  final DateTime createdAt;

  const AlertModel({required this.id, required this.title, required this.createdAt});

  factory AlertModel.fromMap(Map<String, dynamic> map) => AlertModel(
        id: map['id']?.toString() ?? '',
        title: map['title']?.toString() ?? '',
        createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
      );

  Map<String, dynamic> toMap() => {'id': id, 'title': title, 'createdAt': createdAt.toIso8601String()};

  AlertModel copyWith({String? id, String? title, DateTime? createdAt}) =>
      AlertModel(id: id ?? this.id, title: title ?? this.title, createdAt: createdAt ?? this.createdAt);
}
