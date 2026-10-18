import '../logic/money.dart';

/// Periode budget: mingguan, bulanan, atau rentang tanggal bebas.
enum BudgetPeriodType {
  weekly('Mingguan'),
  monthly('Bulanan'),
  custom('Rentang khusus');

  const BudgetPeriodType(this.label);
  final String label;
}

/// Budget per kategori per periode. [month] format 'yyyy-MM' — untuk
/// weekly/custom diisi dari bulan tanggal mulai (kunci kompatibilitas).
class Budget {
  final String id;
  final String categoryId;
  final String month;
  final int limit;
  final BudgetPeriodType periodType;
  final int? startMs;
  final int? endMs;

  const Budget({
    required this.id,
    required this.categoryId,
    required this.month,
    required this.limit,
    this.periodType = BudgetPeriodType.monthly,
    this.startMs,
    this.endMs,
  });

  /// Rentang tanggal efektif. Untuk monthly tanpa startMs/endMs
  /// (data lama), dihitung dari [month].
  ({DateTime start, DateTime end}) get range {
    if (startMs != null && endMs != null) {
      return (
        start: DateTime.fromMillisecondsSinceEpoch(startMs!),
        end: DateTime.fromMillisecondsSinceEpoch(endMs!),
      );
    }
    final s = monthStart(month);
    return (
      start: s,
      end: DateTime(s.year, s.month + 1).subtract(
          const Duration(milliseconds: 1)),
    );
  }

  String get periodLabel {
    final r = range;
    switch (periodType) {
      case BudgetPeriodType.weekly:
        return 'Minggu ${r.start.day}/${r.start.month}–${r.end.day}/${r.end.month}';
      case BudgetPeriodType.monthly:
        return monthLabel(month);
      case BudgetPeriodType.custom:
        return '${r.start.day}/${r.start.month} – ${r.end.day}/${r.end.month}/${r.end.year}';
    }
  }

  Budget copyWith({int? limit}) => Budget(
        id: id,
        categoryId: categoryId,
        month: month,
        limit: limit ?? this.limit,
        periodType: periodType,
        startMs: startMs,
        endMs: endMs,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'categoryId': categoryId,
        'month': month,
        'amountLimit': limit,
        'periodType': periodType.name,
        'startMs': startMs,
        'endMs': endMs,
      };

  factory Budget.fromMap(Map<String, Object?> m) => Budget(
        id: m['id']! as String,
        categoryId: m['categoryId']! as String,
        month: m['month']! as String,
        limit: (m['amountLimit']! as num).toInt(),
        periodType: BudgetPeriodType.values
            .byName((m['periodType'] as String?) ?? 'monthly'),
        startMs: (m['startMs'] as num?)?.toInt(),
        endMs: (m['endMs'] as num?)?.toInt(),
      );
}
