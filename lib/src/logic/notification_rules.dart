import '../models/budget.dart';
import '../models/debt.dart';
import '../models/upcoming.dart';
import 'budget_periods.dart';
import 'debt_logic.dart';

/// Satu notifikasi yang "jatuh tempo" untuk ditampilkan.
/// Komputasi murni Dart — penjadwalan aktual ada di NotificationService.
class DueNotification {
  final String id;
  final String title;
  final String body;

  const DueNotification({
    required this.id,
    required this.title,
    required this.body,
  });
}

/// Aturan kapan notifikasi muncul. Dipanggil saat aplikasi dibuka
/// (dan dijadwalkan harian via NotificationService).
class NotificationRules {
  NotificationRules._();

  /// Budget yang melewati [threshold] (0.8 / 1.0). [spentFor] =
  /// total belanja dalam periode budget masing-masing.
  /// [alreadyNotifiedIds] = id budget yang sudah dinotifikasi di
  /// threshold ini (disimpan di meta) agar tidak spam tiap buka aplikasi.
  static List<DueNotification> budgetAlerts(
    List<Budget> budgets,
    int Function(Budget b) spentFor,
    Map<String, String> categoryNames,
    Set<String> alreadyNotifiedIds,
  ) {
    final out = <DueNotification>[];
    for (final b in budgets) {
      if (b.limit <= 0) continue;
      final spent = spentFor(b);
      final ratio = BudgetPeriods.ratio(spent, b.limit);
      final name = categoryNames[b.categoryId] ?? b.categoryId;
      if (ratio >= 1.0) {
        if (!alreadyNotifiedIds.contains('${b.id}@100')) {
          out.add(DueNotification(
            id: '${b.id}@100',
            title: 'Budget jebol: $name',
            body:
                'Pengeluaran $name sudah ${((ratio) * 100).round()}% dari batas (${b.periodLabel}).',
          ));
        }
      } else if (ratio >= 0.8) {
        if (!alreadyNotifiedIds.contains('${b.id}@80')) {
          out.add(DueNotification(
            id: '${b.id}@80',
            title: 'Budget hampir habis: $name',
            body:
                'Pengeluaran $name sudah ${(ratio * 100).round()}% dari batas (${b.periodLabel}).',
          ));
        }
      }
    }
    return out;
  }

  /// Upcoming yang jatuh tempo hari ini atau besok (dan remind=true).
  static List<DueNotification> upcomingAlerts(
    List<UpcomingTx> items,
    DateTime now,
    Map<String, String> walletNames,
  ) {
    final out = <DueNotification>[];
    final today = DateTime(now.year, now.month, now.day);
    for (final u in items) {
      if (!u.remind) continue;
      final due = DateTime(u.dueDate.year, u.dueDate.month, u.dueDate.day);
      final diff = due.difference(today).inDays;
      if (diff == 0 || diff == 1) {
        final when = diff == 0 ? 'hari ini' : 'besok';
        out.add(DueNotification(
          id: 'upcoming:${u.id}:$diff',
          title:
              'Jadwal ${u.type.name == 'income' ? 'pemasukan' : 'pengeluaran'} $when',
          body:
              '${u.note.isEmpty ? 'Tanpa catatan' : u.note} — jatuh tempo $when (${walletNames[u.walletId] ?? ''}).',
        ));
      }
    }
    return out;
  }

  /// Utang yang jatuh tempo ≤3 hari lagi atau sudah lewat.
  static List<DueNotification> debtAlerts(
    List<Debt> debts,
    DateTime now,
  ) {
    final out = <DueNotification>[];
    for (final d in debts) {
      if (isDebtOverdue(d, now)) {
        out.add(DueNotification(
          id: 'debt:overdue:${d.id}',
          title:
              '${d.kind.label} ke ${d.personName} lewat jatuh tempo',
          body: 'Sisa ${d.remaining} belum dilunasi.',
        ));
      } else if (isDebtDueSoon(d, now, withinDays: 3)) {
        final due = d.dueDate!;
        final today = DateTime(now.year, now.month, now.day);
        final diff =
            DateTime(due.year, due.month, due.day).difference(today).inDays;
        final when = diff == 0 ? 'hari ini' : '$diff hari lagi';
        out.add(DueNotification(
          id: 'debt:soon:${d.id}:$diff',
          title: '${d.kind.label} ke ${d.personName} jatuh tempo $when',
          body: 'Sisa ${d.remaining} — jangan lupa dilunasi.',
        ));
      }
    }
    return out;
  }
}
