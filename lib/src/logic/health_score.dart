/// Financial Health Score 0–100.
///
/// FORMULA (bobot bisa di-tune via konstanta di bawah):
///
///   skor = 40% × kepatuhan budget
///        + 25% × savings rate
///        + 20% × stabilitas pengeluaran
///        + 15% × progres target nabung
///
/// - Kepatuhan budget: rata-rata per kategori `1 − overspend/limit`
///   (kategori tanpa budget diabaikan; jika tidak ada budget sama sekali
///   komponen ini netral 0.5 agar tidak menghukum user baru).
/// - Savings rate: `(pemasukan − pengeluaran) / pemasukan`, dijepit 0–1.
///   Pemasukan 0 → 0 (tidak bisa menilai).
/// - Stabilitas: `1 − koefisien variasi` dari pengeluaran 4 bulan
///   terakhir (bulan ini + 3 bulan lalu). Belanja yang stabil = skor tinggi.
///   Data < 2 bulan → netral 0.5.
/// - Progres target: rata-rata progres semua goal aktif (0–1).
///   Tidak punya goal → netral 0.5 (fitur opsional, jangan menghukum).
///
/// Semua komponen murni fungsi matematika — mudah di-unit-test.
class HealthInputs {
  final Map<String, int> budgetLimits; // categoryId -> limit
  final Map<String, int> spentByCategory; // categoryId -> terpakai
  final int incomeThisMonth;
  final int expenseThisMonth;
  final List<int> monthlyExpenses; // [bulanIni, m-1, m-2, m-3]
  final List<double> goalProgress; // 0..1 per goal

  const HealthInputs({
    required this.budgetLimits,
    required this.spentByCategory,
    required this.incomeThisMonth,
    required this.expenseThisMonth,
    required this.monthlyExpenses,
    required this.goalProgress,
  });
}

class HealthResult {
  final int score; // 0–100
  final double budgetAdherence;
  final double savingsRate;
  final double stability;
  final double goalProgress;

  const HealthResult({
    required this.score,
    required this.budgetAdherence,
    required this.savingsRate,
    required this.stability,
    required this.goalProgress,
  });
}

class HealthScore {
  HealthScore._();

  // --- Bobot (tunable) ---
  static const double wBudget = 0.40;
  static const double wSavings = 0.25;
  static const double wStability = 0.20;
  static const double wGoals = 0.15;

  static HealthResult compute(HealthInputs i) {
    final adherence = _budgetAdherence(i);
    final savings = _savingsRate(i);
    final stability = _stability(i);
    final goals = _goalProgress(i);
    final score = (wBudget * adherence +
            wSavings * savings +
            wStability * stability +
            wGoals * goals) *
        100;
    return HealthResult(
      score: score.round().clamp(0, 100),
      budgetAdherence: adherence,
      savingsRate: savings,
      stability: stability,
      goalProgress: goals,
    );
  }

  static double _budgetAdherence(HealthInputs i) {
    final scored = <double>[];
    for (final e in i.budgetLimits.entries) {
      if (e.value <= 0) continue;
      final spent = i.spentByCategory[e.key] ?? 0;
      final overspend = (spent - e.value).clamp(0, 1 << 62);
      scored.add((1 - overspend / e.value).clamp(0.0, 1.0));
    }
    if (scored.isEmpty) return 0.5; // belum ada budget: netral
    return scored.reduce((a, b) => a + b) / scored.length;
  }

  static double _savingsRate(HealthInputs i) {
    if (i.incomeThisMonth <= 0) return 0;
    return ((i.incomeThisMonth - i.expenseThisMonth) / i.incomeThisMonth)
        .clamp(0.0, 1.0);
  }

  static double _stability(HealthInputs i) {
    final data = i.monthlyExpenses.where((e) => e >= 0).toList();
    if (data.length < 2) return 0.5;
    final mean = data.reduce((a, b) => a + b) / data.length;
    if (mean == 0) return 1.0;
    var variance = 0.0;
    for (final v in data) {
      variance += (v - mean) * (v - mean);
    }
    variance /= data.length;
    final cv = _sqrt(variance) / mean; // koefisien variasi
    return (1 - cv).clamp(0.0, 1.0);
  }

  static double _goalProgress(HealthInputs i) {
    if (i.goalProgress.isEmpty) return 0.5; // opsional: netral
    final avg =
        i.goalProgress.reduce((a, b) => a + b) / i.goalProgress.length;
    return avg.clamp(0.0, 1.0);
  }

  static double _sqrt(double v) {
    if (v <= 0) return 0;
    var x = v;
    for (var k = 0; k < 20; k++) {
      x = 0.5 * (x + v / x);
    }
    return x;
  }

  /// Label kualitatif untuk UI.
  static String grade(int score) {
    if (score >= 80) return 'Sehat banget';
    if (score >= 60) return 'Sehat';
    if (score >= 40) return 'Perlu perhatian';
    return 'Kritis';
  }
}
