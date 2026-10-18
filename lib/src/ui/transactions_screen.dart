import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/money.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../state/providers.dart';
import 'quick_add_sheet.dart';

/// Daftar transaksi: filter bulan (ikut bulan aktif global), cari,
/// edit, hapus (geser).
class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() =>
      _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final month = ref.watch(activeMonthProvider);
    final txs = ref.watch(transactionsProvider(month));
    final categories = ref.watch(categoriesProvider);
    final wallets = ref.watch(walletsProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Cari transaksi...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _query = v.toLowerCase()),
          ),
        ),
        Expanded(
          child: txs.when(
            data: (list) => categories.when(
              data: (cats) => wallets.when(
                data: (ws) => _list(context, ref, list, cats, ws),
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Gagal: $e')),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Gagal: $e')),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Gagal: $e')),
          ),
        ),
      ],
    );
  }

  Widget _list(BuildContext context, WidgetRef ref, List<SakuTransaction> txs,
      List<Category> cats, List wallets) {
    final names = {for (final c in cats) c.id: c.name};
    final icons = {for (final c in cats) c.id: c.icon};
    final colors = {for (final c in cats) c.id: c.color};
    final wnames = {for (final w in wallets) w.id: w.name};

    final filtered = txs.where((t) {
      if (_query.isEmpty) return true;
      final inNote = t.note.toLowerCase().contains(_query);
      final inCat = (names[t.categoryId] ?? '').toLowerCase().contains(_query);
      return inNote || inCat;
    }).toList();

    if (filtered.isEmpty) {
      return const Center(
          child: Text('Belum ada transaksi.\nPencet "Catat" buat mulai.',
              textAlign: TextAlign.center));
    }

    // Kelompokkan per tanggal.
    final groups = <String, List<SakuTransaction>>{};
    for (final t in filtered) {
      final key =
          '${t.date.year}-${t.date.month.toString().padLeft(2, '0')}-${t.date.day.toString().padLeft(2, '0')}';
      groups.putIfAbsent(key, () => []).add(t);
    }

    return ListView(
      children: [
        for (final g in groups.entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(_dateLabel(g.key),
                style: Theme.of(context).textTheme.labelLarge),
          ),
          for (final t in g.value)
            Dismissible(
              key: ValueKey(t.id),
              direction: DismissDirection.endToStart,
              background: Container(
                color: Colors.red,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              confirmDismiss: (_) async {
                return await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Hapus transaksi?'),
                        content: const Text(
                            'Saldo dompet akan dikembalikan seperti semula.'),
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
              },
              onDismissed: (_) async {
                await ref.read(repositoryProvider).deleteTransaction(t.id);
                invalidateAll(ref);
              },
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      (colors[t.categoryId] ?? Colors.grey).withValues(alpha: 0.2),
                  child: Icon(
                    t.type == TransactionType.transfer
                        ? Icons.swap_horiz
                        : (icons[t.categoryId] ?? Icons.receipt),
                    color: colors[t.categoryId],
                  ),
                ),
                title: Text(t.note.isEmpty
                    ? (t.type == TransactionType.transfer
                        ? 'Transfer'
                        : (names[t.categoryId] ?? '-'))
                    : t.note),
                subtitle: Text(t.type == TransactionType.transfer
                    ? '${wnames[t.walletId] ?? ''} → ${wnames[t.toWalletId] ?? ''}'
                    : '${names[t.categoryId] ?? ''} • ${wnames[t.walletId] ?? ''}'),
                trailing: Text(
                  '${t.type == TransactionType.expense ? '−' : t.type == TransactionType.income ? '+' : '⇄ '}${formatIdr(t.amount)}',
                  style: TextStyle(
                    color: t.type == TransactionType.expense
                        ? Colors.red
                        : t.type == TransactionType.income
                            ? Colors.green
                            : null,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => QuickAddSheet(edit: t),
                  ).then((saved) {
                    if (saved == true) invalidateAll(ref);
                  });
                },
              ),
            ),
        ],
      ],
    );
  }

  String _dateLabel(String ymd) {
    final parts = ymd.split('-').map(int.parse).toList();
    final d = DateTime(parts[0], parts[1], parts[2]);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (d == today) return 'Hari ini';
    if (d == today.subtract(const Duration(days: 1))) return 'Kemarin';
    const days = [
      '', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'
    ];
    return '${days[d.weekday]}, ${d.day}/${d.month}/${d.year}';
  }
}
