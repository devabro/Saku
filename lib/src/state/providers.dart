import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_database.dart';
import '../data/local_repository.dart';
import '../data/repository.dart';
import '../logic/health_score.dart';
import '../logic/insight_engine.dart';
import '../logic/money.dart';
import '../models/budget.dart';
import '../models/category.dart';
import '../models/goal.dart';
import '../models/recurring.dart';
import '../models/transaction.dart';
import '../models/wallet.dart';
import '../services/ocr_service.dart';

// ============ Fondasi ============

final databaseProvider = Provider<AppDatabase>((ref) => AppDatabase.instance);

final repositoryProvider = Provider<Repository>(
  (ref) => LocalRepository(ref.watch(databaseProvider)),
);

/// OCR fase 1 = stub lokal. Fase 2: ganti ke ServerTesseractOcrService.
final ocrServiceProvider = Provider<OcrService>((ref) => LocalStubOcrService());

/// Bulan aktif global dalam format 'yyyy-MM'.
final activeMonthProvider = StateProvider<String>((ref) => monthKey(DateTime.now()));

// ============ Preferensi (persist di tabel meta) ============

class _MetaBoolController extends StateNotifier<bool> {
  _MetaBoolController(this._repo, this._key) : super(false);
  final Repository _repo;
  final String _key;

  Future<void> load() async {
    state = (await _repo.getMeta(_key)) == '1';
  }

  Future<void> set(bool v) async {
    state = v;
    await _repo.setMeta(_key, v ? '1' : '0');
  }

  Future<void> toggle() => set(!state);
}

final privacyModeProvider =
    StateNotifierProvider<_MetaBoolController, bool>((ref) {
  return _MetaBoolController(ref.watch(repositoryProvider), 'privacy_mode');
});

/// true = dark mode, false = light mode. Default: gelap.
class ThemeModeController extends StateNotifier<bool> {
  ThemeModeController(this._repo) : super(true);
  final Repository _repo;

  Future<void> load() async {
    final v = await _repo.getMeta('dark_mode');
    if (v != null) state = v == '1';
  }

  Future<void> set(bool v) async {
    state = v;
    await _repo.setMeta('dark_mode', v ? '1' : '0');
  }

  Future<void> toggle() => set(!state);
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeController, bool>((ref) {
  return ThemeModeController(ref.watch(repositoryProvider));
});

final onboardingDoneProvider = FutureProvider<bool>((ref) async {
  final repo = ref.watch(repositoryProvider);
  return (await repo.getMeta('onboarding_done')) == '1';
});

// ============ Data ============

final walletsProvider = FutureProvider<List<Wallet>>((ref) {
  return ref.watch(repositoryProvider).getWallets();
});

final categoriesProvider = FutureProvider<List<Category>>((ref) {
  return ref.watch(repositoryProvider).getCategories();
});

final transactionsProvider =
    FutureProvider.family<List<SakuTransaction>, String>((ref, month) {
  return ref.watch(repositoryProvider).getTransactionsForMonth(month);
});

final budgetsProvider = FutureProvider.family<List<Budget>, String>((ref, month) async {
  final repo = ref.watch(repositoryProvider);
  await repo.ensureBudgetsForMonth(month);
  return repo.getBudgets(month);
});

final goalsProvider = FutureProvider<List<Goal>>((ref) {
  return ref.watch(repositoryProvider).getGoals();
});

final recurringsProvider = FutureProvider<List<Recurring>>((ref) {
  return ref.watch(repositoryProvider).getRecurrings();
});

final netWorthProvider = FutureProvider<int>((ref) {
  return ref.watch(repositoryProvider).netWorth();
});

final healthProvider = FutureProvider.family<HealthResult, String>((ref, month) async {
  final inputs = await ref.watch(repositoryProvider).healthInputs(month);
  return HealthScore.compute(inputs);
});

final insightsProvider =
    FutureProvider.family<List<Insight>, String>((ref, month) async {
  final repo = ref.watch(repositoryProvider);
  final inputs = await repo.insightInputs(month, DateTime.now());
  return InsightEngine.analyze(inputs);
});

/// Invalidate semua provider data setelah mutasi. Panggil ini dari UI
/// setiap kali simpan/hapus transaksi, dompet, budget, goal, recurring.
void invalidateAll(WidgetRef ref) {
  ref.invalidate(walletsProvider);
  ref.invalidate(categoriesProvider);
  ref.invalidate(transactionsProvider);
  ref.invalidate(budgetsProvider);
  ref.invalidate(goalsProvider);
  ref.invalidate(recurringsProvider);
  ref.invalidate(netWorthProvider);
  ref.invalidate(healthProvider);
  ref.invalidate(insightsProvider);
}
