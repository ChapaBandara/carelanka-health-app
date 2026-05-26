class AppointmentModel {
  final String id;
  final String title;
  final DateTime createdAt;

  const AppointmentModel({required this.id, required this.title, required this.createdAt});

  factory AppointmentModel.fromMap(Map<String, dynamic> map) => AppointmentModel(
        id: map['id']?.toString() ?? '',
        title: map['title']?.toString() ?? '',
        createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
      );

  Map<String, dynamic> toMap() => {'id': id, 'title': title, 'createdAt': createdAt.toIso8601String()};

  AppointmentModel copyWith({String? id, String? title, DateTime? createdAt}) =>
      AppointmentModel(id: id ?? this.id, title: title ?? this.title, createdAt: createdAt ?? this.createdAt);
}
