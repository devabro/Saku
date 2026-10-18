import 'package:flutter_test/flutter_test.dart';
import 'package:saku/src/logic/insight_engine.dart';

InsightInputs _inputs() => const InsightInputs(
      incomeThisMonth: 10000000,
      expenseThisMonth: 3000000,
      spentByCategoryThisMonth: {'cat_makan': 2000000, 'cat_hiburan': 1000000},
      categoryNames: {'cat_makan': 'Makan & Minum', 'cat_hiburan': 'Hiburan'},
      last3MonthsByCategory: {
        'cat_makan': [1500000, 1600000, 1400000],
        // rata-rata 200rb, bulan ini 1jt -> > 2x lipat = anomali
        'cat_hiburan': [200000, 250000, 150000],
      },
      dayOfMonth: 15,
      daysInMonth: 30,
      budgetLimits: {'cat_makan': 2500000, 'cat_hiburan': 500000},
    );

void main() {
  group('InsightEngine', () {
    test('proyeksi akhir bulan muncul dari burn rate', () {
      final insights = InsightEngine.analyze(_inputs());
      final proj = insights.where((i) => i.title.contains('Proyeksi'));
      expect(proj, isNotEmpty);
      // 3jt / 15 hari = 200rb/hari * 30 hari = 6jt
      expect(proj.first.body, contains('Rp6.000.000'));
    });

    test('anomali terdeteksi saat belanja > 2x rata-rata 3 bulan', () {
      final insights = InsightEngine.analyze(_inputs());
      final anomaly = insights.where((i) => i.title.contains('Lonjakan'));
      expect(anomaly, isNotEmpty);
      expect(anomaly.first.title, contains('Hiburan'));
      expect(anomaly.first.severity, InsightSeverity.warning);
    });

    test('tidak ada anomali saat belanja normal', () {
      final normal = InsightInputs(
        incomeThisMonth: 10000000,
        expenseThisMonth: 1600000,
        spentByCategoryThisMonth: const {'cat_makan': 1600000},
        categoryNames: const {'cat_makan': 'Makan & Minum'},
        last3MonthsByCategory: const {
          'cat_makan': [1500000, 1600000, 1400000]
        },
        dayOfMonth: 15,
        daysInMonth: 30,
        budgetLimits: const {'cat_makan': 2500000},
      );
      final insights = InsightEngine.analyze(normal);
      expect(insights.where((i) => i.title.contains('Lonjakan')), isEmpty);
    });

    test('budget jebol (100%+) terdeteksi sebagai danger', () {
      final insights = InsightEngine.analyze(_inputs());
      final over = insights.where((i) => i.title.contains('jebol'));
      expect(over, isNotEmpty);
      expect(over.first.severity, InsightSeverity.danger);
      expect(over.first.body, contains('Hiburan'));
    });

    test('peringatan 80% muncul sebelum jebol', () {
      // makan: 2jt / 2,5jt = 80% -> warning "Mendekati batas"
      final insights = InsightEngine.analyze(_inputs());
      final near = insights.where((i) => i.title.contains('Mendekati'));
      expect(near, isNotEmpty);
      expect(near.first.body, contains('Makan & Minum'));
    });

    test('savings rate di atas target -> good', () {
      // (10jt - 3jt) / 10jt = 70% > target 20%
      final insights = InsightEngine.analyze(_inputs());
      final s = insights.where((i) => i.title.contains('on track'));
      expect(s, isNotEmpty);
      expect(s.first.severity, InsightSeverity.good);
    });

    test('tanpa pemasukan -> insight info, bukan crash', () {
      final noIncome = InsightInputs(
        incomeThisMonth: 0,
        expenseThisMonth: 1000000,
        spentByCategoryThisMonth: const {},
        categoryNames: const {},
        last3MonthsByCategory: const {},
        dayOfMonth: 10,
        daysInMonth: 30,
        budgetLimits: const {},
      );
      final insights = InsightEngine.analyze(noIncome);
      expect(
          insights.any((i) => i.title.contains('Belum ada pemasukan')), isTrue);
    });
  });

  group('buildKuncungSummary', () {
    test('ringkasan memuat semua bagian penting', () {
      final summary = InsightEngine.buildKuncungSummary(
        appName: 'Saku',
        monthLabel: 'Oktober 2026',
        healthScore: 75,
        income: 10000000,
        expense: 3000000,
        spentByCategory: const {'cat_makan': 2000000},
        categoryNames: const {'cat_makan': 'Makan & Minum'},
        budgetLimits: const {'cat_makan': 2500000},
        insights: const [
          Insight(title: 'Halo', body: 'dunia', severity: InsightSeverity.info)
        ],
      );
      expect(summary, contains('Oktober 2026'));
      expect(summary, contains('75/100'));
      expect(summary, contains('Rp10.000.000'));
      expect(summary, contains('Makan & Minum'));
      expect(summary, contains('Halo: dunia'));
      expect(summary, contains('Kuncung'));
    });
  });
}
