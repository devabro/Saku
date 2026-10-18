import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/money.dart';
import '../models/goal.dart';
import '../state/providers.dart';
import 'widgets/masked_amount.dart';

/// Dialog tambah/ubah target. Top-level agar bisa dipanggil dari FAB Home.
Future<void> showGoalEditor(
    BuildContext context, WidgetRef ref, Goal? existing) async {
  final name = TextEditingController(text: existing?.name ?? '');
  final target = TextEditingController(
      text: existing != null ? '${existing.targetAmount}' : '');
  DateTime? deadline = existing?.deadline;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        title: Text(existing == null ? 'Target baru' : 'Ubah target'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Buat apa?')),
            const SizedBox(height: 8),
            TextField(
              controller: target,
              decoration: const InputDecoration(
                  labelText: 'Target (Rp)', prefixText: 'Rp '),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(deadline == null
                      ? 'Tanpa deadline'
                      : 'Deadline: ${deadline!.day}/${deadline!.month}/${deadline!.year}'),
                ),
                TextButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: deadline ??
                          DateTime.now().add(const Duration(days: 90)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                    );
                    if (picked != null) setS(() => deadline = picked);
                  },
                  child: const Text('Pilih'),
                ),
              ],
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
    final goal = existing?.copyWith(
          name: name.text.trim(),
          targetAmount: parseIdrInput(target.text),
          deadline: deadline,
        ) ??
        Goal(
          id: newId(),
          name: name.text.trim(),
          targetAmount: parseIdrInput(target.text),
          deadline: deadline,
          createdAt: DateTime.now(),
        );
    await ref.read(repositoryProvider).saveGoal(goal);
  }
}

/// Target nabung: progres, tambah/setor manual, ubah, hapus.
/// FAB "Target" disediakan HomeScreen (context-aware).
class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(goalsProvider);
    return goals.when(
      data: (list) => list.isEmpty
          ? const Center(
              child: Text(
                  'Belum ada target.\nPencet "Target" buat bikin satu.',
                  textAlign: TextAlign.center))
          : ListView.builder(
              itemCount: list.length,
              itemBuilder: (ctx, i) => _goalCard(context, ref, list[i]),
            ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Gagal: $e')),
    );
  }

  Widget _goalCard(BuildContext context, WidgetRef ref, Goal g) {
    final pct = g.progress.clamp(0.0, 1.0);
    final done = g.progress >= 1;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(g.name,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                if (done)
                  const Chip(
                    label: Text('Tercapai!'),
                    visualDensity: VisualDensity.compact,
                  ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () async {
                    await showGoalEditor(context, ref, g);
                    invalidateAll(ref);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _deleteGoal(context, ref, g),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: pct,
              minHeight: 10,
              borderRadius: BorderRadius.circular(5),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                MaskedAmount(g.savedAmount, short: true),
                Text(' / ${formatIdrShort(g.targetAmount)}',
                    style: const TextStyle(fontSize: 13)),
                const Spacer(),
                if (g.deadline != null)
                  Text(
                      'target ${g.deadline!.day}/${g.deadline!.month}/${g.deadline!.year}',
                      style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _contribute(context, ref, g, 1),
                    icon: const Icon(Icons.add),
                    label: const Text('Nabung'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _contribute(context, ref, g, -1),
                    icon: const Icon(Icons.remove),
                    label: const Text('Ambil'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _contribute(
      BuildContext context, WidgetRef ref, Goal g, int sign) async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(sign > 0 ? 'Nabung ke "${g.name}"' : 'Ambil dari "${g.name}"'),
        content: TextField(
          controller: c,
          decoration: const InputDecoration(
              labelText: 'Nominal (Rp)', prefixText: 'Rp '),
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
      final amount = parseIdrInput(c.text);
      if (amount > 0) {
        final updated = g.copyWith(
            savedAmount: (g.savedAmount + sign * amount).clamp(0, 1 << 62));
        await ref.read(repositoryProvider).saveGoal(updated);
        invalidateAll(ref);
      }
    }
  }

  Future<void> _deleteGoal(
      BuildContext context, WidgetRef ref, Goal g) async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Hapus target?'),
            content: Text('"${g.name}" akan dihapus.'),
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
      await ref.read(repositoryProvider).deleteGoal(g.id);
      invalidateAll(ref);
    }
  }
}
