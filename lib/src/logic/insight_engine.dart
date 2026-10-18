import '../config/app_config.dart';
import 'money.dart';

/// Insight lokal — "AI advisor" versi gratis: murni komputasi dari data
/// pengguna, tanpa API, tanpa network. 100% unit-testable.
enum InsightSeverity { info, warning, danger, good }

class Insight {
  final String title;
  final String body;
  final InsightSeverity severity;

  const Insight({required this.title, required this.body, required this.severity});
}

class InsightInputs {
  final int incomeThisMonth;
  final int expenseThisMonth;
  final Map<String, int> spentByCategoryThisMonth;
  final Map<String, String> categoryNames;
  final Map<String, List<int>> last3MonthsByCategory;
  final int dayOfMonth;
  final int daysInMonth;
  final Map<String, int> budgetLimits;
  final double savingsTarget;

  const InsightInputs({
    required this.incomeThisMonth,
    required this.expenseThisMonth,
    required this.spentByCategoryThisMonth,
    required this.categoryNames,
    required this.last3MonthsByCategory,
    required this.dayOfMonth,
    required this.daysInMonth,
    required this.budgetLimits,
    this.savingsTarget = AppConfig.defaultSavingsTarget,
  });
}

class InsightEngine {
  InsightEngine._();

  static List<Insight> analyze(InsightInputs i) {
    final out = <Insight>[];
    out.addAll(_burnRate(i));
    out.addAll(_anomalies(i));
    out.addAll(_budgetWarnings(i));
    out.add(_savingsRate(i));
    return out;
  }

  // --- 1. Burn rate: kecepatan belanja harian + proyeksi akhir bulan ---
  static List<Insight> _burnRate(InsightInputs i) {
    if (i.dayOfMonth <= 0 || i.expenseThisMonth <= 0) return [];
    final rate = i.expenseThisMonth / i.dayOfMonth;
    final projected = (rate * i.daysInMonth).round();
    final remaining = i.daysInMonth - i.dayOfMonth;
    if (remaining <= 0) return [];
    return [
      Insight(
        title: 'Proyeksi akhir bulan',
        body: 'Dengan kecepatan belanja ${formatIdr(rate.round())}/hari, '
            'bulan ini diproyeksi habis ${formatIdr(projected)}. '
            'Sisa $remaining hari.',
        severity: InsightSeverity.info,
      ),
    ];
  }

  // --- 2. Anomali: kategori > 2× rata-rata 3 bulan terakhir ---
  static List<Insight> _anomalies(InsightInputs i) {
    final out = <Insight>[];
    for (final e in i.spentByCategoryThisMonth.entries) {
      final history = i.last3MonthsByCategory[e.key] ?? [];
      if (history.isEmpty) continue;
      final avg = history.reduce((a, b) => a + b) / history.length;
      if (avg <= 0) {
        // Tidak ada histori tapi bulan ini ada belanja = pola baru.
        if (e.value > 0 && history.every((v) => v == 0)) {
          final name = i.categoryNames[e.key] ?? 'Kategori';
          out.add(Insight(
            title: 'Pola baru: $name',
            body: 'Tiga bulan terakhir nol, bulan ini ${formatIdr(e.value)}. '
                'Cek apakah ini kebutuhan sekali waktu.',
            severity: InsightSeverity.info,
          ));
        }
        continue;
      }
      if (e.value > 2 * avg) {
        final name = i.categoryNames[e.key] ?? 'Kategori';
        out.add(Insight(
          title: 'Lonjakan di $name',
          body: '${formatIdr(e.value)} bulan ini vs rata-rata '
              '${formatIdr(avg.round())}/bulan (3 bulan terakhir). '
              'Lebih dari 2× lipat — ada yang berubah?',
          severity: InsightSeverity.warning,
        ));
      }
    }
    return out;
  }

