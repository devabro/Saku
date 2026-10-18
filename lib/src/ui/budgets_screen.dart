import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/money.dart';
import '../models/budget.dart';
import '../models/transaction.dart';
import '../state/providers.dart';
import 'widgets/masked_amount.dart';

/// Budget per kategori: progress bar + peringatan 80% (kuning) & 100% (merah).
class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(activeMonthProvider);
    final budgets = ref.watch(budgetsProvider(month));
    final txs = ref.watch(transactionsProvider(month));
    final categories = ref.watch(categoriesProvider);

    return budgets.when(
      data: (bs) => txs.when(
        data: (txList) => categories.when(
          data: (cats) => _body(context, ref, month, bs, txList, cats),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Gagal: $e')),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Gagal: $e')),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Gagal: $e')),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref, String month,
      List<Budget> budgets, List<SakuTransaction> txs, List categories) {
    final spent = <String, int>{};
    for (final t in txs) {
      if (t.type == TransactionType.expense && t.categoryId != null) {
        spent[t.categoryId!] = (spent[t.categoryId!] ?? 0) + t.amount;
      }
    }
    final names = {for (final c in categories) c.id: c.name};
    final icons = {for (final c in categories) c.id: c.icon};
    final colors = {for (final c in categories) c.id: c.color};

    final over = budgets
        .where((b) => (spent[b.categoryId] ?? 0) >= b.limit && b.limit > 0)
        .toList();
    final near = budgets
        .where((b) =>
            (spent[b.categoryId] ?? 0) >= b.limit * 0.8 &&
            (spent[b.categoryId] ?? 0) < b.limit &&
            b.limit > 0)
        .toList();

    return ListView(
      children: [
        if (over.isNotEmpty)
          _banner(context, Colors.red,
              'Jebol: ${over.map((b) => names[b.categoryId] ?? '').join(', ')}'),
        if (near.isNotEmpty)
          _banner(context, Colors.orange,
              'Hampir habis: ${near.map((b) => names[b.categoryId] ?? '').join(', ')}'),
        if (budgets.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('Belum ada budget bulan ini.')),
          )
        else
          for (final b in budgets)
            _budgetTile(context, ref, b, spent[b.categoryId] ?? 0,
                names[b.categoryId] ?? b.categoryId,
                icons[b.categoryId], colors[b.categoryId]),
      ],
    );
  }

  Widget _banner(BuildContext context, Color color, String text) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  Widget _budgetTile(BuildContext context, WidgetRef ref, Budget b, int used,
      String name, IconData? icon, Color? color) {
    final ratio = b.limit <= 0 ? 0.0 : used / b.limit;
    final barColor = ratio >= 1
        ? Colors.red
        : ratio >= 0.8
            ? Colors.orange
            : Colors.green;
    return Card(
      child: ListTile(
        leading: Icon(icon ?? Icons.category, color: color),
        title: Text(name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0),
              color: barColor,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                MaskedAmount(used, short: true),
                Text(' / ${formatIdrShort(b.limit)}',
                    style: const TextStyle(fontSize: 13)),
                const Spacer(),
                Text('${(ratio * 100).round()}%',
                    style: TextStyle(
                        color: barColor, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.edit_outlined),
          tooltip: 'Ubah batas',
          onPressed: () => _editLimit(context, ref, b),
        ),
      ),
    );
  }

  Future<void> _editLimit(
      BuildContext context, WidgetRef ref, Budget b) async {
    final c = TextEditingController(text: '${b.limit}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ubah batas budget'),
        content: TextField(
          controller: c,
          decoration: const InputDecoration(
              labelText: 'Batas (Rp)', prefixText: 'Rp '),
          keyboardType: TextInputType.number,
          autofocus: true,
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
    );
    if (ok == true) {
      final limit = parseIdrInput(c.text);
      if (limit > 0) {
        await ref
            .read(repositoryProvider)
            .saveBudget(b.copyWith(limit: limit));
        invalidateAll(ref);
      }
    }
  }
}
