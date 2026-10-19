import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repository.dart';
import '../logic/budget_periods.dart';
import '../logic/money.dart';
import '../models/budget.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../state/providers.dart';
import 'widgets/glass.dart';
import 'widgets/masked_amount.dart';

/// Budget per kategori per periode (mingguan/bulanan/rentang khusus).
/// Progress bar + peringatan 80% (kuning) & 100% (merah).
class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);
    final repo = ref.watch(repositoryProvider);
    // Di-watch agar invalidateAll() me-rebuild layar ini.
    ref.watch(allBudgetsProvider);

    return categories.when(
      data: (cats) => FutureBuilder<({List<Budget> budgets, List<SakuTransaction> txs})>(
        future: _load(repo),
        builder: (ctx, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final d = snap.data!;
          return _body(context, ref, d.budgets, d.txs, cats);
        },
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Gagal: $e')),
    );
  }

  /// Pastikan budget bulanan dari onboarding ada, lalu muat semua budget
  /// + transaksi dalam rentang gabungannya.
  Future<({List<Budget> budgets, List<SakuTransaction> txs})> _load(
      Repository repo) async {
    await repo.ensureBudgetsForMonth(monthKey(DateTime.now()));
    final budgets = await repo.getAllBudgets();
    final txs = await _txsFor(repo, budgets);
    return (budgets: budgets, txs: txs);
  }

  Future<List<SakuTransaction>> _txsFor(
      Repository repo, List<Budget> budgets) async {
    if (budgets.isEmpty) return [];
    var minStart = DateTime.now();
    var maxEnd = DateTime.now();
    for (final b in budgets) {
      final r = b.range;
      if (r.start.isBefore(minStart)) minStart = r.start;
      if (r.end.isAfter(maxEnd)) maxEnd = r.end;
    }
    return repo.getTransactions(from: minStart, to: maxEnd);
  }

  Widget _body(BuildContext context, WidgetRef ref, List<Budget> budgets,
      List<SakuTransaction> txs, List<Category> cats) {
    final names = {for (final c in cats) c.id: c.name};
    final icons = {for (final c in cats) c.id: c.icon};
    final colors = {for (final c in cats) c.id: c.color};

    int spentFor(Budget b) {
      final r = b.range;
      final m = BudgetPeriods.spentByCategory(txs, r.start, r.end);
      return m[b.categoryId] ?? 0;
    }

    final over = budgets
        .where((b) =>
            BudgetPeriods.ratio(spentFor(b), b.limit) >= 1 &&
            b.limit > 0)
        .toList();
    final near = budgets
        .where((b) {
          final r = BudgetPeriods.ratio(spentFor(b), b.limit);
          return r >= 0.8 && r < 1 && b.limit > 0;
        })
        .toList();

    // Urut: yang aktif dulu (rentang mencakup hari ini).
    final now = DateTime.now();
    final sorted = [...budgets];
    sorted.sort((a, b) {
      final ra = a.range;
      final rb = b.range;
      final aa = !now.isBefore(ra.start) && !now.isAfter(ra.end);
      final ab = !now.isBefore(rb.start) && !now.isAfter(rb.end);
      if (aa != ab) return aa ? -1 : 1;
      return (b.startMs ?? 0).compareTo(a.startMs ?? 0);
    });

    return ListView(
      children: [
        if (over.isNotEmpty)
          _banner(
              context,
              Colors.red,
              'Jebol: ${over.map((b) => names[b.categoryId] ?? '').join(', ')}'),
        if (near.isNotEmpty)
          _banner(context, Colors.orange,
              'Hampir habis: ${near.map((b) => names[b.categoryId] ?? '').join(', ')}'),
        if (budgets.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
                child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.pie_chart_outline_rounded,
                    size: 48,
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.6)),
                const SizedBox(height: 12),
                const Text(
                    'Belum ada budget.\nPencet tombol + Budget di bawah\nbuat mulai atur pengeluaran.',
                    textAlign: TextAlign.center),
              ],
            )),
          )
        else
          for (final b in sorted)
            _budgetTile(context, ref, b, spentFor(b),
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
    final ratio = BudgetPeriods.ratio(used, b.limit);
    final scheme = Theme.of(context).colorScheme;
    final ringColor = ratio >= 1
        ? scheme.error
        : ratio >= 0.8
            ? const Color(0xFFE8934A)
            : const Color(0xFF4C8C6B);
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Row(
          children: [
            // Ring progres melingkar.
            SizedBox(
              width: 76,
              height: 76,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 68,
                    height: 68,
                    child: CircularProgressIndicator(
                      value: ratio.clamp(0.0, 1.0),
                      strokeWidth: 9,
                      strokeCap: StrokeCap.round,
                      color: ringColor,
                      backgroundColor:
                          scheme.surfaceContainerHighest,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${(ratio * 100).round()}%',
                          style: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: ringColor)),
                      Icon(icon ?? Icons.category,
                          size: 18, color: color),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  Text(b.periodLabel,
                      style: Theme.of(context).textTheme.labelSmall),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      MaskedAmount(used, short: true,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                  fontWeight: FontWeight.w600)),
                      Text(' / ${formatIdrShort(b.limit)}',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    ratio >= 1
                        ? 'Jebol! Kurangi belanja di sini.'
                        : ratio >= 0.8
                            ? 'Hampir habis, hati-hati ya.'
                            : 'Masih aman.',
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: ringColor),
                  ),
                ],
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  tooltip: 'Ubah batas',
                  onPressed: () => _editLimit(context, ref, b),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.red, size: 20),
                  tooltip: 'Hapus budget',
                  onPressed: () async {
                    await ref
                        .read(repositoryProvider)
                        .deleteBudget(b.id);
                    invalidateAll(ref);
                  },
                ),
              ],
            ),
          ],
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

