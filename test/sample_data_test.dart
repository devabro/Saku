import 'package:flutter_test/flutter_test.dart';
import 'package:saku/src/config/seed_data.dart';
import 'package:saku/src/logic/sample_data.dart';
import 'package:saku/src/models/transaction.dart';
import 'package:saku/src/models/wallet.dart';

void main() {
  List<Wallet> wallets() => [
        Wallet(id: 'w_tunai', name: 'Tunai', type: WalletType.tunai),
        Wallet(id: 'w_bank', name: 'Bank', type: WalletType.bank),
      ];

  group('SampleData.generate', () {
    test('tanpa dompet = kosong', () {
      final txs = SampleData.generate(
        wallets: [],
        categories: SeedData.expenseCategories(),
        now: DateTime(2026, 10, 19),
      );
      expect(txs, isEmpty);
    });

    test('hasilkan ~2 bulan data realistis', () {
      final now = DateTime(2026, 10, 19);
      final txs = SampleData.generate(
        wallets: wallets(),
        categories: [
          ...SeedData.expenseCategories(),
          ...SeedData.incomeCategories()
        ],
        now: now,
      );
      // Cukup banyak buat dashboard kelihatan hidup.
      expect(txs.length, greaterThan(40));
      // Semua dalam 60 hari ke belakang.
      final oldest = now.subtract(const Duration(days: 61));
      for (final t in txs) {
        expect(t.date.isAfter(oldest), true,
            reason: 'transaksi ${t.id} terlalu lama');
        expect(t.date.isAfter(now.add(const Duration(days: 1))), false);
      }
    });

    test('semua bertanda sample_data & nominal positif', () {
      final txs = SampleData.generate(
        wallets: wallets(),
        categories: [
          ...SeedData.expenseCategories(),
          ...SeedData.incomeCategories()
        ],
        now: DateTime(2026, 10, 19),
      );
      for (final t in txs) {
        expect(t.recurringId, sampleDataMarker);
        expect(t.amount, greaterThan(0));
      }
      // Ada pemasukan (gaji) dan pengeluaran.
      expect(txs.any((t) => t.type == TransactionType.income), true);
      expect(txs.any((t) => t.type == TransactionType.expense), true);
    });

    test('deterministik: seed sama = hasil sama', () {
      final cats = [
        ...SeedData.expenseCategories(),
        ...SeedData.incomeCategories()
      ];
      final a = SampleData.generate(
          wallets: wallets(), categories: cats, now: DateTime(2026, 10, 19));
      final b = SampleData.generate(
          wallets: wallets(), categories: cats, now: DateTime(2026, 10, 19));
      expect(a.length, b.length);
      for (var i = 0; i < a.length; i++) {
        expect(a[i].amount, b[i].amount);
        expect(a[i].note, b[i].note);
      }
    });

    test('id unik (tidak tabrakan saat disimpan)', () {
      final txs = SampleData.generate(
        wallets: wallets(),
        categories: [
          ...SeedData.expenseCategories(),
          ...SeedData.incomeCategories()
        ],
        now: DateTime(2026, 10, 19),
      );
      final ids = txs.map((t) => t.id).toSet();
      expect(ids.length, txs.length);
    });

    test('ada gaji & kos (pola Indonesia)', () {
      final txs = SampleData.generate(
        wallets: wallets(),
        categories: [
          ...SeedData.expenseCategories(),
          ...SeedData.incomeCategories()
        ],
        now: DateTime(2026, 10, 19),
      );
      expect(txs.any((t) => t.note.contains('Gaji')), true);
      expect(txs.any((t) => t.note.contains('Kos')), true);
      expect(txs.any((t) => t.note.contains('Skincare')), true);
    });
  });
}
