import '../models/transaction.dart';
import 'budget_periods.dart';
import 'money.dart';

/// Laporan mingguan otomatis: belanja minggu ini vs minggu lalu.
///
/// Minggu = Senin–Minggu (konsisten dengan [BudgetPeriods]).
/// Hanya pengeluaran yang dihitung — transfer dikecualikan.
class WeeklyReport {
  final int thisWeek;
  final int lastWeek;

  const WeeklyReport({required this.thisWeek, required this.lastWeek});

  /// Persen perubahan vs minggu lalu. 0 bila minggu lalu kosong.
  double get pctChange {
    if (lastWeek <= 0) return 0;
    return (thisWeek - lastWeek) / lastWeek * 100;
  }

  bool get up => thisWeek > lastWeek;
  bool get down => thisWeek < lastWeek;
  bool get flat => thisWeek == lastWeek;

  /// Narasi natural Bahasa Indonesia — bukan angka mentah doang.
  String get narrative {
    final w = formatIdrShort(thisWeek);
    if (thisWeek == 0 && lastWeek == 0) {
      return 'Belum ada belanja tercatat minggu ini. Santai~';
    }
    if (lastWeek == 0) {
      return 'Minggu ini $w. Minggu lalu belum ada data buat dibandingin.';
    }
    final p = pctChange.abs().round();
    if (flat) {
      return 'Minggu ini $w — sama persis kayak minggu lalu. Stabil!';
    }
    if (down) {
      return 'Minggu ini $w — turun $p% dari minggu lalu. Mantap, pertahankan!';
    }
    return 'Minggu ini $w — naik $p% dari minggu lalu. Jajan kebanyakan nih, rem dikit.';
  }

  /// Hitung dari daftar transaksi dalam rentang dua minggu.
  static WeeklyReport compute(
    List<SakuTransaction> txs,
    DateTime thisStart,
    DateTime thisEnd,
    DateTime lastStart,
    DateTime lastEnd,
  ) {
    var tw = 0;
    var lw = 0;
    for (final t in txs) {
      if (t.type != TransactionType.expense) continue;
      if (!_in(t.date, thisStart, thisEnd)) {
        if (_in(t.date, lastStart, lastEnd)) lw += t.amount;
        continue;
      }
      tw += t.amount;
    }
    return WeeklyReport(thisWeek: tw, lastWeek: lw);
  }

  static bool _in(DateTime d, DateTime start, DateTime end) =>
      !d.isBefore(start) && !d.isAfter(end);
}
