import 'package:flutter_test/flutter_test.dart';
import 'package:saku/src/logic/budget_periods.dart';
import 'package:saku/src/models/budget.dart';
import 'package:saku/src/models/transaction.dart';

SakuTransaction _tx(String id, DateTime date, int amount,
        {String? categoryId = 'c1'}) =>
    SakuTransaction(
      id: id,
      type: TransactionType.expense,
      amount: amount,
      categoryId: categoryId,
      walletId: 'w1',
      date: date,
    );

void main() {
  group('BudgetPeriods.rangeFor', () {
    test('weekly: Senin–Minggu dari minggu berjalan', () {
      // Rabu 2026-10-21.
      final r = BudgetPeriods.rangeFor(
          BudgetPeriodType.weekly, DateTime(2026, 10, 21));
      expect(r.start, DateTime(2026, 10, 19)); // Senin
      expect(r.end.day, 25); // Minggu
      expect(r.end.month, 10);
    });

    test('monthly: 1 sampai akhir bulan', () {
      final r = BudgetPeriods.rangeFor(
          BudgetPeriodType.monthly, DateTime(2026, 2, 15));
      expect(r.start, DateTime(2026, 2, 1));
      expect(r.end, DateTime(2026, 3, 1)
          .subtract(const Duration(milliseconds: 1)));
      expect(r.end.day, 28);
    });

    test('custom: pakai tanggal apa adanya', () {
      final r = BudgetPeriods.rangeFor(
        BudgetPeriodType.custom,
        DateTime(2026, 10, 1),
        customStart: DateTime(2026, 10, 10),
        customEnd: DateTime(2026, 10, 12),
      );
      expect(r.start, DateTime(2026, 10, 10));
      expect(r.end.day, 12);
      expect(r.end.hour, 23);
    });
  });

  group('BudgetPeriods.spentByCategory', () {
    test('hanya hitung expense dalam rentang, transfer dikecualikan',
        () {
      final txs = [
        _tx('1', DateTime(2026, 10, 5, 12), 50000),
        _tx('2', DateTime(2026, 10, 20, 12), 30000),
        _tx('3', DateTime(2026, 9, 30, 12), 99999), // di luar
        _tx('4', DateTime(2026, 10, 6, 12), 1000,
            categoryId: null), // tanpa kategori
        SakuTransaction(
          id: '5',
          type: TransactionType.transfer,
          amount: 200000,
          walletId: 'w1',
          toWalletId: 'w2',
          date: DateTime(2026, 10, 7, 12),
        ),
        SakuTransaction(
          id: '6',
          type: TransactionType.income,
          amount: 100000,
          categoryId: 'c1',
          walletId: 'w1',
          date: DateTime(2026, 10, 8, 12),
        ),
      ];
      final m = BudgetPeriods.spentByCategory(
          txs, DateTime(2026, 10, 1), DateTime(2026, 10, 31, 23, 59, 59));
      expect(m['c1'], 80000);
      expect(m.length, 1);
    });
  });

  group('BudgetPeriods.ratio', () {
    test('limit 0 = 0.0 (tidak bagi nol)', () {
      expect(BudgetPeriods.ratio(500, 0), 0.0);
    });

    test('bisa > 1 saat jebol', () {
      expect(BudgetPeriods.ratio(120000, 100000), 1.2);
    });
  });

  group('Budget.range', () {
    test('monthly tanpa startMs dihitung dari month', () {
      const b = Budget(
          id: 'b1', categoryId: 'c1', month: '2026-10', limit: 1000);
      final r = b.range;
      expect(r.start, DateTime(2026, 10, 1));
      expect(r.end.month, 10);
      expect(r.end.day, 31);
    });

    test('startMs/endMs dipakai bila ada', () {
      final b = Budget(
        id: 'b1',
        categoryId: 'c1',
        month: '2026-10',
        limit: 1000,
        periodType: BudgetPeriodType.weekly,
        startMs: DateTime(2026, 10, 19).millisecondsSinceEpoch,
        endMs: DateTime(2026, 10, 25, 23, 59, 59, 999)
            .millisecondsSinceEpoch,
      );
      final r = b.range;
      expect(r.start, DateTime(2026, 10, 19));
      expect(r.end.day, 25);
    });
  });
}
