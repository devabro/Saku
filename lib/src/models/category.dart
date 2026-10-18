import 'package:flutter/material.dart';

enum CategoryKind { expense, income }

/// Kategori transaksi.
///
/// Catatan Flutter 3.47+: konstruktor `IconData` menuntut `codePoint`
/// berupa konstanta compile-time (`@mustBeConst`), jadi ikon tidak bisa
/// dibangun dari integer runtime. Solusinya: [iconKey] berupa string yang
/// dipetakan ke `IconData` konstanta lewat [_icons]. Satu-satunya sumber
/// kebenaran daftar ikon ada di map ini.
class Category {
  final String id;
  final String name;
  final String iconKey;
  final int colorValue;
  final CategoryKind kind;
  final bool enabled;

  const Category({
    required this.id,
    required this.name,
    required this.iconKey,
    required this.colorValue,
    this.kind = CategoryKind.expense,
    this.enabled = true,
  });

  static const Map<String, IconData> _icons = {
    'restaurant': Icons.restaurant,
    'directions_car': Icons.directions_car,
    'shopping_bag': Icons.shopping_bag,
    'receipt_long': Icons.receipt_long,
    'medical_services': Icons.medical_services,
    'movie': Icons.movie,
    'school': Icons.school,
    'savings': Icons.savings,
    'more_horiz': Icons.more_horiz,
    'work': Icons.work,
    'card_giftcard': Icons.card_giftcard,
    'add_circle': Icons.add_circle,
  };

  IconData get icon => _icons[iconKey] ?? Icons.category_outlined;

  Color get color => Color(colorValue);

  Category copyWith({bool? enabled, String? name}) => Category(
        id: id,
        name: name ?? this.name,
        iconKey: iconKey,
        colorValue: colorValue,
        kind: kind,
        enabled: enabled ?? this.enabled,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'icon': iconKey,
        'color': colorValue,
        'kind': kind.name,
        'enabled': enabled ? 1 : 0,
      };

  factory Category.fromMap(Map<String, Object?> m) => Category(
        id: m['id']! as String,
        name: m['name']! as String,
        iconKey: m['icon']! as String,
        colorValue: (m['color']! as num).toInt(),
        kind: CategoryKind.values.byName(m['kind']! as String),
        enabled: (m['enabled']! as num).toInt() == 1,
      );
}
