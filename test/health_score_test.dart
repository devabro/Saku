import 'package:flutter_test/flutter_test.dart';
import 'package:saku/src/logic/health_score.dart';

HealthInputs _base() => const HealthInputs(
      budgetLimits: {'makan': 2000000, 'transport': 1000000},
      spentByCategory: {'makan': 1500000, 'transport': 800000},
      incomeThisMonth: 10000000,
      expenseThisMonth: 6000000,
      monthlyExpenses: [6000000, 6000000, 6100000, 5900000],
      goalProgress: [0.8],
    );

void main() {
  group('HealthScore', () {
    test('user rapi: skor tinggi (>=80)', () {
      final r = HealthScore.compute(_base());
      expect(r.score, greaterThanOrEqualTo(80));
      expect(r.score, lessThanOrEqualTo(100));
    });

    test('jebol budget + boros menurunkan skor', () {
      final bad = HealthInputs(
        budgetLimits: _base().budgetLimits,
        spentByCategory: const {'makan': 4000000, 'transport': 2000000},
        incomeThisMonth: 10000000,
        expenseThisMonth: 12000000, // lebih besar dari pemasukan
        monthlyExpenses: const [12000000, 6000000, 20000000, 5000000],
        goalProgress: const [0.1],
      );
      final good = HealthScore.compute(_base());
      final worse = HealthScore.compute(bad);
      expect(worse.score, lessThan(good.score));
      expect(worse.score, lessThan(60));
    });

    test('tanpa data: skor netral di tengah (tidak 0, tidak 100)', () {
      final r = HealthScore.compute(const HealthInputs(
        budgetLimits: {},
        spentByCategory: {},
        incomeThisMonth: 0,
        expenseThisMonth: 0,
        monthlyExpenses: [],
        goalProgress: [],
      ));
      // 0.4*0.5 + 0.25*0 + 0.2*0.5 + 0.15*0.5 = 37.5 -> 38
      expect(r.score, inInclusiveRange(30, 45));
    });

    test('skor selalu dalam 0..100 walau input ekstrem', () {
      final r = HealthScore.compute(const HealthInputs(
        budgetLimits: {'a': 1},
        spentByCategory: {'a': 999999999999},
        incomeThisMonth: 1,
        expenseThisMonth: 999999999999,
        monthlyExpenses: [999999999999, 0, 999999999999, 0],
        goalProgress: [999.0],
      ));
      expect(r.score, inInclusiveRange(0, 100));
    });

    test('grade() konsisten dengan rentang skor', () {
      expect(HealthScore.grade(90), 'Sehat banget');
      expect(HealthScore.grade(70), 'Sehat');
      expect(HealthScore.grade(50), 'Perlu perhatian');
      expect(HealthScore.grade(10), 'Kritis');
    });
  });
}
