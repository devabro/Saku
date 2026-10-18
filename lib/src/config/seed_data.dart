import '../models/category.dart';

/// Kategori bawaan berbahasa Indonesia. Di-seed saat onboarding selesai.
/// Pengguna bisa menonaktifkan yang tidak dipakai (belum bisa tambah
/// custom di fase 1 — lihat README fase 2).
///
/// [iconKey] harus ada di map `Category._icons`.
class SeedData {
  SeedData._();

  static List<Category> expenseCategories() => [
        _cat('cat_makan', 'Makan & Minum', 'restaurant', 0xFFFF7043),
        _cat('cat_transport', 'Transportasi', 'directions_car', 0xFF42A5F5),
        _cat('cat_belanja', 'Belanja', 'shopping_bag', 0xFFAB47BC),
        _cat('cat_tagihan', 'Tagihan & Utilitas', 'receipt_long', 0xFFFFCA28),
        _cat('cat_kesehatan', 'Kesehatan', 'medical_services', 0xFF26A69A),
        _cat('cat_hiburan', 'Hiburan', 'movie', 0xFFEC407A),
        _cat('cat_pendidikan', 'Pendidikan', 'school', 0xFF5C6BC0),
        _cat('cat_tabungan', 'Tabungan & Investasi', 'savings', 0xFF66BB6A),
        _cat('cat_lainnya', 'Lainnya', 'more_horiz', 0xFF78909C),
      ];

  static List<Category> incomeCategories() => [
        _cat('inc_gaji', 'Gaji', 'work', 0xFF66BB6A,
            kind: CategoryKind.income),
        _cat('inc_bonus', 'Bonus & THR', 'card_giftcard', 0xFF42A5F5,
            kind: CategoryKind.income),
        _cat('inc_lainnya', 'Pemasukan Lainnya', 'add_circle', 0xFF78909C,
            kind: CategoryKind.income),
      ];

  static Category _cat(String id, String name, String iconKey, int color,
      {CategoryKind kind = CategoryKind.expense}) {
    return Category(
      id: id,
      name: name,
      iconKey: iconKey,
      colorValue: color,
      kind: kind,
    );
  }
}
