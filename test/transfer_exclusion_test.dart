import 'package:flutter_test/flutter_test.dart';
import 'package:saku/src/logic/totals.dart';
import 'package:saku/src/models/transaction.dart';

SakuTransaction _tx(String id, TransactionType type, int amount,
        {String walletId = 'w1', String? toWalletId}) =>
    SakuTransaction(
      id: id,
      type: type,
      amount: amount,
      walletId: walletId,
      toWalletId: toWalletId,
      date: DateTime(2026, 10, 5),
    );

void main() {
  group('totalsExcludingTransfers — anti double-count', () {
    test('transfer antar dompet tidak dihitung pemasukan/pengeluaran', () {
      final txs = [
        _tx('1', TransactionType.income, 10000000),
        _tx('2', TransactionType.expense, 3000000, walletId: 'w1'),
        // Pindah uang sendiri: bank -> e-wallet. Bukan belanja.
        _tx('3', TransactionType.transfer, 2000000,
            walletId: 'w1', toWalletId: 'w2'),
        // Bayar tagihan kartu kredit. Juga bukan belanja baru.
        _tx('4', TransactionType.transfer, 500000,
            walletId: 'w1', toWalletId: 'w3'),
      ];
      final t = totalsExcludingTransfers(txs);
      expect(t.income, 10000000);
      expect(t.expense, 3000000);
      expect(t.net, 7000000);
      expect(t.savings, 7000000);
    });

    test('hanya berisi transfer -> total nol', () {
      final t = totalsExcludingTransfers([
        _tx('1', TransactionType.transfer, 1000000,
            walletId: 'w1', toWalletId: 'w2'),
      ]);
      expect(t.income, 0);
      expect(t.expense, 0);
      expect(t.net, 0);
    });

    test('daftar kosong -> total nol', () {
      final t = totalsExcludingTransfers([]);
      expect(t.income, 0);
      expect(t.expense, 0);
    });

    test('banyak transfer besar tidak menggelembungkan pengeluaran', () {
      // Simulasi salah catat: user mindahin 50jt antar dompet.
      final txs = [
        _tx('1', TransactionType.income, 10000000),
        _tx('2', TransactionType.transfer, 50000000,
            walletId: 'w1', toWalletId: 'w2'),
      ];
      final t = totalsExcludingTransfers(txs);
      expect(t.expense, 0,
          reason: 'transfer 50jt tidak boleh jadi pengeluaran');
      expect(t.savings, 10000000);
    });
  });
}
