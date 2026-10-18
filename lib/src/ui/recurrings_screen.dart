import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/money.dart';
import '../models/category.dart';
import '../models/recurring.dart';
import '../state/providers.dart';

/// Kelola transaksi rutin: langganan, cicilan, gaji.
/// Item yang jatuh tempo otomatis dibuatkan transaksi saat aplikasi dibuka
/// (lihat SplashScreen); di sini bisa dilewati (skip) atau dinonaktifkan.
class RecurringsScreen extends ConsumerWidget {
  const RecurringsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(recurringsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Transaksi rutin')),
      body: list.when(
        data: (rs) => rs.isEmpty
            ? const Center(
                child: Text(
                    'Belum ada.\nContoh: langganan Netflix, cicilan motor, gaji bulanan.',
                    textAlign: TextAlign.center))
            : ListView.builder(
                itemCount: rs.length,
                itemBuilder: (ctx, i) => _tile(context, ref, rs[i]),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Gagal: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _editRecurring(context, ref, null),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _tile(BuildContext context, WidgetRef ref, Recurring r) {
    return Card(
      child: ListTile(
        leading: Icon(
          r.type == 'income' ? Icons.arrow_downward : Icons.arrow_upward,
          color: r.type == 'income' ? Colors.green : Colors.red,
        ),
        title: Text(r.name,
            style: TextStyle(
                color: r.active ? null : Colors.grey,
                decoration:
                    r.active ? null : TextDecoration.lineThrough)),
        subtitle: Text(
            '${formatIdrShort(r.amount)} • ${r.frequency.label} • berikutnya ${r.nextDue.day}/${r.nextDue.month}/${r.nextDue.year}'),
        trailing: PopupMenuButton<String>(
          onSelected: (v) async {
            final repo = ref.read(repositoryProvider);
            if (v == 'skip') {
              await repo.skipRecurring(r.id);
            } else if (v == 'toggle') {
              await repo.saveRecurring(r.copyWith(active: !r.active));
            } else if (v == 'delete') {
              await repo.deleteRecurring(r.id);
            }
            invalidateAll(ref);
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
                value: 'skip', child: Text('Lewati jadwal ini')),
            PopupMenuItem(
                value: 'toggle',
                child: Text(r.active ? 'Nonaktifkan' : 'Aktifkan')),
            const PopupMenuItem(value: 'delete', child: Text('Hapus')),
          ],
        ),
      ),
    );
  }

  Future<void> _editRecurring(
      BuildContext context, WidgetRef ref, Recurring? existing) async {
    final name = TextEditingController(text: existing?.name ?? '');
    final amount = TextEditingController(
        text: existing != null ? '${existing.amount}' : '');
    var type = existing?.type ?? 'expense';
    var frequency = existing?.frequency ?? RecurringFrequency.bulanan;
    String? categoryId = existing?.categoryId;
    String? walletId = existing?.walletId;

    final cats = await ref.read(repositoryProvider).getCategories();
    final wallets = await ref.read(repositoryProvider).getWallets();
    categoryId ??= cats.isNotEmpty ? cats.first.id : null;
    walletId ??= wallets.isNotEmpty ? wallets.first.id : null;

    if (!context.mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Transaksi rutin'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: name,
                    decoration: const InputDecoration(
                        labelText: 'Nama (mis. Netflix)')),
                const SizedBox(height: 8),
                TextField(
                  controller: amount,
                  decoration: const InputDecoration(
                      labelText: 'Nominal (Rp)', prefixText: 'Rp '),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'Jenis'),
                  items: const [
                    DropdownMenuItem(
                        value: 'expense', child: Text('Pengeluaran')),
                    DropdownMenuItem(
                        value: 'income', child: Text('Pemasukan')),
                  ],
                  onChanged: (v) => setS(() => type = v ?? 'expense'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<RecurringFrequency>(
                  initialValue: frequency,
                  decoration:
                      const InputDecoration(labelText: 'Frekuensi'),
                  items: RecurringFrequency.values
                      .map((f) =>
                          DropdownMenuItem(value: f, child: Text(f.label)))
                      .toList(),
                  onChanged: (v) =>
                      setS(() => frequency = v ?? RecurringFrequency.bulanan),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: categoryId,
                  decoration:
                      const InputDecoration(labelText: 'Kategori'),
                  items: cats
                      .where((c) =>
                          (type == 'expense'
                              ? c.kind == CategoryKind.expense
                              : c.kind == CategoryKind.income) &&
                          c.enabled)
                      .map((c) => DropdownMenuItem(
                          value: c.id, child: Text(c.name)))
                      .toList(),
                  onChanged: (v) => setS(() => categoryId = v),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: walletId,
                  decoration: const InputDecoration(labelText: 'Dompet'),
                  items: wallets
                      .map((w) => DropdownMenuItem(
                          value: w.id, child: Text(w.name)))
                      .toList(),
                  onChanged: (v) => setS(() => walletId = v),
                ),
              ],
            ),
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
    if (ok == true &&
        name.text.trim().isNotEmpty &&
        categoryId != null &&
        walletId != null) {
      final repo = ref.read(repositoryProvider);
      // Jadwal pertama: 1 periode dari sekarang.
      final first = Recurring(
        id: newId(),
        name: '',
        type: type,
        amount: 0,
        categoryId: categoryId!,
        walletId: walletId!,
        frequency: frequency,
        nextDue: DateTime.now(),
      ).advance(DateTime.now());
      await repo.saveRecurring(Recurring(
        id: existing?.id ?? newId(),
        name: name.text.trim(),
        type: type,
        amount: parseIdrInput(amount.text),
        categoryId: categoryId!,
        walletId: walletId!,
        frequency: frequency,
        nextDue: existing?.nextDue ?? first,
        active: existing?.active ?? true,
      ));
      invalidateAll(ref);
    }
  }
}
