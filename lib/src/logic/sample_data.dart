import 'dart:math';

import '../models/category.dart';
import '../models/transaction.dart';
import '../models/wallet.dart';
import 'money.dart';

/// Penanda transaksi data contoh. Dipakai "Hapus data contoh"
/// untuk mengenali & menghapus hanya transaksi dummy.
const sampleDataMarker = 'sample_data';

/// Generator data contoh: ~2 bulan transaksi dummy yang realistis
/// untuk perempuan Indonesia (gaji, kos, jajan, kopi, skincare...).
///
/// Murni Dart & deterministik lewat [seed] — gampang di-unit-test.
/// Tidak menyentuh DB; orkestrasi simpan/hapus ada di
/// `SampleDataService`.
class SampleData {
  SampleData._();

  /// Bangun daftar transaksi contoh.
  ///
  /// [wallets] dan [categories] diambil dari data pengguna saat ini
  /// (hasil onboarding). [now] = acuan "hari ini".
  static List<SakuTransaction> generate({
    required List<Wallet> wallets,
    required List<Category> categories,
    required DateTime now,
    int seed = 7,
  }) {
    if (wallets.isEmpty || categories.isEmpty) return [];
    final rnd = Random(seed);
    final out = <SakuTransaction>[];

    String cat(String id, CategoryKind kind) {
      final hit = categories.where((c) => c.id == id && c.enabled);
      if (hit.isNotEmpty) return hit.first.id;
      final fb =
          categories.where((c) => c.kind == kind && c.enabled);
      if (fb.isNotEmpty) return fb.first.id;
      return categories.first.id;
    }

    Wallet pickWallet({bool preferCash = false}) {
      if (preferCash) {
        final cash =
            wallets.where((w) => w.type == WalletType.tunai);
        if (cash.isNotEmpty) return cash.first;
      }
      return wallets[rnd.nextInt(wallets.length)];
    }

    void add({
      required DateTime date,
      required TransactionType type,
      required int amount,
      String? categoryId,
      Wallet? wallet,
      Wallet? toWallet,
      required String note,
    }) {
      final w = wallet ?? pickWallet();
      out.add(SakuTransaction(
        id: 'sample_${newId()}',
        type: type,
        amount: amount,
        categoryId: categoryId,
        walletId: w.id,
        toWalletId: toWallet?.id,
        note: note,
        date: date,
        recurringId: sampleDataMarker,
      ));
    }

    int jitter(int base, int spread) =>
        base + rnd.nextInt(spread * 2 + 1) - spread;

    final today = DateTime(now.year, now.month, now.day);
    final start = today.subtract(const Duration(days: 60));

    final bankWallet = wallets
        .where((w) => w.type == WalletType.bank)
        .cast<Wallet?>()
        .followedBy([null])
        .first ??
        wallets.first;
    final cashWallet = wallets
        .where((w) => w.type == WalletType.tunai)
        .cast<Wallet?>()
        .followedBy([null])
        .first;

    // ---- Pemasukan rutin: gaji tiap tanggal 25 ----
    for (var m = 0; m < 3; m++) {
      final d = DateTime(today.year, today.month - m, 25);
      if (d.isAfter(today) || d.isBefore(start)) continue;
      add(
        date: d,
        type: TransactionType.income,
        amount: 8500000,
        categoryId: cat('inc_gaji', CategoryKind.income),
        wallet: bankWallet,
        note: 'Gaji bulanan',
      );
    }
    // Bonus freelance sekali
    final bonusDay = today.subtract(const Duration(days: 20));
    if (!bonusDay.isBefore(start)) {
      add(
        date: bonusDay,
        type: TransactionType.income,
        amount: 1500000,
        categoryId: cat('inc_lainnya', CategoryKind.income),
        wallet: bankWallet,
        note: 'Freelance desain',
      );
    }

    // ---- Tagihan rutin ----
    for (var m = 0; m < 2; m++) {
      final kos = DateTime(today.year, today.month - m, 5);
      if (!kos.isAfter(today) && !kos.isBefore(start)) {
        add(
          date: kos,
          type: TransactionType.expense,
          amount: 1200000,
          categoryId: cat('cat_tagihan', CategoryKind.expense),
          wallet: bankWallet,
          note: 'Kos bulanan',
        );
      }
      final listrik = DateTime(today.year, today.month - m, 10);
      if (!listrik.isAfter(today) && !listrik.isBefore(start)) {
        add(
          date: listrik,
          type: TransactionType.expense,
          amount: 200000,
          categoryId: cat('cat_tagihan', CategoryKind.expense),
          note: 'Token listrik',
        );
      }
    }
    // Langganan
    final netflix = today.subtract(const Duration(days: 12));
    if (!netflix.isBefore(start)) {
      add(
        date: netflix,
        type: TransactionType.expense,
        amount: 65000,
        categoryId: cat('cat_hiburan', CategoryKind.expense),
        note: 'Netflix',
      );
    }

    // ---- Harian: iterate 60 hari ke belakang ----
    const wartegNotes = [
      'Warteg deket kos',
      'Nasi padang',
      'Ayam geprek',
      'Soto ayam',
      'Mie ayam gerobak',
    ];
    const kopiNotes = ['Kopi susu tetangga', 'Es kopi', 'Matcha latte'];
    for (var i = 0; i < 60; i++) {
      final d = today.subtract(Duration(days: i));
      if (d.isBefore(start)) break;
      final wd = d.weekday; // 1=Senin..7=Minggu
      final isWeekend = wd >= 6;

      // Makan siang warteg (hari kerja)
      if (!isWeekend && rnd.nextDouble() < 0.75) {
        add(
          date: d,
          type: TransactionType.expense,
          amount: jitter(20000, 5000),
          categoryId: cat('cat_makan', CategoryKind.expense),
          wallet: cashWallet,
          note: wartegNotes[rnd.nextInt(wartegNotes.length)],
        );
      }
      // Kopi
      if (rnd.nextDouble() < (isWeekend ? 0.35 : 0.25)) {
        add(
          date: d,
          type: TransactionType.expense,
          amount: jitter(22000, 6000),
          categoryId: cat('cat_makan', CategoryKind.expense),
          wallet: cashWallet,
          note: kopiNotes[rnd.nextInt(kopiNotes.length)],
        );
      }
      // GoFood (malam minggu / mager)
      if (rnd.nextDouble() < (isWeekend ? 0.3 : 0.12)) {
        add(
          date: d,
          type: TransactionType.expense,
          amount: jitter(45000, 15000),
          categoryId: cat('cat_makan', CategoryKind.expense),
          note: 'GoFood',
        );
      }
      // Parkir
      if (!isWeekend && rnd.nextDouble() < 0.5) {
        add(
          date: d,
          type: TransactionType.expense,
          amount: jitter(8000, 3000),
          categoryId: cat('cat_transport', CategoryKind.expense),
          wallet: cashWallet,
          note: 'Parkir motor',
        );
      }
      // Bensin ~ tiap 10 hari
      if (i % 10 == 4) {
        add(
          date: d,
          type: TransactionType.expense,
          amount: 50000,
          categoryId: cat('cat_transport', CategoryKind.expense),
          wallet: cashWallet,
          note: 'Bensin',
        );
      }
      // Ojol sesekali
      if (rnd.nextDouble() < 0.12) {
        add(
          date: d,
          type: TransactionType.expense,
          amount: jitter(20000, 8000),
          categoryId: cat('cat_transport', CategoryKind.expense),
          note: 'Ojek online',
        );
      }
      // Belanja bulanan ~ tiap 10 hari
      if (i % 10 == 7) {
        add(
          date: d,
          type: TransactionType.expense,
          amount: jitter(150000, 50000),
          categoryId: cat('cat_belanja', CategoryKind.expense),
          note: 'Belanja bulanan',
        );
      }
      // Skincare ~ tiap 20 hari
      if (i % 20 == 9) {
        add(
          date: d,
          type: TransactionType.expense,
          amount: jitter(185000, 40000),
          categoryId: cat('cat_belanja', CategoryKind.expense),
          note: 'Skincare',
        );
      }
      // Nongkrong weekend
      if (isWeekend && rnd.nextDouble() < 0.4) {
        add(
          date: d,
          type: TransactionType.expense,
          amount: jitter(75000, 25000),
          categoryId: cat('cat_hiburan', CategoryKind.expense),
          note: 'Nongkrong sama temen',
        );
      }
    }

    // ---- Nabung: transfer tiap gajian ----
    final tabungan = wallets
        .where((w) =>
            w.name.toLowerCase().contains('tabung') ||
            w.type == WalletType.ewallet)
        .cast<Wallet?>()
        .followedBy([null])
        .first;
    for (var m = 0; m < 2; m++) {
      final d = DateTime(today.year, today.month - m, 26);
      if (d.isAfter(today) || d.isBefore(start)) continue;
      add(
        date: d,
        type: TransactionType.transfer,
        amount: 500000,
        wallet: bankWallet,
        toWallet: tabungan ?? bankWallet,
        note: 'Nabung rutin',
      );
    }

    out.sort((a, b) => b.date.compareTo(a.date));
    return out;
  }
}
