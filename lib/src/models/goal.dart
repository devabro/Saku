/// Target nabung: jumlah target + deadline + progres.
class Goal {
  final String id;
  final String name;
  final int targetAmount;
  final int savedAmount;
  final DateTime? deadline;
  final DateTime createdAt;

  const Goal({
    required this.id,
    required this.name,
    required this.targetAmount,
    this.savedAmount = 0,
    this.deadline,
    required this.createdAt,
  });

  /// 0.0 – 1.0 (bisa > 1.0 kalau kelebihan nabung).
  double get progress => targetAmount <= 0 ? 0 : savedAmount / targetAmount;

  Goal copyWith({String? name, int? targetAmount, int? savedAmount, DateTime? deadline}) =>
      Goal(
        id: id,
        name: name ?? this.name,
        targetAmount: targetAmount ?? this.targetAmount,
        savedAmount: savedAmount ?? this.savedAmount,
        deadline: deadline ?? this.deadline,
        createdAt: createdAt,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'targetAmount': targetAmount,
        'savedAmount': savedAmount,
        'deadline': deadline?.millisecondsSinceEpoch,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory Goal.fromMap(Map<String, Object?> m) => Goal(
        id: m['id']! as String,
        name: m['name']! as String,
        targetAmount: (m['targetAmount']! as num).toInt(),
        savedAmount: (m['savedAmount']! as num).toInt(),
        deadline: m['deadline'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch((m['deadline']! as num).toInt()),
        createdAt:
            DateTime.fromMillisecondsSinceEpoch((m['createdAt']! as num).toInt()),
      );
}
