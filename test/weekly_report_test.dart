import 'package:flutter_test/flutter_test.dart';
import 'package:saku/src/logic/budget_periods.dart';
import 'package:saku/src/logic/weekly_report.dart';
import 'package:saku/src/models/budget.dart';
import 'package:saku/src/models/transaction.dart';

SakuTransaction _tx(String id, DateTime date, int amount,
        {TransactionType type = TransactionType.expense}) =>
    SakuTransaction(
      id: id,
      type: type,
      amount: amount,
      categoryId: 'c1',
      walletId: 'w1',
      date: date,
    );

void main() {
  // Rabu 2026-10-21 → minggu ini 19–25 Okt, minggu lalu 12–18 Okt.
  final now = DateTime(2026, 10, 21);
  final thisW = BudgetPeriods.rangeFor(BudgetPeriodType.weekly, now);
  final lastW = BudgetPeriods.rangeFor(
      BudgetPeriodType.weekly, now.subtract(const Duration(days: 7)));

  WeeklyReport compute(List<SakuTransaction> txs) => WeeklyReport.compute(
        txs,
        thisW.start,
        thisW.end,
        lastW.start,
        lastW.end,
      );

  group('WeeklyReport', () {
    test('hitung total & persen perubahan', () {
      final txs = [
        _tx('1', DateTime(2026, 10, 20), 600000), // minggu ini
        _tx('2', DateTime(2026, 10, 19), 400000), // minggu ini
        _tx('3', DateTime(2026, 10, 14), 500000), // minggu lalu
      ];
      final r = compute(txs);
      expect(r.thisWeek, 1000000);
      expect(r.lastWeek, 500000);
      expect(r.pctChange, 100);
      expect(r.up, true);
    });

    test('transfer dikecualikan', () {
      final txs = [
        _tx('1', DateTime(2026, 10, 20), 500000,
            type: TransactionType.transfer),
      ];
      final r = compute(txs);
      expect(r.thisWeek, 0);
    });

    test('transaksi di luar 2 minggu diabaikan', () {
      final txs = [
        _tx('1', DateTime(2026, 10, 5), 999000), // 2 minggu lalu
      ];
      final r = compute(txs);
      expect(r.thisWeek, 0);
      expect(r.lastWeek, 0);
    });

    test('narasi turun = penyemangat', () {
      final txs = [
        _tx('1', DateTime(2026, 10, 20), 400000),
        _tx('2', DateTime(2026, 10, 14), 800000),
      ];
      final r = compute(txs);
      expect(r.down, true);
      expect(r.narrative, contains('turun 50%'));
      expect(r.narrative, contains('Mantap'));
    });

    test('narasi naik = teguran halus', () {
      final txs = [
        _tx('1', DateTime(2026, 10, 20), 800000),
        _tx('2', DateTime(2026, 10, 14), 400000),
      ];
      final r = compute(txs);
      expect(r.up, true);
      expect(r.narrative, contains('naik 100%'));
    });

    test('kosong dua-duanya = santai', () {
      final r = compute([]);
      expect(r.narrative, contains('Santai'));
    });
  });
}
