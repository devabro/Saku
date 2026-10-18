import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../logic/money.dart';
import '../services/export_service.dart';
import '../state/providers.dart';
import 'recurrings_screen.dart';

/// Pengaturan: privasi, tema, transaksi rutin, export, tentang.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final privacy = ref.watch(privacyModeProvider);
    final dark = ref.watch(themeModeProvider);
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
            secondary: const Icon(Icons.dark_mode),
            title: const Text('Mode gelap'),
            subtitle: const Text('Default: gelap'),
            value: dark,
            onChanged: (_) =>
                ref.read(themeModeProvider.notifier).toggle(),
          ),
          const Divider(),
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
