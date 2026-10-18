import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/debt_logic.dart';
import '../logic/money.dart';
import '../models/debt.dart';
import '../models/transaction.dart';
import '../models/upcoming.dart';
import '../state/providers.dart';
import 'widgets/masked_amount.dart';

/// Layar Utang Piutang + Terjadwal (dua tab).
class DebtsScreen extends ConsumerWidget {
  const DebtsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Utang Piutang'),
              Tab(text: 'Terjadwal'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _debtsTab(context, ref),
                _upcomingTab(context, ref),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ================= UTANG =================

  Widget _debtsTab(BuildContext context, WidgetRef ref) {
    final debts = ref.watch(debtsProvider);
    final wallets = ref.watch(walletsProvider);
    return debts.when(
      data: (list) => wallets.when(
        data: (ws) => _debtsList(context, ref, list, ws),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Gagal: $e')),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Gagal: $e')),
    );
  }

  Widget _debtsList(
      BuildContext context, WidgetRef ref, List<Debt> debts, List wallets) {
    if (debts.isEmpty) {
      return const Center(
        child: Text(
          'Belum ada utang/piutang.\nPencet + buat catat.',
          textAlign: TextAlign.center,
        ),
      );
    }
    final now = DateTime.now();
    return ListView.builder(
      itemCount: debts.length,
      itemBuilder: (ctx, i) {
        final d = debts[i];
        final st = debtStatus(d.totalAmount, d.paidAmount);
        final overdue = isDebtOverdue(d, now);
        final color = st == DebtStatus.paid
            ? Colors.green
            : overdue
                ? Colors.red
                : d.kind == DebtKind.utang
                    ? Colors.orange
                    : Colors.blue;
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.15),
              child: Icon(
                d.kind == DebtKind.utang
                    ? Icons.arrow_upward
                    : Icons.arrow_downward,
                color: color,
              ),
            ),
            title: Text('${d.kind.label} • ${d.personName}'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (d.dueDate != null)
                  Text(
                    'Jatuh tempo: ${d.dueDate!.day}/${d.dueDate!.month}/${d.dueDate!.year}'
                    '${overdue ? ' (lewat!)' : ''}',
                    style: TextStyle(
                        color: overdue ? Colors.red : null, fontSize: 12),
                  ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: d.totalAmount == 0
                      ? 0
                      : (d.paidAmount / d.totalAmount).clamp(0.0, 1.0),
                  color: color,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    MaskedAmount(d.remaining, short: true),
                    Text(' sisa dari ${formatIdrShort(d.totalAmount)}',
                        style: const TextStyle(fontSize: 12)),
                    const Spacer(),
                    Text(st.label,
                        style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
            trailing: st == DebtStatus.paid
                ? IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Hapus',
                    onPressed: () =>
                        _confirmDeleteDebt(context, ref, d),
                  )
                : IconButton(
                    icon: const Icon(Icons.payments_outlined),
                    tooltip: d.kind == DebtKind.utang
                        ? 'Bayar'
                        : 'Terima pembayaran',
                    onPressed: () =>
                        _payDialog(context, ref, d, wallets),
                  ),
            onTap: st == DebtStatus.paid
                ? () => _confirmDeleteDebt(context, ref, d)
                : () => _payDialog(context, ref, d, wallets),
          ),
        );
      },
    );
  }

  Future<void> _confirmDeleteDebt(
      BuildContext context, WidgetRef ref, Debt d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus catatan utang?'),
        content: const Text('Riwayat utang ini akan dihapus.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Hapus')),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(repositoryProvider).deleteDebt(d.id);
      invalidateAll(ref);
    }
  }

  Future<void> _payDialog(
      BuildContext context, WidgetRef ref, Debt d, List wallets) async {
    final c = TextEditingController(text: '${d.remaining}');
    String? walletId = d.walletId;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(d.kind == DebtKind.utang
              ? 'Bayar utang ke ${d.personName}'
              : 'Terima dari ${d.personName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: c,
                decoration: InputDecoration(
                  labelText: 'Nominal (Rp)',
                  prefixText: 'Rp ',
                  helperText: 'Sisa: ${formatIdr(d.remaining)}',
                ),
                keyboardType: TextInputType.number,
                autofocus: true,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: walletId,
                decoration: const InputDecoration(labelText: 'Dompet'),
                items: wallets
                    .map((w) => DropdownMenuItem(
                        value: w.id as String, child: Text(w.name as String)))
                    .toList(),
                onChanged: (v) => setS(() => walletId = v),
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
    if (ok != true || walletId == null) return;
    final amount = parseIdrInput(c.text);
    final success = await ref
        .read(repositoryProvider)
        .payDebt(d.id, amount, walletId!);
    if (!context.mounted) return;
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Nominal tidak valid (melebihi sisa?).')),
      );
      return;
    }
    invalidateAll(ref);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pembayaran tercatat.')),
    );
  }

  // ================= TERJADWAL =================

  Widget _upcomingTab(BuildContext context, WidgetRef ref) {
    final items = ref.watch(upcomingProvider);
    final wallets = ref.watch(walletsProvider);
    return items.when(
      data: (list) => wallets.when(
        data: (ws) => _upcomingList(context, ref, list, ws),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Gagal: $e')),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Gagal: $e')),
    );
  }

  Widget _upcomingList(BuildContext context, WidgetRef ref,
      List<UpcomingTx> items, List wallets) {
    if (items.isEmpty) {
      return const Center(
        child: Text(
          'Belum ada transaksi terjadwal.\nCatat transaksi lalu aktifkan "Jadwalkan".',
          textAlign: TextAlign.center,
        ),
      );
    }
    final wnames = {for (final w in wallets) w.id as String: w.name as String};
    final now = DateTime.now();
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (ctx, i) {
        final u = items[i];
        final due = DateTime(u.dueDate.year, u.dueDate.month, u.dueDate.day);
        final today = DateTime(now.year, now.month, now.day);
        final diff = due.difference(today).inDays;
        final when = diff < 0
            ? 'Terlewat ${-diff} hari'
            : diff == 0
                ? 'Hari ini'
                : diff == 1
                    ? 'Besok'
                    : '$diff hari lagi';
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor:
                  Colors.blue.withValues(alpha: 0.15),
              child: Icon(
                u.type == TransactionType.expense
                    ? Icons.arrow_upward
                    : Icons.arrow_downward,
                color: Colors.blue,
              ),
            ),
            title: Text(u.note.isEmpty ? 'Terjadwal' : u.note),
            subtitle: Text(
                '$when • ${u.dueDate.day}/${u.dueDate.month}/${u.dueDate.year} • ${wnames[u.walletId] ?? ''}'),
            trailing: Text(
              '${u.type == TransactionType.expense ? '−' : '+'}${formatIdr(u.amount)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            onTap: () => _upcomingActions(context, ref, u),
          ),
        );
      },
    );
  }

  Future<void> _upcomingActions(
      BuildContext context, WidgetRef ref, UpcomingTx u) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(u.note.isEmpty ? 'Terjadwal' : u.note),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'paid'),
            child: const ListTile(
              leading: Icon(Icons.check_circle_outline),
              title: Text('Tandai sudah dibayar'),
              subtitle: Text('Jadi transaksi beneran, saldo bergerak'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'delete'),
            child: const ListTile(
              leading: Icon(Icons.delete_outline, color: Colors.red),
              title: Text('Hapus jadwal',
                  style: TextStyle(color: Colors.red)),
            ),
          ),
        ],
      ),
    );
    if (choice == 'paid') {
      await ref.read(repositoryProvider).markUpcomingPaid(u.id);
      invalidateAll(ref);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaksi dicatat.')),
        );
      }
    } else if (choice == 'delete') {
      await ref.read(repositoryProvider).deleteUpcoming(u.id);
      invalidateAll(ref);
    }
  }
}

