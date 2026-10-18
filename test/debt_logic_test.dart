import 'package:flutter_test/flutter_test.dart';
import 'package:saku/src/logic/debt_logic.dart';
import 'package:saku/src/models/debt.dart';

Debt _debt(String id,
        {int total = 1000000,
        int paid = 0,
        DateTime? due,
        DebtKind kind = DebtKind.utang}) =>
    Debt(
      id: id,
      personName: 'Orang $id',
      kind: kind,
      totalAmount: total,
      paidAmount: paid,
      dueDate: due,
      walletId: 'w1',
      createdAt: DateTime(2026, 10, 1),
    );

void main() {
  group('debtStatus', () {
    test('belum dibayar sama sekali = unpaid', () {
      expect(debtStatus(1000000, 0), DebtStatus.unpaid);
    });

    test('bayar sebagian = partial', () {
      expect(debtStatus(1000000, 400000), DebtStatus.partial);
    });

    test('bayar penuh = paid', () {
      expect(debtStatus(1000000, 1000000), DebtStatus.paid);
    });
  });

  group('debtRemaining', () {
    test('sisa = total - dibayar', () {
      expect(debtRemaining(1000000, 300000), 700000);
    });

    test('tidak pernah negatif (kelebihan bayar dijepit ke 0)', () {
      expect(debtRemaining(1000000, 1500000), 0);
    });
  });

  group('isValidDebtPayment', () {
    test('bayar valid dalam sisa', () {
      expect(isValidDebtPayment(1000000, 300000, 700000), isTrue);
    });

    test('bayar nol atau negatif ditolak', () {
      expect(isValidDebtPayment(1000000, 0, 0), isFalse);
      expect(isValidDebtPayment(1000000, 0, -500), isFalse);
    });

    test('bayar melebihi sisa ditolak', () {
      expect(isValidDebtPayment(1000000, 300000, 700001), isFalse);
    });

    test('bayar pas sisa diperbolehkan', () {
      expect(isValidDebtPayment(1000000, 300000, 700000), isTrue);
    });
  });

  group('sortDebts', () {
    test('belum lunas di atas, lunas di bawah; jatuh tempo terdekat dulu',
        () {
      final now = DateTime(2026, 10, 19);
      final list = [
        _debt('lunas', total: 500, paid: 500),
        _debt('jauh',
            due: DateTime(2026, 12, 1), paid: 100),
        _debt('dekat',
            due: DateTime(2026, 10, 20), paid: 100),
        _debt('tanpa-due', paid: 100),
      ];
      final sorted = sortDebts(list);
      expect(sorted.map((d) => d.id),
          ['dekat', 'jauh', 'tanpa-due', 'lunas']);
      expect(now.day, 19); // penanda: now tidak dipakai di sort
    });
  });

  group('isDebtOverdue / isDebtDueSoon', () {
    final now = DateTime(2026, 10, 19, 12);

    test('lewat jatuh tempo dan belum lunas = overdue', () {
      expect(
          isDebtOverdue(_debt('a', due: DateTime(2026, 10, 18)), now),
          isTrue);
    });

    test('jatuh tempo hari ini belum overdue', () {
      expect(
          isDebtOverdue(_debt('a', due: DateTime(2026, 10, 19)), now),
          isFalse);
    });

    test('lunas tidak overdue walau lewat tanggal', () {
      expect(
          isDebtOverdue(
              _debt('a',
                  due: DateTime(2026, 10, 1),
                  total: 100,
                  paid: 100),
              now),
          isFalse);
    });

    test('tanpa jatuh tempo tidak overdue', () {
      expect(isDebtOverdue(_debt('a'), now), isFalse);
    });

    test('due soon: 0..3 hari ke depan', () {
      expect(
          isDebtDueSoon(
              _debt('a', due: DateTime(2026, 10, 22)), now),
          isTrue);
      expect(
          isDebtDueSoon(
              _debt('a', due: DateTime(2026, 10, 23)), now),
          isFalse);
    });
  });
}
