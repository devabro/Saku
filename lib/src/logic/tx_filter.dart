import '../models/transaction.dart';

/// Filter daftar transaksi. Murni Dart — unit-testable.
class TxFilter {
  final String query;
  final DateTime? from;
  final DateTime? to;
  final String? categoryId;
  final String? walletId;
  final TransactionType? type;
  final int? minAmount;
  final int? maxAmount;

  const TxFilter({
    this.query = '',
    this.from,
    this.to,
    this.categoryId,
    this.walletId,
    this.type,
    this.minAmount,
    this.maxAmount,
  });

  bool get isActive =>
      query.isNotEmpty ||
      from != null ||
      to != null ||
      categoryId != null ||
      walletId != null ||
      type != null ||
      minAmount != null ||
      maxAmount != null;

  TxFilter copyWith({
    String? query,
    DateTime? Function()? from,
    DateTime? Function()? to,
    String? Function()? categoryId,
    String? Function()? walletId,
    TransactionType? Function()? type,
    int? Function()? minAmount,
    int? Function()? maxAmount,
  }) =>
      TxFilter(
        query: query ?? this.query,
        from: from != null ? from() : this.from,
        to: to != null ? to() : this.to,
        categoryId:
            categoryId != null ? categoryId() : this.categoryId,
        walletId: walletId != null ? walletId() : this.walletId,
        type: type != null ? type() : this.type,
        minAmount:
            minAmount != null ? minAmount() : this.minAmount,
        maxAmount:
            maxAmount != null ? maxAmount() : this.maxAmount,
      );

  List<SakuTransaction> apply(
    List<SakuTransaction> txs,
    Map<String, String> categoryNames,
  ) {
    final q = query.toLowerCase();
    return txs.where((t) {
      if (q.isNotEmpty) {
        final inNote = t.note.toLowerCase().contains(q);
        final inCat =
            (categoryNames[t.categoryId] ?? '').toLowerCase().contains(q);
        if (!inNote && !inCat) return false;
      }
      if (from != null && t.date.isBefore(from!)) return false;
      if (to != null && t.date.isAfter(to!)) return false;
      if (categoryId != null && t.categoryId != categoryId) return false;
      if (walletId != null &&
          t.walletId != walletId &&
          t.toWalletId != walletId) {
        return false;
      }
      if (type != null && t.type != type) return false;
      if (minAmount != null && t.amount < minAmount!) return false;
      if (maxAmount != null && t.amount > maxAmount!) return false;
      return true;
    }).toList();
  }
}
