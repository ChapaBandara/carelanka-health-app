class MedicationModel {
  final String id;
  final String title;
  final DateTime createdAt;

  const MedicationModel({required this.id, required this.title, required this.createdAt});

  factory MedicationModel.fromMap(Map<String, dynamic> map) => MedicationModel(
        id: map['id']?.toString() ?? '',
        title: map['title']?.toString() ?? '',
        createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
      );

  Map<String, dynamic> toMap() => {'id': id, 'title': title, 'createdAt': createdAt.toIso8601String()};

  MedicationModel copyWith({String? id, String? title, DateTime? createdAt}) =>
      MedicationModel(id: id ?? this.id, title: title ?? this.title, createdAt: createdAt ?? this.createdAt);
}
