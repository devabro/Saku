/// Transaksi. Nama kelas memakai prefix `Saku` agar tidak bentrok
/// dengan `Transaction` milik sqflite.
enum TransactionType {
  expense('Pengeluaran'),
  income('Pemasukan'),
  transfer('Transfer');

  const TransactionType(this.label);
  final String label;
}

class SakuTransaction {
  final String id;
  final TransactionType type;
  final int amount; // rupiah, selalu positif
  final String? categoryId; // null untuk transfer
  final String walletId; // dompet sumber (atau dompet transaksi)
  final String? toWalletId; // dompet tujuan — hanya untuk transfer
  final String note;
  final DateTime date;
  final String? receiptPath; // path foto struk di app documents dir
  final String? recurringId; // asal recurring, jika auto-generated

  const SakuTransaction({
    required this.id,
    required this.type,
    required this.amount,
    this.categoryId,
    required this.walletId,
    this.toWalletId,
    this.note = '',
    required this.date,
    this.receiptPath,
    this.recurringId,
  });

  SakuTransaction copyWith({
    TransactionType? type,
    int? amount,
    String? categoryId,
    String? walletId,
    String? toWalletId,
    String? note,
    DateTime? date,
    String? receiptPath,
  }) =>
      SakuTransaction(
        id: id,
        type: type ?? this.type,
        amount: amount ?? this.amount,
        categoryId: categoryId ?? this.categoryId,
        walletId: walletId ?? this.walletId,
        toWalletId: toWalletId ?? this.toWalletId,
        note: note ?? this.note,
        date: date ?? this.date,
        receiptPath: receiptPath ?? this.receiptPath,
        recurringId: recurringId,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'type': type.name,
        'amount': amount,
        'categoryId': categoryId,
        'walletId': walletId,
        'toWalletId': toWalletId,
        'note': note,
        'date': date.millisecondsSinceEpoch,
        'receiptPath': receiptPath,
        'recurringId': recurringId,
      };

  factory SakuTransaction.fromMap(Map<String, Object?> m) => SakuTransaction(
        id: m['id']! as String,
        type: TransactionType.values.byName(m['type']! as String),
        amount: (m['amount']! as num).toInt(),
        categoryId: m['categoryId'] as String?,
        walletId: m['walletId']! as String,
        toWalletId: m['toWalletId'] as String?,
        note: (m['note'] as String?) ?? '',
        date: DateTime.fromMillisecondsSinceEpoch((m['date']! as num).toInt()),
        receiptPath: m['receiptPath'] as String?,
        recurringId: m['recurringId'] as String?,
      );
}
