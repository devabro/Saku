import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/money.dart';
import '../models/wallet.dart';
import '../state/providers.dart';
import 'widgets/glass.dart';
import 'widgets/masked_amount.dart';

/// Dialog tambah/ubah dompet. Top-level agar bisa dipakai ulang.
Future<void> showWalletEditor(
    BuildContext context, WidgetRef ref, Wallet? existing) async {
  final name = TextEditingController(text: existing?.name ?? '');
  final balance =
      TextEditingController(text: existing != null ? '${existing.balance}' : '');
  var type = existing?.type ?? WalletType.bank;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        title: Text(existing == null ? 'Dompet baru' : 'Ubah dompet'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Nama')),
            const SizedBox(height: 8),
            DropdownButtonFormField<WalletType>(
              initialValue: type,
              decoration: const InputDecoration(labelText: 'Jenis'),
              items: WalletType.values
                  .map((t) =>
                      DropdownMenuItem(value: t, child: Text(t.label)))
                  .toList(),
              onChanged: (v) => setS(() => type = v ?? WalletType.bank),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: balance,
              decoration: const InputDecoration(
                  labelText: 'Saldo (Rp)', prefixText: 'Rp '),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Simpan')),
        ],
      ),
    ),
  );
  if (ok == true && name.text.trim().isNotEmpty) {
    final wallet = existing?.copyWith(
          name: name.text.trim(),
          type: type,
          balance: parseIdrInput(balance.text),
        ) ??
        Wallet(
          id: newId(),
          name: name.text.trim(),
          type: type,
          balance: parseIdrInput(balance.text),
        );
    await ref.read(repositoryProvider).saveWallet(wallet);
  }
}

/// Kelola dompet: tambah/ubah/hapus.
/// FAB "Transfer" disediakan HomeScreen (context-aware).
class WalletsScreen extends ConsumerWidget {
  const WalletsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallets = ref.watch(walletsProvider);
    return wallets.when(
      data: (list) {
        final assets =
            list.where((w) => !w.isDebt).fold(0, (a, w) => a + w.balance);
        final debts =
            list.where((w) => w.isDebt).fold(0, (a, w) => a + w.balance);
        return ListView(
          children: [
            GlassCard(
              child: ListTile(
                title: const Text('Ringkasan'),
                subtitle: Text(
                    'Aset ${formatIdrShort(assets)} • Utang ${formatIdrShort(debts)}'),
                trailing: MaskedAmount(assets - debts,
                    style: Theme.of(context).textTheme.titleLarge),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: OutlinedButton.icon(
                onPressed: () async {
                  await showWalletEditor(context, ref, null);
                  invalidateAll(ref);
                },
                icon: const Icon(Icons.add),
                label: const Text('Tambah dompet'),
              ),
            ),
            for (final w in list) _walletTile(context, ref, w),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Gagal: $e')),
    );
  }

  Widget _walletTile(BuildContext context, WidgetRef ref, Wallet w) {
    return GlassCard(
      child: ListTile(
        leading: Icon(_icon(w.type),
            color: w.isDebt ? Colors.red : Colors.green),
        title: Text(w.name),
        subtitle: Text(w.isDebt ? '${w.type.label} • utang' : w.type.label),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            MaskedAmount(w.balance,
                style: Theme.of(context).textTheme.titleMedium),
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'edit') {
                  await showWalletEditor(context, ref, w);
                  invalidateAll(ref);
                } else if (v == 'delete') {
                  _deleteWallet(context, ref, w);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Ubah')),
                PopupMenuItem(value: 'delete', child: Text('Hapus')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _icon(WalletType t) {
    switch (t) {
      case WalletType.bank:
        return Icons.account_balance;
      case WalletType.ewallet:
        return Icons.smartphone;
      case WalletType.kartuKredit:
        return Icons.credit_card;
      case WalletType.paylater:
        return Icons.schedule;
      case WalletType.tunai:
        return Icons.payments;
    }
  }

  Future<void> _deleteWallet(
      BuildContext context, WidgetRef ref, Wallet w) async {
    // Cegah hapus dompet yang masih dipakai transaksi.
    final used =
        await ref.read(repositoryProvider).isWalletUsed(w.id);
    if (!context.mounted) return;
    if (used) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Tidak bisa dihapus'),
          content: Text(
              '"${w.name}" masih dipakai transaksi. Hapus atau pindahkan dulu transaksinya.'),
          actions: [
            FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Mengerti')),
          ],
        ),
      );
      return;
    }
    final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Hapus dompet?'),
            content: Text('"${w.name}" akan dihapus permanen.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Batal')),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Hapus')),
            ],
          ),
        ) ??
        false;
    if (ok) {
      await ref.read(repositoryProvider).deleteWallet(w.id);
      invalidateAll(ref);
    }
  }
}