/// Dialog tambah utang/piutang. Dipakai dari FAB tab Utang.
Future<void> showDebtEditor(BuildContext context, WidgetRef ref) async {
  final repo = ref.read(repositoryProvider);
  final wallets = await repo.getWallets();
  if (!context.mounted || wallets.isEmpty) return;

  var kind = DebtKind.utang;
  final person = TextEditingController();
  final amount = TextEditingController();
  String walletId = wallets.first.id;
  DateTime? due;
  final note = TextEditingController();

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        title: const Text('Catat utang/piutang'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<DebtKind>(
                segments: const [
                  ButtonSegment(
                      value: DebtKind.utang, label: Text('Utang')),
                  ButtonSegment(
                      value: DebtKind.piutang, label: Text('Piutang')),
                ],
                selected: {kind},
                onSelectionChanged: (s) => setS(() => kind = s.first),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: person,
                decoration: const InputDecoration(
                  labelText: 'Nama orang',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amount,
                decoration: const InputDecoration(
                  labelText: 'Nominal (Rp)',
                  prefixText: 'Rp ',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: walletId,
                decoration: const InputDecoration(labelText: 'Dompet'),
                items: wallets
                    .map((w) => DropdownMenuItem(
                        value: w.id, child: Text(w.name)))
                    .toList(),
                onChanged: (v) => setS(() => walletId = v ?? walletId),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(due == null
                        ? 'Tanpa jatuh tempo'
                        : 'Jatuh tempo: ${due!.day}/${due!.month}/${due!.year}'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: () async {
                      final p = await showDatePicker(
                        context: ctx,
                        initialDate:
                            DateTime.now().add(const Duration(days: 7)),
                        firstDate: DateTime.now(),
                        lastDate:
                            DateTime.now().add(const Duration(days: 365 * 5)),
                      );
                      if (p != null) setS(() => due = p);
                    },
                  ),
                ],
              ),
              TextField(
                controller: note,
                decoration: const InputDecoration(
                  labelText: 'Catatan (opsional)',
                  border: OutlineInputBorder(),
                ),
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
  if (ok != true) return;
  final amt = parseIdrInput(amount.text);
  if (person.text.trim().isEmpty || amt <= 0) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Isi nama dan nominal dulu.')),
      );
    }
    return;
  }
  await repo.createDebt(Debt(
    id: newId(),
    personName: person.text.trim(),
    kind: kind,
    totalAmount: amt,
    dueDate: due,
    walletId: walletId,
    note: note.text.trim(),
    createdAt: DateTime.now(),
  ));
  invalidateAll(ref);
}
