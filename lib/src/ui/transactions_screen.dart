import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/money.dart';
import '../logic/tx_filter.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../models/wallet.dart';
import '../state/providers.dart';
import 'quick_add_sheet.dart';

/// Daftar transaksi: cari + filter lengkap (tanggal, kategori, dompet,
/// tipe, nominal), edit, hapus (geser).
class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() =>
      _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  TxFilter _filter = const TxFilter();

  int get _activeCount {
    var n = 0;
    if (_filter.from != null || _filter.to != null) n++;
    if (_filter.categoryId != null) n++;
    if (_filter.walletId != null) n++;
    if (_filter.type != null) n++;
    if (_filter.minAmount != null || _filter.maxAmount != null) n++;
    return n;
  }

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
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Cari transaksi...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(
                      () => _filter = _filter.copyWith(query: v)),
                ),
              ),
              const SizedBox(width: 8),
              Badge(
                isLabelVisible: _activeCount > 0,
                label: Text('$_activeCount'),
                child: IconButton.filledTonal(
                  tooltip: 'Filter',
                  icon: const Icon(Icons.filter_list),
                  onPressed: () =>
                      _openFilter(context, ref),
                ),
              ),
            ],
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

  Future<void> _openFilter(BuildContext context, WidgetRef ref) async {
    final cats = await ref.read(categoriesProvider.future);
    final wallets = await ref.read(walletsProvider.future);
    if (!context.mounted) return;
    final result = await showModalBottomSheet<TxFilter>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          _FilterSheet(initial: _filter, categories: cats, wallets: wallets),
    );
    if (result != null) setState(() => _filter = result);
  }

  Widget _list(BuildContext context, WidgetRef ref, List<SakuTransaction> txs,
      List<Category> cats, List<Wallet> ws) {
    final names = {for (final c in cats) c.id: c.name};
    final icons = {for (final c in cats) c.id: c.icon};
    final colors = {for (final c in cats) c.id: c.color};
    final wnames = {for (final w in ws) w.id: w.name};

    final filtered = _filter.apply(txs, names);

    if (filtered.isEmpty) {
      return Center(
          child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primaryContainer
                    .withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _filter.isActive
                    ? Icons.search_off_rounded
                    : Icons.receipt_long_rounded,
                size: 36,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 14),
            Text(
                _filter.isActive
                    ? 'Tidak ada transaksi yang cocok filter.\nCoba ubah katanya ya.'
                    : 'Belum ada transaksi.\nPencet tombol + Catat di bawah buat mulai.',
                textAlign: TextAlign.center),
          ],
        ),
      ));
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
                    backgroundColor: Colors.transparent,
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

/// Bottom sheet filter transaksi.
class _FilterSheet extends StatefulWidget {
  const _FilterSheet(
      {required this.initial,
      required this.categories,
      required this.wallets});
  final TxFilter initial;
  final List<Category> categories;
  final List<Wallet> wallets;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late TxFilter _f;
  final _min = TextEditingController();
  final _max = TextEditingController();

  @override
  void initState() {
    super.initState();
    _f = widget.initial;
    if (_f.minAmount != null) _min.text = '${_f.minAmount}';
    if (_f.maxAmount != null) _max.text = '${_f.maxAmount}';
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Filter transaksi',
                    style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                TextButton(
                  onPressed: () =>
                      Navigator.pop(context, const TxFilter()),
                  child: const Text('Reset'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Rentang tanggal.
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(_f.from == null
                        ? 'Dari tanggal'
                        : '${_f.from!.day}/${_f.from!.month}/${_f.from!.year}'),
                    onPressed: () async {
                      final p = await showDatePicker(
                        context: context,
                        initialDate: _f.from ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (p != null) {
                        setState(() => _f = _f.copyWith(
                            from: () => DateTime(
                                p.year, p.month, p.day)));
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(_f.to == null
                        ? 'Sampai tanggal'
                        : '${_f.to!.day}/${_f.to!.month}/${_f.to!.year}'),
                    onPressed: () async {
                      final p = await showDatePicker(
                        context: context,
                        initialDate: _f.to ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (p != null) {
                        setState(() => _f = _f.copyWith(
                            to: () => DateTime(
                                p.year, p.month, p.day, 23, 59, 59)));
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Tipe.
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Semua tipe'),
                  selected: _f.type == null,
                  onSelected: (_) =>
                      setState(() => _f = _f.copyWith(type: () => null)),
                ),
                for (final t in TransactionType.values)
                  ChoiceChip(
                    label: Text(t.label),
                    selected: _f.type == t,
                    onSelected: (_) =>
                        setState(() => _f = _f.copyWith(type: () => t)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _f.categoryId,
              decoration:
                  const InputDecoration(labelText: 'Kategori (semua)'),
              items: [
                const DropdownMenuItem(
                    value: null, child: Text('Semua kategori')),
                for (final c in widget.categories)
                  DropdownMenuItem(
                      value: c.id, child: Text(c.name)),
              ],
              onChanged: (v) => setState(
                  () => _f = _f.copyWith(categoryId: () => v)),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _f.walletId,
              decoration:
                  const InputDecoration(labelText: 'Dompet (semua)'),
              items: [
                const DropdownMenuItem(
                    value: null, child: Text('Semua dompet')),
                for (final w in widget.wallets)
                  DropdownMenuItem(
                      value: w.id, child: Text(w.name)),
              ],
              onChanged: (v) => setState(
                  () => _f = _f.copyWith(walletId: () => v)),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _min,
                    decoration: const InputDecoration(
                        labelText: 'Min (Rp)', prefixText: 'Rp '),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _max,
                    decoration: const InputDecoration(
                        labelText: 'Maks (Rp)', prefixText: 'Rp '),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  final min = parseIdrInput(_min.text);
                  final max = parseIdrInput(_max.text);
                  Navigator.pop(
                      context,
                      _f.copyWith(
                        minAmount: () => min > 0 ? min : null,
                        maxAmount: () => max > 0 ? max : null,
                      ));
                },
                child: const Text('Terapkan'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
