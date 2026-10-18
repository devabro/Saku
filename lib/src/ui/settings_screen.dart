import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../logic/money.dart';
import '../services/biometric_service.dart';
import '../services/export_service.dart';
import '../services/notification_service.dart';
import '../state/providers.dart';
import 'categories_screen.dart';
import 'recurrings_screen.dart';

/// Pengaturan: privasi, biometrik, tema, notifikasi, kategori,
/// transaksi rutin, export, tentang.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final privacy = ref.watch(privacyModeProvider);
    final dark = ref.watch(themeModeProvider);
    final bioLock = ref.watch(biometricLockProvider);
    final nBudget = ref.watch(notifBudgetProvider);
    final nUpcoming = ref.watch(notifUpcomingProvider);
    final nDebt = ref.watch(notifDebtProvider);
    final nDaily = ref.watch(notifDailyProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListView(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.visibility_off),
            title: const Text('Mode privasi'),
            subtitle:
                const Text('Sembunyikan semua nominal saldo di layar'),
            value: privacy,
            onChanged: (_) =>
                ref.read(privacyModeProvider.notifier).toggle(),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.fingerprint),
            title: const Text('Kunci biometrik'),
            subtitle: const Text(
                'Minta sidik jari / PIN perangkat saat buka aplikasi'),
            value: bioLock,
            onChanged: (_) => _toggleBiometric(context, ref),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode),
            title: const Text('Mode gelap'),
            subtitle: const Text('Default: gelap'),
            value: dark,
            onChanged: (_) =>
                ref.read(themeModeProvider.notifier).toggle(),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text('Notifikasi',
                style: Theme.of(context).textTheme.titleSmall),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.warning_amber_outlined),
            title: const Text('Peringatan budget'),
            subtitle:
                const Text('Saat budget 80% dan 100% terpakai'),
            value: nBudget,
            onChanged: (_) =>
                ref.read(notifBudgetProvider.notifier).toggle(),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.schedule_outlined),
            title: const Text('Jadwal terjadwal'),
            subtitle: const Text(
                'Transaksi terjadwal jatuh tempo hari ini/besok'),
            value: nUpcoming,
            onChanged: (_) =>
                ref.read(notifUpcomingProvider.notifier).toggle(),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.handshake_outlined),
            title: const Text('Jatuh tempo utang'),
            subtitle:
                const Text('Utang/piutang ≤3 hari lagi atau terlewat'),
            value: nDebt,
            onChanged: (_) =>
                ref.read(notifDebtProvider.notifier).toggle(),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.alarm_outlined),
            title: const Text('Pengingat harian'),
            subtitle:
                const Text('Notifikasi jam 8 pagi untuk cek keuangan'),
            value: nDaily,
            onChanged: (_) =>
                ref.read(notifDailyProvider.notifier).toggle(),
          ),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Tes notifikasi'),
            subtitle:
                const Text('Cek aturan sekarang (budget, jadwal, utang)'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _testNotifications(context, ref),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.category_outlined),
            title: const Text('Kategori'),
            subtitle:
                const Text('Tambah, ubah, nonaktifkan kategori'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => const CategoriesScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.repeat),
            title: const Text('Transaksi rutin'),
            subtitle: const Text('Langganan, cicilan, gaji otomatis'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const RecurringsScreen()),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('Export CSV'),
            subtitle: const Text('Semua transaksi → file CSV'),
            onTap: () => _exportCsv(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('Export JSON'),
            subtitle: const Text('Daftar dompet → file JSON'),
            onTap: () => _exportJson(context, ref),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Tentang'),
            onTap: () => showAboutDialog(
              context: context,
              applicationName: AppConfig.appName,
              applicationVersion: AppConfig.version,
              children: const [
                Text(
                    'Aplikasi budgeting pribadi, local-first.\nSemua data tersimpan di perangkat ini. Tanpa iklan, tanpa analytics, tanpa kirim data ke mana pun.'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '${AppConfig.appName} ${AppConfig.version}\n${AppConfig.tagline}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleBiometric(
      BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(biometricLockProvider.notifier);
    if (ref.read(biometricLockProvider)) {
      await notifier.set(false);
      return;
    }
    final can = await BiometricService.instance.canAuthenticate;
    if (!context.mounted) return;
    if (!can) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Perangkat tidak mendukung kunci biometrik/PIN.')),
      );
      return;
    }
    final ok = await BiometricService.instance.authenticate();
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    if (ok) {
      await notifier.set(true);
      messenger.showSnackBar(
        const SnackBar(content: Text('Kunci biometrik aktif.')),
      );
    } else {
      messenger.showSnackBar(
        const SnackBar(content: Text('Autentikasi gagal.')),
      );
    }
  }

  Future<void> _testNotifications(
      BuildContext context, WidgetRef ref) async {
    final n = await NotificationService.instance.checkAndNotify(
        ref.read(repositoryProvider), DateTime.now());
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(n == 0
                ? 'Tidak ada notifikasi yang jatuh tempo.'
                : '$n notifikasi ditampilkan.')),
      );
    }
  }

  Future<void> _exportCsv(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(repositoryProvider);
    final txs = await repo.getTransactions();
    final wallets = await repo.getWallets();
    final cats = await repo.getCategories();
    final csv = ExportService.transactionsToCsv(
      txs,
      {for (final w in wallets) w.id: w.name},
      {for (final c in cats) c.id: c.name},
    );
    await ExportService.shareTextFile(
        '${AppConfig.appName.toLowerCase()}-transaksi-${monthKey(DateTime.now())}.csv',
        csv);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${txs.length} transaksi diekspor.')),
      );
    }
  }

  Future<void> _exportJson(BuildContext context, WidgetRef ref) async {
    final wallets = await ref.read(repositoryProvider).getWallets();
    await ExportService.shareTextFile(
        '${AppConfig.appName.toLowerCase()}-dompet.json',
        ExportService.walletsToJson(wallets));
  }
}
