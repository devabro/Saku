import '../logic/health_score.dart';
import '../logic/insight_engine.dart';
import '../models/budget.dart';
import '../models/category.dart';
import '../models/debt.dart';
import '../models/goal.dart';
import '../models/recurring.dart';
import '../models/transaction.dart';
import '../models/upcoming.dart';
import '../models/wallet.dart';

/// Abstraksi penyimpanan. Fase 1: [LocalRepository] (sqflite).
/// Fase 2: [SyncRepository] menambahkan sinkronisasi antar-device
/// tanpa mengubah satu pun pemanggil kode ini.
abstract class Repository {
  // --- Dompet ---
  Future<List<Wallet>> getWallets();
  Future<void> saveWallet(Wallet wallet);
  Future<void> deleteWallet(String id);

  /// true jika ada transaksi yang memakai dompet [id].
  Future<bool> isWalletUsed(String id);

  // --- Kategori ---
  Future<List<Category>> getCategories({CategoryKind? kind});
  Future<void> saveCategory(Category category);

  /// Hapus kategori custom. Kategori bawaan (id diawali 'cat_'/'inc_')
  /// tidak bisa dihapus — nonaktifkan saja via [saveCategory].
  Future<void> deleteCategory(String id);

  /// true jika ada transaksi yang memakai kategori [id].
  Future<bool> isCategoryUsed(String id);

  // --- Budget ---
  Future<List<Budget>> getBudgets(String month);
  Future<void> saveBudget(Budget budget);

  /// Semua budget (semua periode) — untuk layar budget baru.
  Future<List<Budget>> getAllBudgets();

  Future<void> deleteBudget(String id);

  /// Buat budget bulan [month] dari metode onboarding jika belum ada.
  /// Dipanggil otomatis saat dashboard dibuka (menangani ganti bulan).
  Future<void> ensureBudgetsForMonth(String month);

  // --- Transaksi ---
  Future<List<SakuTransaction>> getTransactions({DateTime? from, DateTime? to});
  Future<List<SakuTransaction>> getTransactionsForMonth(String month);

  /// Simpan transaksi + update saldo dompet terkait.
  /// Transfer menggerakkan saldo dua dompet tapi TIDAK dihitung
  /// sebagai pemasukan/pengeluaran (anti double-count).
  Future<void> saveTransaction(SakuTransaction tx);

  /// Hapus transaksi + kembalikan (reverse) efek ke saldo dompet.
  Future<void> deleteTransaction(String id);

  // --- Target ---
  Future<List<Goal>> getGoals();
  Future<void> saveGoal(Goal goal);
  Future<void> deleteGoal(String id);

  // --- Rutin (recurring) ---
  Future<List<Recurring>> getRecurrings();
  Future<void> saveRecurring(Recurring recurring);
  Future<void> deleteRecurring(String id);

  /// Generate transaksi untuk semua recurring yang jatuh tempo s/d [now].
  /// Mengembalikan jumlah transaksi yang dibuat.
  Future<int> generateDueRecurrings(DateTime now);

  /// Lewati jadwal berikutnya tanpa membuat transaksi.
  Future<void> skipRecurring(String id);

  // --- Utang-piutang ---
  Future<List<Debt>> getDebts();
  Future<void> saveDebt(Debt debt);
  Future<void> deleteDebt(String id);

  /// Buat utang baru + gerakkan saldo dompet:
  /// utang = uang masuk ke dompet, piutang = uang keluar dari dompet.
  Future<void> createDebt(Debt debt);

  /// Bayar/terima cicilan [amount] via [walletId]:
  /// tambah paidAmount + gerakkan saldo dompet berlawanan arah saat buat.
  /// Mengembalikan false jika amount tidak valid.
  Future<bool> payDebt(String debtId, int amount, String walletId);

  // --- Terjadwal (upcoming) ---
  Future<List<UpcomingTx>> getUpcoming();
  Future<void> saveUpcoming(UpcomingTx item);
  Future<void> deleteUpcoming(String id);

  /// Tandai sudah dibayar: jadi transaksi beneran (saldo bergerak)
  /// + hapus dari daftar terjadwal.
  Future<void> markUpcomingPaid(String id);

  // --- Memori judul ---
  /// Ingat pasangan judul->kategori (dipanggil tiap simpan transaksi).
  Future<void> rememberTitle(String title, String categoryId);

  /// Semua pasangan judul->kategori untuk auto-suggest.
  Future<Map<String, String>> getTitleMemory();

  // --- Meta (key-value) ---
  Future<String?> getMeta(String key);
  Future<void> setMeta(String key, String value);

  // --- Agregat ---
  /// Net worth = total aset − total utang (kartu kredit & paylater).
  Future<int> netWorth();

  /// Input mentah untuk [HealthScore] — komputasi tetap pure di logic/.
  Future<HealthInputs> healthInputs(String month);

  /// Input mentah untuk [InsightEngine].
  Future<InsightInputs> insightInputs(String month, DateTime now);
}
