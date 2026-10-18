import '../models/budget.dart';
import '../models/transaction.dart';
import 'money.dart';

/// Logika periode budget: hitung rentang tanggal untuk weekly/monthly/custom
/// dan total belanja per kategori di dalam rentang itu. Murni Dart.
class BudgetPeriods {
  BudgetPeriods._();

  /// Rentang [start, end] inklusif untuk tipe periode.
  /// - weekly: Senin–Minggu dari minggu yang memuat [ref].
  /// - monthly: 1–akhir bulan dari [ref].
  /// - custom: [customStart]–[customEnd] apa adanya.
  static ({DateTime start, DateTime end}) rangeFor(
    BudgetPeriodType type,
    DateTime ref, {
    DateTime? customStart,
    DateTime? customEnd,
  }) {
    switch (type) {
      case BudgetPeriodType.weekly:
        final start = ref.subtract(Duration(days: ref.weekday - 1));
        final s = DateTime(start.year, start.month, start.day);
        return (
          start: s,
          end: s.add(const Duration(days: 7)).subtract(
              const Duration(milliseconds: 1)),
        );
      case BudgetPeriodType.monthly:
        final s = DateTime(ref.year, ref.month);
        return (
          start: s,
          end: DateTime(ref.year, ref.month + 1)
              .subtract(const Duration(milliseconds: 1)),
        );
      case BudgetPeriodType.custom:
        final s = customStart ?? ref;
        final e = customEnd ?? ref;
        return (
          start: DateTime(s.year, s.month, s.day),
          end: DateTime(e.year, e.month, e.day, 23, 59, 59, 999),
        );
    }
  }

  /// Total pengeluaran per kategori dari [txs] yang tanggalnya
  /// masuk rentang [start]–[end] inklusif. Transfer dikecualikan.
  static Map<String, int> spentByCategory(
    List<SakuTransaction> txs,
    DateTime start,
    DateTime end,
  ) {
    final out = <String, int>{};
    for (final t in txs) {
      if (t.type != TransactionType.expense) continue;
      if (t.categoryId == null) continue;
      if (t.date.isBefore(start) || t.date.isAfter(end)) continue;
      out[t.categoryId!] = (out[t.categoryId!] ?? 0) + t.amount;
    }
    return out;
  }

  /// Rasio pakai 0..1+ (bisa >1 kalau jebol).
  static double ratio(int spent, int limit) =>
      limit <= 0 ? 0.0 : spent / limit;

  /// Label ringkas rentang, mis. "12/10–18/10" atau "Oktober 2026".
  static String rangeLabel(BudgetPeriodType type, DateTime start, DateTime end) {
    if (type == BudgetPeriodType.monthly) {
      return monthLabel(monthKey(start));
    }
    final s = '${start.day}/${start.month}';
    final e = start.year == end.year && start.month == end.month
        ? '${end.day}/${end.month}'
        : '${end.day}/${end.month}/${end.year}';
    return '$s–$e';
  }
}
