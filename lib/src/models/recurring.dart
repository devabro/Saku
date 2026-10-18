enum RecurringFrequency {
  harian('Harian'),
  mingguan('Mingguan'),
  bulanan('Bulanan'),
  tahunan('Tahunan');

  const RecurringFrequency(this.label);
  final String label;
}

/// Transaksi berulang: langganan, cicilan, gaji.
/// [nextDue] adalah jadwal berikutnya yang belum diproses.
class Recurring {
  final String id;
  final String name;
  final String type; // 'expense' | 'income'
  final int amount;
  final String categoryId;
  final String walletId;
  final RecurringFrequency frequency;
  final DateTime nextDue;
  final bool active;
  final String note;

  const Recurring({
    required this.id,
    required this.name,
    required this.type,
    required this.amount,
    required this.categoryId,
    required this.walletId,
    required this.frequency,
    required this.nextDue,
    this.active = true,
    this.note = '',
  });

  /// Jadwal berikutnya setelah [from].
  DateTime advance(DateTime from) {
    switch (frequency) {
      case RecurringFrequency.harian:
        return from.add(const Duration(days: 1));
      case RecurringFrequency.mingguan:
        return from.add(const Duration(days: 7));
      case RecurringFrequency.bulanan:
        return DateTime(from.year, from.month + 1, from.day);
      case RecurringFrequency.tahunan:
        return DateTime(from.year + 1, from.month, from.day);
    }
  }

  Recurring copyWith({DateTime? nextDue, bool? active}) => Recurring(
        id: id,
        name: name,
        type: type,
        amount: amount,
        categoryId: categoryId,
        walletId: walletId,
        frequency: frequency,
        nextDue: nextDue ?? this.nextDue,
        active: active ?? this.active,
        note: note,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'type': type,
        'amount': amount,
        'categoryId': categoryId,
        'walletId': walletId,
        'frequency': frequency.name,
        'nextDue': nextDue.millisecondsSinceEpoch,
        'active': active ? 1 : 0,
        'note': note,
      };

  factory Recurring.fromMap(Map<String, Object?> m) => Recurring(
        id: m['id']! as String,
        name: m['name']! as String,
        type: m['type']! as String,
        amount: (m['amount']! as num).toInt(),
        categoryId: m['categoryId']! as String,
        walletId: m['walletId']! as String,
        frequency: RecurringFrequency.values.byName(m['frequency']! as String),
        nextDue:
            DateTime.fromMillisecondsSinceEpoch((m['nextDue']! as num).toInt()),
        active: (m['active']! as num).toInt() == 1,
        note: (m['note'] as String?) ?? '',
      );
}
