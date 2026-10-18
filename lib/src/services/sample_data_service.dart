import 'dart:convert';

import '../data/repository.dart';
import '../logic/money.dart';
import '../logic/sample_data.dart';
import '../models/wallet.dart';

/// Orkestrasi data contoh: pasang & hapus lewat [Repository].
///
/// - Transaksi dummy ditandai [sampleDataMarker] di `recurringId`.
/// - Kalau pengguna belum punya dompet, dibuatkan 2 dompet contoh;
///   id-nya disimpan di meta `sample_wallet_ids` agar bisa dibersihkan.
/// - Hapus = deleteTransaction satu per satu (saldo dompet otomatis
///   dikembalikan), lalu hapus dompet contoh bila ada.
class SampleDataService {
  SampleDataService._();

  static const metaActive = 'sample_data_active';
  static const metaWalletIds = 'sample_wallet_ids';

  /// Pasang data contoh. Mengembalikan jumlah transaksi dibuat.
  static Future<int> install(Repository repo) async {
    if ((await repo.getMeta(metaActive)) == '1') return 0;

    var wallets = await repo.getWallets();
    final categories = await repo.getCategories();

    final sampleWalletIds = <String>[];
    if (wallets.isEmpty) {
      final tunai = Wallet(
          id: newId(), name: 'Tunai', type: WalletType.tunai, balance: 500000);
      final bank = Wallet(
          id: newId(),
          name: 'Bank',
          type: WalletType.bank,
          balance: 10000000);
      await repo.saveWallet(tunai);
      await repo.saveWallet(bank);
      sampleWalletIds.addAll([tunai.id, bank.id]);
      wallets = [tunai, bank];
    }

    final txs = SampleData.generate(
      wallets: wallets,
      categories: categories,
      now: DateTime.now(),
    );
    for (final t in txs) {
      await repo.saveTransaction(t);
    }
    if (sampleWalletIds.isNotEmpty) {
      await repo.setMeta(metaWalletIds, jsonEncode(sampleWalletIds));
    }
    await repo.setMeta(metaActive, '1');
    return txs.length;
  }

  /// Hapus semua data contoh. Mengembalikan jumlah transaksi dihapus.
  static Future<int> clear(Repository repo) async {
    final txs = await repo.getTransactions();
    var n = 0;
    for (final t in txs) {
      if (t.recurringId == sampleDataMarker) {
        await repo.deleteTransaction(t.id);
        n++;
      }
    }
    final rawIds = await repo.getMeta(metaWalletIds);
    if (rawIds != null) {
      try {
        final ids = (jsonDecode(rawIds) as List).cast<String>();
        // Hanya hapus dompet contoh yang sudah tidak punya transaksi.
        final remaining = await repo.getTransactions();
        for (final id in ids) {
          final used = remaining.any(
              (t) => t.walletId == id || t.toWalletId == id);
          if (!used) await repo.deleteWallet(id);
        }
      } catch (_) {
        // Meta korup = abaikan, transaksi sudah bersih.
      }
      await repo.setMeta(metaWalletIds, '');
    }
    await repo.setMeta(metaActive, '0');
    return n;
  }

  static Future<bool> isActive(Repository repo) async =>
      (await repo.getMeta(metaActive)) == '1';
}