  // --- 3. Peringatan budget 80% / 100% ---
  static List<Insight> _budgetWarnings(InsightInputs i) {
    final over = <String>[];
    final near = <String>[];
    for (final e in i.budgetLimits.entries) {
      if (e.value <= 0) continue;
      final spent = i.spentByCategoryThisMonth[e.key] ?? 0;
      final ratio = spent / e.value;
      final name = i.categoryNames[e.key] ?? 'Kategori';
      if (ratio >= 1) {
        over.add('$name (${formatIdr(spent)} / ${formatIdr(e.value)})');
      } else if (ratio >= 0.8) {
        near.add('$name (${(ratio * 100).round()}%)');
      }
    }
    final out = <Insight>[];
    if (over.isNotEmpty) {
      out.add(Insight(
        title: 'Budget jebol',
        body: over.join(', '),
        severity: InsightSeverity.danger,
      ));
    }
    if (near.isNotEmpty) {
      out.add(Insight(
        title: 'Mendekati batas',
        body: near.join(', '),
        severity: InsightSeverity.warning,
      ));
    }
    return out;
  }

  // --- 4. Savings rate vs target ---
  static Insight _savingsRate(InsightInputs i) {
    if (i.incomeThisMonth <= 0) {
      return const Insight(
        title: 'Belum ada pemasukan tercatat',
        body: 'Catat pemasukan bulan ini biar savings rate bisa dihitung.',
        severity: InsightSeverity.info,
      );
    }
    final rate = (i.incomeThisMonth - i.expenseThisMonth) / i.incomeThisMonth;
    final pct = (rate * 100).round();
    final target = (i.savingsTarget * 100).round();
    if (rate >= i.savingsTarget) {
      return Insight(
        title: 'Nabung on track 🎯',
        body: 'Savings rate $pct% — di atas target $target%. Pertahankan!',
        severity: InsightSeverity.good,
      );
    }
    return Insight(
      title: 'Savings rate $pct%',
      body: 'Di bawah target $target%. Selisihnya sekitar '
          '${formatIdr(((i.savingsTarget - rate) * i.incomeThisMonth).round())} '
          'yang perlu dihemat.',
      severity: rate < 0 ? InsightSeverity.danger : InsightSeverity.warning,
    );
  }

  /// Ringkasan teks untuk tombol "Tanya Kuncung": user salin/bagikan
  /// ke Kuncung (atau siapa pun) untuk dapat saran personal.
  static String buildKuncungSummary({
    required String appName,
    required String monthLabel,
    required int healthScore,
    required int income,
    required int expense,
    required Map<String, int> spentByCategory,
    required Map<String, String> categoryNames,
    required Map<String, int> budgetLimits,
    required List<Insight> insights,
  }) {
    final b = StringBuffer();
    b.writeln('Ringkasan keuangan $monthLabel (dari $appName)');
    b.writeln('Health score: $healthScore/100');
    b.writeln('Pemasukan: ${formatIdr(income)}');
    b.writeln('Pengeluaran: ${formatIdr(expense)}');
    b.writeln('Sisa: ${formatIdr(income - expense)}');
    b.writeln();
    b.writeln('Per kategori:');
    final sorted = spentByCategory.entries.toList()
      ..sort((a, b2) => b2.value.compareTo(a.value));
    for (final e in sorted) {
      final name = categoryNames[e.key] ?? e.key;
      final limit = budgetLimits[e.key];
      final lim = limit == null ? '' : ' / budget ${formatIdr(limit)}';
      b.writeln('- $name: ${formatIdr(e.value)}$lim');
    }
    if (insights.isNotEmpty) {
      b.writeln();
      b.writeln('Insight:');
      for (final ins in insights) {
        b.writeln('- ${ins.title}: ${ins.body}');
      }
    }
    b.writeln();
    b.writeln(
        'Tolong kasih saran, Kuncung, biar keuanganku lebih rapi bulan depan.');
    return b.toString();
  }
}
