import '../models/debt.dart';

/// Status utang dari total vs sudah dibayar. Murni Dart — unit-testable.
enum DebtStatus {
  unpaid('Belum dibayar'),
  partial('Sebagian'),
  paid('Lunas');

  const DebtStatus(this.label);
  final String label;
}

DebtStatus debtStatus(int totalAmount, int paidAmount) {
  if (paidAmount <= 0) return DebtStatus.unpaid;
  if (paidAmount >= totalAmount) return DebtStatus.paid;
  return DebtStatus.partial;
}

/// Sisa yang harus dibayar. Tidak pernah negatif.
int debtRemaining(int totalAmount, int paidAmount) =>
    (totalAmount - paidAmount).clamp(0, totalAmount);

/// Validasi pembayaran: harus > 0 dan tidak melebihi sisa.
bool isValidDebtPayment(int totalAmount, int paidAmount, int payment) =>
    payment > 0 && payment <= debtRemaining(totalAmount, paidAmount);

/// Urutkan utang untuk daftar: belum lunas dulu, lalu jatuh tempo terdekat.
List<Debt> sortDebts(List<Debt> debts) {
  final list = [...debts];
  list.sort((a, b) {
    final sa = debtStatus(a.totalAmount, a.paidAmount);
    final sb = debtStatus(b.totalAmount, b.paidAmount);
    if ((sa == DebtStatus.paid) != (sb == DebtStatus.paid)) {
      return sa == DebtStatus.paid ? 1 : -1;
    }
    final da = a.dueDate;
    final db = b.dueDate;
    if (da == null && db == null) return 0;
    if (da == null) return 1;
    if (db == null) return -1;
    return da.compareTo(db);
  });
  return list;
}

/// Apakah jatuh tempo sudah lewat (dan belum lunas)?
bool isDebtOverdue(Debt d, DateTime now) {
  final due = d.dueDate;
  if (due == null) return false;
  if (debtStatus(d.totalAmount, d.paidAmount) == DebtStatus.paid) {
    return false;
  }
  final today = DateTime(now.year, now.month, now.day);
  final dueDay = DateTime(due.year, due.month, due.day);
  return dueDay.isBefore(today);
}

/// Jatuh tempo dalam [withinDays] hari ke depan (termasuk hari ini)?
bool isDebtDueSoon(Debt d, DateTime now, {int withinDays = 3}) {
  final due = d.dueDate;
  if (due == null) return false;
  if (debtStatus(d.totalAmount, d.paidAmount) == DebtStatus.paid) {
    return false;
  }
  final today = DateTime(now.year, now.month, now.day);
  final dueDay = DateTime(due.year, due.month, due.day);
  final diff = dueDay.difference(today).inDays;
  return diff >= 0 && diff <= withinDays;
}
