/// Budget per kategori per bulan. [month] format 'yyyy-MM'.
class Budget {
  final String id;
  final String categoryId;
  final String month;
  final int limit;

  const Budget({
    required this.id,
    required this.categoryId,
    required this.month,
    required this.limit,
  });

  Budget copyWith({int? limit}) => Budget(
        id: id,
        categoryId: categoryId,
        month: month,
        limit: limit ?? this.limit,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'categoryId': categoryId,
        'month': month,
        'amountLimit': limit,
      };

  factory Budget.fromMap(Map<String, Object?> m) => Budget(
        id: m['id']! as String,
        categoryId: m['categoryId']! as String,
        month: m['month']! as String,
        limit: (m['amountLimit']! as num).toInt(),
      );
}
