import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../data/repository.dart';
import '../logic/budget_periods.dart';
import '../logic/notification_rules.dart';

/// Wrapper flutter_local_notifications. Semua aturan "kapan notif muncul"
/// murni di [NotificationRules] (unit-testable); kelas ini hanya
/// inisialisasi + tampil + jadwal harian.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      // Fallback: UTC bila nama zona tidak dikenali.
    }
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: android),
    );
    // Android 13+: minta izin notifikasi saat pertama kali.
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    _ready = true;
  }

  Future<void> show(DueNotification n) async {
    await init();
    await _plugin.show(
      n.id.hashCode,
      n.title,
      n.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'saku_reminders',
          'Pengingat Saku',
          importance: Importance.defaultImportance,
        ),
      ),
    );
  }

  /// Jadwalkan pengingat harian jam 8 pagi: buka aplikasi -> cek aturan.
  /// (Tanpa receiver boot — jadwal hilang setelah reboot sampai app dibuka.)
  Future<void> scheduleDailyCheck() async {
    await init();
    final now = tz.TZDateTime.now(tz.local);
    var at = tz.TZDateTime(tz.local, now.year, now.month, now.day, 8);
    if (at.isBefore(now)) at = at.add(const Duration(days: 1));
    await _plugin.zonedSchedule(
      9001,
      'Cek keuangan harian',
      'Buka Saku untuk cek budget, jadwal, dan utang hari ini.',
      at,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'saku_daily',
          'Pengingat harian Saku',
          importance: Importance.defaultImportance,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelDailyCheck() async {
    await _plugin.cancel(9001);
  }

  /// Jalankan semua aturan notifikasi yang aktif. Dipanggil saat aplikasi
  /// dibuka (splash). Mengembalikan jumlah notifikasi yang ditampilkan.
  Future<int> checkAndNotify(Repository repo, DateTime now) async {
    final enabled = await repo.getMeta('notif_enabled') != '0';
    if (!enabled) return 0;
    var shown = 0;

    if (await repo.getMeta('notif_budget') != '0') {
      shown += await _checkBudgets(repo, now);
    }
    if (await repo.getMeta('notif_upcoming') != '0') {
      shown += await _checkUpcoming(repo, now);
    }
    if (await repo.getMeta('notif_debt') != '0') {
      shown += await _checkDebts(repo, now);
    }

    // Jadwalkan (atau perbarui) pengingat harian.
    if (await repo.getMeta('notif_daily') != '0') {
      await scheduleDailyCheck();
    } else {
      await cancelDailyCheck();
    }
    return shown;
  }

  Future<int> _checkBudgets(Repository repo, DateTime now) async {
    final budgets = await repo.getAllBudgets();
    if (budgets.isEmpty) return 0;
    // Ambil transaksi secukupnya: rentang terluas dari semua budget.
    var minStart = now;
    var maxEnd = now;
    for (final b in budgets) {
      final r = b.range;
      if (r.start.isBefore(minStart)) minStart = r.start;
      if (r.end.isAfter(maxEnd)) maxEnd = r.end;
    }
    final txs = await repo.getTransactions(from: minStart, to: maxEnd);
    final cats = await repo.getCategories();
    final names = {for (final c in cats) c.id: c.name};
    final doneRaw = await repo.getMeta('notif_budget_done') ?? '';
    final done = doneRaw.split(',').where((s) => s.isNotEmpty).toSet();

    final alerts = NotificationRules.budgetAlerts(
      budgets,
      (b) {
        final r = b.range;
        final m =
            BudgetPeriods.spentByCategory(txs, r.start, r.end);
        return m[b.categoryId] ?? 0;
      },
      names,
      done,
    );
    for (final a in alerts) {
      await show(a);
      done.add(a.id);
    }
    await repo.setMeta('notif_budget_done', done.join(','));
    return alerts.length;
  }

  Future<int> _checkUpcoming(Repository repo, DateTime now) async {
    final items = await repo.getUpcoming();
    final wallets = await repo.getWallets();
    final wnames = {for (final w in wallets) w.id: w.name};
    final alerts = NotificationRules.upcomingAlerts(items, now, wnames);
    for (final a in alerts) {
      await show(a);
    }
    return alerts.length;
  }

  Future<int> _checkDebts(Repository repo, DateTime now) async {
    final debts = await repo.getDebts();
    final alerts = NotificationRules.debtAlerts(debts, now);
    // Anti-spam: satu id hanya sekali per hari.
    final dayKey = '${now.year}-${now.month}-${now.day}';
    final seenRaw = await repo.getMeta('notif_debt_seen') ?? '';
    final seen = seenRaw.split('|').where((s) => s.isNotEmpty).toSet();
    var n = 0;
    for (final a in alerts) {
      final key = '$dayKey:${a.id}';
      if (seen.contains(key)) continue;
      await show(a);
      seen.add(key);
      n++;
    }
    await repo.setMeta('notif_debt_seen', seen.join('|'));
    return n;
  }
}
