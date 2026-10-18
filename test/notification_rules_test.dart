import 'package:flutter_test/flutter_test.dart';
import 'package:saku/src/logic/notification_rules.dart';
import 'package:saku/src/logic/tx_filter.dart';
import 'package:saku/src/models/budget.dart';
import 'package:saku/src/models/debt.dart';
import 'package:saku/src/models/transaction.dart';
import 'package:saku/src/models/upcoming.dart';

Budget _budget(String id, int limit,
        {BudgetPeriodType type = BudgetPeriodType.monthly}) =>
    Budget(
      id: id,
      categoryId: 'c1',
      month: '2026-10',
      limit: limit,
      periodType: type,
      startMs: DateTime(2026, 10, 1).millisecondsSinceEpoch,
      endMs: DateTime(2026, 10, 31, 23, 59, 59, 999)
          .millisecondsSinceEpoch,
    );

void main() {
  group('NotificationRules.budgetAlerts', () {
    test('100% muncul sekali, lalu 80% tidak spam bila sudah ada', () {
      final budgets = [_budget('b1', 100000)];
      int spent(Budget b) => 120000;
      final names = {'c1': 'Makan'};
      final first =
          NotificationRules.budgetAlerts(budgets, spent, names, {});
      expect(first.length, 1);
      expect(first.first.id, 'b1@100');

      // Sudah dinotifikasi 100% -> tidak muncul lagi.
      final second = NotificationRules.budgetAlerts(
          budgets, spent, names, {'b1@100'});
      expect(second, isEmpty);
    });

    test('80% muncul untuk yang hampir habis', () {
      final budgets = [_budget('b1', 100000)];
      int spent(Budget b) => 85000;
      final out = NotificationRules.budgetAlerts(
          budgets, spent, {'c1': 'Makan'}, {});
      expect(out.length, 1);
      expect(out.first.id, 'b1@80');
    });

    test('di bawah 80% tidak ada notifikasi', () {
      final budgets = [_budget('b1', 100000)];
      int spent(Budget b) => 50000;
      final out = NotificationRules.budgetAlerts(
          budgets, spent, {'c1': 'Makan'}, {});
      expect(out, isEmpty);
    });
  });

  group('NotificationRules.upcomingAlerts', () {
    UpcomingTx makeUpcoming(String id, DateTime due,
            {bool remind = true}) =>
        UpcomingTx(
          id: id,
          type: TransactionType.expense,
          amount: 50000,
          walletId: 'w1',
          note: 'Bayar $id',
          dueDate: due,
          remind: remind,
          createdAt: DateTime(2026, 10, 1),
        );

    test('hari ini dan besok muncul; lusa tidak', () {
      final now = DateTime(2026, 10, 19, 10);
      final items = [
        makeUpcoming('a', DateTime(2026, 10, 19)),
        makeUpcoming('b', DateTime(2026, 10, 20)),
        makeUpcoming('c', DateTime(2026, 10, 21)),
        makeUpcoming('d', DateTime(2026, 10, 19), remind: false),
      ];
      final out =
          NotificationRules.upcomingAlerts(items, now, {'w1': 'Tunai'});
      expect(out.map((n) => n.id),
          ['upcoming:a:0', 'upcoming:b:1']);
    });
  });

  group('NotificationRules.debtAlerts', () {
    Debt makeDebt(String id, DateTime? due,
            {int total = 1000000, int paid = 0}) =>
        Debt(
          id: id,
          personName: 'Budi',
          kind: DebtKind.utang,
          totalAmount: total,
          paidAmount: paid,
          dueDate: due,
          walletId: 'w1',
          createdAt: DateTime(2026, 10, 1),
        );

    test('overdue dan due-soon terdeteksi', () {
      final now = DateTime(2026, 10, 19, 10);
      final debts = [
        makeDebt('over', DateTime(2026, 10, 15)),
        makeDebt('soon', DateTime(2026, 10, 21)),
        makeDebt('far', DateTime(2026, 11, 1)),
        makeDebt('paid',
            DateTime(2026, 10, 15), total: 100, paid: 100),
      ];
      final out = NotificationRules.debtAlerts(debts, now);
      expect(out.map((n) => n.id),
          ['debt:overdue:over', 'debt:soon:soon:2']);
    });
  });

  group('TxFilter', () {
    SakuTransaction tx(String id, TransactionType t, int amount,
            {String? cat, DateTime? date, String note = ''}) =>
        SakuTransaction(
          id: id,
          type: t,
          amount: amount,
          categoryId: cat,
          walletId: 'w1',
          note: note,
          date: date ?? DateTime(2026, 10, 10, 12),
        );

    final txs = [
      tx('1', TransactionType.expense, 50000,
          cat: 'c1', note: 'Kopi'),
      tx('2', TransactionType.income, 5000000,
          cat: 'c2', note: 'Gaji'),
      tx('3', TransactionType.expense, 150000,
          cat: 'c1',
          date: DateTime(2026, 9, 5, 12),
          note: 'Bensin'),
    ];
    const names = {'c1': 'Makan', 'c2': 'Gaji'};

    test('tanpa filter = semua', () {
      expect(const TxFilter().apply(txs, names).length, 3);
    });

    test('filter tipe', () {
      final out = const TxFilter(type: TransactionType.expense)
          .apply(txs, names);
      expect(out.map((t) => t.id), ['1', '3']);
    });

    test('filter rentang tanggal', () {
      final out = TxFilter(
        from: DateTime(2026, 10, 1),
        to: DateTime(2026, 10, 31, 23, 59, 59),
      ).apply(txs, names);
      expect(out.map((t) => t.id), ['1', '2']);
    });

    test('filter nominal min/maks', () {
      final out = const TxFilter(minAmount: 100000, maxAmount: 200000)
          .apply(txs, names);
      expect(out.map((t) => t.id), ['3']);
    });

    test('filter kategori + query', () {
      final out = const TxFilter(categoryId: 'c1', query: 'bensin')
          .apply(txs, names);
      expect(out.map((t) => t.id), ['3']);
    });

    test('copyWith bisa reset field nullable via fungsi', () {
      const f = TxFilter(type: TransactionType.expense);
      final cleared = f.copyWith(type: () => null);
      expect(cleared.type, isNull);
    });
  });
}
