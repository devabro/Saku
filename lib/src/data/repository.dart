import '../logic/health_score.dart';
import '../logic/insight_engine.dart';
import '../models/budget.dart';
import '../models/category.dart';
import '../models/goal.dart';
import '../models/recurring.dart';
import '../models/transaction.dart';
import '../models/wallet.dart';

/// Abstraksi penyimpanan. Fase 1: [LocalRepository] (sqflite).
/// Fase 2: [SyncRepository] menambahkan sinkronisasi antar-device
/// tanpa mengubah satu pun pemanggil kode ini.
abstract class Repository {
  // --- Dompet ---
  Future<List<Wallet>> getWallets();
  Future<void> saveWallet(Wallet wallet);
  Future<void> deleteWallet(String id);

  // --- Kategori ---
  Future<List<Category>> getCategories({CategoryKind? kind});
  Future<void> saveCategory(Category category);

  // --- Budget ---
  Future<List<Budget>> getBudgets(String month);
  Future<void> saveBudget(Budget budget);

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
