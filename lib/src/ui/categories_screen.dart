import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/money.dart';
import '../models/category.dart';
import '../state/providers.dart';

/// Kelola kategori: tambah/edit/nonaktif/hapus (custom saja).
class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  bool _isSeed(String id) => id.startsWith('cat_') || id.startsWith('inc_');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cats = ref.watch(categoriesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Kategori')),
      body: cats.when(
        data: (list) {
          final expense =
              list.where((c) => c.kind == CategoryKind.expense).toList();
          final income =
              list.where((c) => c.kind == CategoryKind.income).toList();
          return ListView(
            children: [
              _section(context, ref, 'Pengeluaran', expense),
              _section(context, ref, 'Pemasukan', income),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Gagal: $e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showCategoryEditor(context, ref, null),
        icon: const Icon(Icons.add),
        label: const Text('Kategori'),
      ),
    );
  }

  Widget _section(
      BuildContext context, WidgetRef ref, String title, List<Category> cats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(title,
              style: Theme.of(context).textTheme.titleSmall),
        ),
        for (final c in cats)
          ListTile(
            leading: CircleAvatar(
              backgroundColor: c.color.withValues(alpha: 0.15),
              child: Icon(c.icon, color: c.color),
            ),
            title: Text(c.name,
                style: TextStyle(
                    color: c.enabled ? null : Colors.grey)),
            subtitle: _isSeed(c.id)
                ? const Text('Bawaan', style: TextStyle(fontSize: 12))
                : const Text('Custom', style: TextStyle(fontSize: 12)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Switch(
                  value: c.enabled,
                  onChanged: (_) async {
                    await ref
                        .read(repositoryProvider)
                        .saveCategory(c.copyWith(enabled: !c.enabled));
                    invalidateAll(ref);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () =>
                      showCategoryEditor(context, ref, c),
                ),
                if (!_isSeed(c.id))
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: Colors.red),
                    onPressed: () =>
                        _confirmDelete(context, ref, c),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Category c) async {
    final used =
        await ref.read(repositoryProvider).isCategoryUsed(c.id);
    if (!context.mounted) return;
    if (used) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Kategori masih dipakai transaksi. Nonaktifkan saja.')),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Hapus "${c.name}"?'),
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
      await ref.read(repositoryProvider).deleteCategory(c.id);
      invalidateAll(ref);
    }
  }
}

/// Dialog tambah/edit kategori.
Future<void> showCategoryEditor(
    BuildContext context, WidgetRef ref, Category? edit) async {
  final name = TextEditingController(text: edit?.name ?? '');
  var kind = edit?.kind ?? CategoryKind.expense;
  var iconKey = edit?.iconKey ?? 'more_horiz';
  var colorValue = edit?.colorValue ?? 0xFF78909C;

  const palette = [
    0xFFFF7043, 0xFF42A5F5, 0xFFAB47BC, 0xFFFFCA28, 0xFF26A69A,
    0xFFEC407A, 0xFF5C6BC0, 0xFF66BB6A, 0xFF78909C, 0xFF8D6E63,
  ];

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        title:
            Text(edit == null ? 'Kategori baru' : 'Ubah kategori'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (edit == null)
                SegmentedButton<CategoryKind>(
                  segments: const [
                    ButtonSegment(
                        value: CategoryKind.expense,
                        label: Text('Keluar')),
                    ButtonSegment(
                        value: CategoryKind.income,
                        label: Text('Masuk')),
                  ],
                  selected: {kind},
                  onSelectionChanged: (s) =>
                      setS(() => kind = s.first),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: name,
                decoration: const InputDecoration(
                  labelText: 'Nama kategori',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              const Text('Ikon'),
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (final k in Category.availableIconKeys)
                    InkWell(
                      onTap: () => setS(() => iconKey = k),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: iconKey == k
                              ? Theme.of(context)
                                  .colorScheme
                                  .primaryContainer
                              : null,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Category(
                                id: 'tmp',
                                name: 'tmp',
                                iconKey: k,
                                colorValue: 0xFF000000)
                            .icon),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              const Text('Warna'),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in palette)
                    InkWell(
                      onTap: () => setS(() => colorValue = c),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Color(c),
                          shape: BoxShape.circle,
                          border: colorValue == c
                              ? Border.all(
                                  color: Colors.white, width: 3)
                              : null,
                        ),
                      ),
                    ),
                ],
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
  if (name.text.trim().isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Isi nama kategori dulu.')),
      );
    }
    return;
  }
  final repo = ref.read(repositoryProvider);
  if (edit == null) {
    await repo.saveCategory(Category(
      id: newId(),
      name: name.text.trim(),
      iconKey: iconKey,
      colorValue: colorValue,
      kind: kind,
    ));
  } else {
    await repo.saveCategory(edit.copyWith(
      name: name.text.trim(),
      iconKey: iconKey,
      colorValue: colorValue,
    ));
  }
  invalidateAll(ref);
}