/// Dialog tambah budget dengan pilihan periode.
Future<void> showBudgetEditor(
    BuildContext context, WidgetRef ref, Budget? edit) async {
  final repo = ref.read(repositoryProvider);
  final cats = (await repo.getCategories(kind: CategoryKind.expense))
      .where((c) => c.enabled)
      .toList();
  if (!context.mounted || cats.isEmpty) return;

  var periodType = BudgetPeriodType.monthly;
  String categoryId = cats.first.id;
  final limit = TextEditingController();
  DateTime customStart = DateTime.now();
  DateTime customEnd = DateTime.now().add(const Duration(days: 7));

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        title: const Text('Budget baru'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<BudgetPeriodType>(
                segments: const [
                  ButtonSegment(
                      value: BudgetPeriodType.weekly,
                      label: Text('Mingguan')),
                  ButtonSegment(
                      value: BudgetPeriodType.monthly,
                      label: Text('Bulanan')),
                  ButtonSegment(
                      value: BudgetPeriodType.custom,
                      label: Text('Khusus')),
                ],
                selected: {periodType},
                onSelectionChanged: (s) =>
                    setS(() => periodType = s.first),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: categoryId,
                decoration:
                    const InputDecoration(labelText: 'Kategori'),
                items: cats
                    .map((c) => DropdownMenuItem(
                        value: c.id, child: Text(c.name)))
                    .toList(),
                onChanged: (v) =>
                    setS(() => categoryId = v ?? categoryId),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: limit,
                decoration: const InputDecoration(
                  labelText: 'Batas (Rp)',
                  prefixText: 'Rp ',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                autofocus: true,
              ),
              if (periodType == BudgetPeriodType.custom) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        child: Text(
                            'Dari ${customStart.day}/${customStart.month}'),
                        onPressed: () async {
                          final p = await showDatePicker(
                            context: ctx,
                            initialDate: customStart,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now()
                                .add(const Duration(days: 365 * 2)),
                          );
                          if (p != null) {
                            setS(() => customStart = p);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        child: Text(
                            'Sampai ${customEnd.day}/${customEnd.month}'),
                        onPressed: () async {
                          final p = await showDatePicker(
                            context: ctx,
                            initialDate: customEnd,
                            firstDate: customStart,
                            lastDate: DateTime.now()
                                .add(const Duration(days: 365 * 2)),
                          );
                          if (p != null) {
                            setS(() => customEnd = p);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
              if (periodType == BudgetPeriodType.weekly)
                Builder(builder: (ctx) {
                  final wr = BudgetPeriods.rangeFor(
                      BudgetPeriodType.weekly, DateTime.now());
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Minggu ini: ${BudgetPeriods.rangeLabel(BudgetPeriodType.weekly, wr.start, wr.end)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  );
                }),
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
  if (ok != true) return;
  final lim = parseIdrInput(limit.text);
  if (lim <= 0) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Isi batas budget dulu.')),
      );
    }
    return;
  }
  final now = DateTime.now();
  final r = BudgetPeriods.rangeFor(periodType, now,
      customStart: customStart, customEnd: customEnd);
  final b = Budget(
    id: newId(),
    categoryId: categoryId,
    month: monthKey(r.start),
    limit: lim,
    periodType: periodType,
    startMs: r.start.millisecondsSinceEpoch,
    endMs: r.end.millisecondsSinceEpoch,
  );
  await repo.saveBudget(b);
  // Reset penanda notifikasi agar budget baru ikut dicek.
  invalidateAll(ref);
}
