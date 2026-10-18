import '../models/transaction.dart';

/// Hasil penjumlahan pemasukan & pengeluaran.
///
/// ATURAN KUNCI (anti double-count): transfer antar dompet milik sendiri
/// BUKAN pemasukan dan BUKAN pengeluaran — ia hanya memindahkan uang.
/// Fungsi ini adalah satu-satunya tempat aturan itu ditegakkan untuk
/// agregat, dan dikunci oleh unit test `transfer_exclusion_test.dart`.
class TransactionTotals {
  final int income;
  final int expense;

  const TransactionTotals({required this.income, required this.expense});

  int get net => income - expense;

  /// Sama dengan net: sisa uang bulan ini.
  int get savings => income - expense;
}

TransactionTotals totalsExcludingTransfers(Iterable<SakuTransaction> txs) {
  var income = 0;
  var expense = 0;
  for (final t in txs) {
    switch (t.type) {
      case TransactionType.income:
        income += t.amount;
      case TransactionType.expense:
        expense += t.amount;
      case TransactionType.transfer:
        break; // SENGAJA diabaikan — lihat doc di atas.
    }
  }
  return TransactionTotals(income: income, expense: expense);
}
