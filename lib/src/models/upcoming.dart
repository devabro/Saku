import 'transaction.dart';

/// Transaksi terjadwal: dicatat sekarang, jadi transaksi beneran
/// (dan baru memengaruhi saldo) saat pengguna menandai "sudah dibayar".
class UpcomingTx {
  final String id;
  final TransactionType type; // expense / income saja
  final int amount;
  final String? categoryId;
  final String walletId;
  final String note;
  final DateTime dueDate;
  final bool remind;
  final DateTime createdAt;

  const UpcomingTx({
    required this.id,
    required this.type,
    required this.amount,
    this.categoryId,
    required this.walletId,
    this.note = '',
    required this.dueDate,
    this.remind = false,
    required this.createdAt,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'type': type.name,
        'amount': amount,
        'categoryId': categoryId,
        'walletId': walletId,
        'note': note,
        'dueMs': dueDate.millisecondsSinceEpoch,
        'remind': remind ? 1 : 0,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory UpcomingTx.fromMap(Map<String, Object?> m) => UpcomingTx(
        id: m['id']! as String,
        type: TransactionType.values.byName(m['type']! as String),
        amount: (m['amount']! as num).toInt(),
        categoryId: m['categoryId'] as String?,
        walletId: m['walletId']! as String,
        note: (m['note'] as String?) ?? '',
        dueDate:
            DateTime.fromMillisecondsSinceEpoch((m['dueMs']! as num).toInt()),
        remind: ((m['remind'] as num?)?.toInt() ?? 0) == 1,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
            (m['createdAt']! as num).toInt()),
      );
}
