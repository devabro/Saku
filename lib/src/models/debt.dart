/// Utang-piutang.
/// [DebtKind.utang]: kita berutang KE orang lain (uang masuk saat dibuat).
/// [DebtKind.piutang]: orang lain berutang ke kita (uang keluar saat dibuat).
enum DebtKind {
  utang('Utang'),
  piutang('Piutang');

  const DebtKind(this.label);
  final String label;
}

class Debt {
  final String id;
  final String personName;
  final DebtKind kind;
  final int totalAmount; // rupiah, positif
  final int paidAmount; // rupiah, sudah dibayar/diterima
  final DateTime? dueDate;
  final String walletId; // dompet yang dipakai saat buat/lunasi
  final String note;
  final DateTime createdAt;

  const Debt({
    required this.id,
    required this.personName,
    required this.kind,
    required this.totalAmount,
    this.paidAmount = 0,
    this.dueDate,
    required this.walletId,
    this.note = '',
    required this.createdAt,
  });

  int get remaining => (totalAmount - paidAmount).clamp(0, totalAmount);

  Debt copyWith({int? paidAmount, DateTime? dueDate, String? note}) => Debt(
        id: id,
        personName: personName,
        kind: kind,
        totalAmount: totalAmount,
        paidAmount: paidAmount ?? this.paidAmount,
        dueDate: dueDate ?? this.dueDate,
        walletId: walletId,
        note: note ?? this.note,
        createdAt: createdAt,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'personName': personName,
        'kind': kind.name,
        'totalAmount': totalAmount,
        'paidAmount': paidAmount,
        'dueMs': dueDate?.millisecondsSinceEpoch,
        'walletId': walletId,
        'note': note,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory Debt.fromMap(Map<String, Object?> m) => Debt(
        id: m['id']! as String,
        personName: m['personName']! as String,
        kind: DebtKind.values.byName(m['kind']! as String),
        totalAmount: (m['totalAmount']! as num).toInt(),
        paidAmount: (m['paidAmount'] as num?)?.toInt() ?? 0,
        dueDate: (m['dueMs'] as num?) == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(
                (m['dueMs']! as num).toInt()),
        walletId: m['walletId']! as String,
        note: (m['note'] as String?) ?? '',
        createdAt: DateTime.fromMillisecondsSinceEpoch(
            (m['createdAt']! as num).toInt()),
      );
}
