class ReminderLogModel {
  final String id;
  final String title;
  final DateTime createdAt;

  const ReminderLogModel({required this.id, required this.title, required this.createdAt});

  factory ReminderLogModel.fromMap(Map<String, dynamic> map) => ReminderLogModel(
        id: map['id']?.toString() ?? '',
        title: map['title']?.toString() ?? '',
        createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
      );

  Map<String, dynamic> toMap() => {'id': id, 'title': title, 'createdAt': createdAt.toIso8601String()};

  ReminderLogModel copyWith({String? id, String? title, DateTime? createdAt}) =>
      ReminderLogModel(id: id ?? this.id, title: title ?? this.title, createdAt: createdAt ?? this.createdAt);
}
