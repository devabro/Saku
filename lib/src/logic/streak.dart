/// Streak harian: berapa hari beruntun pengguna mencatat transaksi.
///
/// Aturan (gaya Duolingo, tapi jujur):
/// - 1 hari dihitung kalau ada ≥1 transaksi non-transfer di hari itu.
/// - Streak dihitung mundur dari hari ini; kalau hari ini belum catat,
///   streak diambil dari kemarin (masih hidup, belum putus).
/// - Hari tanpa catatan memutus rantai.
///
/// Murni Dart — gampang di-unit-test.
class Streak {
  Streak._();

  /// [dates]: tanggal transaksi (jam diabaikan). [today]: acuan "hari ini".
  static int calc(List<DateTime> dates, DateTime today) {
    if (dates.isEmpty) return 0;
    final days = <DateTime>{
      for (final d in dates) DateTime(d.year, d.month, d.day),
    };
    var cursor = DateTime(today.year, today.month, today.day);
    // Belum catat hari ini? Streak masih dihitung dari kemarin.
    if (!days.contains(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
      if (!days.contains(cursor)) return 0;
    }
    var streak = 0;
    while (days.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  /// Copywriting penyemangat berbahasa Indonesia natural.
  static String message(int streak) {
    if (streak <= 0) return 'Yuk mulai streak-mu hari ini!';
    if (streak == 1) return 'Hari pertama! Besok lanjut lagi ya.';
    if (streak < 7) return 'Lanjut! Jangan sampai putus.';
    if (streak < 30) return 'Seminggu lebih konsisten. Keren!';
    if (streak < 100) return 'Sebulan penuh disiplin. Salut!';
    return 'Legenda pencatatan. $streak hari!';
  }
}
