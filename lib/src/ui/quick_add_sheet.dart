import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../logic/money.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../state/providers.dart';

/// Quick-add: nominal + kategori + dompet + catatan.
/// Target: tersimpan dalam <10 detik. Dipakai juga untuk edit & transfer.
class QuickAddSheet extends ConsumerStatefulWidget {
  const QuickAddSheet({super.key, this.edit, this.initialType});

  /// Jika diisi, sheet menjadi mode edit.
  final SakuTransaction? edit;

  /// Untuk tombol "Transfer" dari layar dompet.
  final TransactionType? initialType;

  @override
  ConsumerState<QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends ConsumerState<QuickAddSheet> {
  late TransactionType _type;
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String? _categoryId;
  String? _walletId;
  String? _toWalletId;
  DateTime _date = DateTime.now();
  String? _receiptPath;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.edit;
    _type = e?.type ?? widget.initialType ?? TransactionType.expense;
    if (e != null) {
      _amount.text = '${e.amount}';
      _note.text = e.note;
      _categoryId = e.categoryId;
      _walletId = e.walletId;
      _toWalletId = e.toWalletId;
      _date = e.date;
      _receiptPath = e.receiptPath;
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickReceipt(ImageSource source) async {
    final picked =
        await ImagePicker().pickImage(source: source, maxWidth: 1600);
    if (picked == null) return;
    final dir = await getApplicationDocumentsDirectory();
    final receipts = Directory(p.join(dir.path, 'receipts'));
    await receipts.create(recursive: true);
    final dest = File(p.join(receipts.path, '${newId()}.jpg'));
    await File(picked.path).copy(dest.path);
    setState(() => _receiptPath = dest.path);

    // Tawarkan OCR (fase 1: stub — jujur bilang belum aktif).
    if (!mounted) return;
    final ocr = ref.read(ocrServiceProvider);
    final result = await ocr.scanReceipt(dest.path);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.rawText)),
    );
  }

  Future<void> _save() async {
    final amount = parseIdrInput(_amount.text);
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Isi nominal dulu.')),
      );
      return;
    }
    if (_walletId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih dompet dulu.')),
      );
      return;
    }
    if (_type == TransactionType.transfer) {
      if (_toWalletId == null || _toWalletId == _walletId) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pilih dompet tujuan yang berbeda.')),
        );
        return;
      }
    } else if (_categoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih kategori dulu.')),
      );
      return;
    }
    setState(() => _saving = true);
    final repo = ref.read(repositoryProvider);
    final tx = SakuTransaction(
      id: widget.edit?.id ?? newId(),
      type: _type,
      amount: amount,
      categoryId: _type == TransactionType.transfer ? null : _categoryId,
      walletId: _walletId!,
      toWalletId: _type == TransactionType.transfer ? _toWalletId : null,
      note: _note.text.trim(),
      date: DateTime(_date.year, _date.month, _date.day, DateTime.now().hour,
          DateTime.now().minute),
      receiptPath: _receiptPath,
      recurringId: widget.edit?.recurringId,
    );
    await repo.saveTransaction(tx);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);
    final wallets = ref.watch(walletsProvider);
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.edit == null ? 'Catat transaksi' : 'Ubah transaksi',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            SegmentedButton<TransactionType>(
              segments: const [
                ButtonSegment(
                    value: TransactionType.expense,
                    label: Text('Keluar'),
                    icon: Icon(Icons.arrow_upward)),
                ButtonSegment(
                    value: TransactionType.income,
                    label: Text('Masuk'),
                    icon: Icon(Icons.arrow_downward)),
                ButtonSegment(
                    value: TransactionType.transfer,
                    label: Text('Transfer'),
                    icon: Icon(Icons.swap_horiz)),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() {
                _type = s.first;
                _categoryId = null;
              }),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amount,
              decoration: const InputDecoration(
                labelText: 'Nominal (Rp)',
                prefixText: 'Rp ',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              autofocus: widget.edit == null,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            if (_type != TransactionType.transfer)
              categories.when(
                data: (cats) {
                  final kind = _type == TransactionType.expense
                      ? CategoryKind.expense
                      : CategoryKind.income;
                  final list =
                      cats.where((c) => c.kind == kind && c.enabled).toList();
                  if (_categoryId != null &&
                      !list.any((c) => c.id == _categoryId)) {
                    _categoryId = null;
                  }
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final c in list)
                        ChoiceChip(
                          label: Text(c.name),
                          avatar: Icon(c.icon, size: 18, color: c.color),
                          selected: _categoryId == c.id,
                          onSelected: (_) =>
                              setState(() => _categoryId = c.id),
                        ),
                    ],
                  );
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Gagal: $e'),
              ),
            const SizedBox(height: 12),
            wallets.when(
              data: (ws) {
                _walletId ??= ws.isNotEmpty ? ws.first.id : null;
                return Column(
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: _walletId,
                      decoration: InputDecoration(
                          labelText: _type == TransactionType.transfer
                              ? 'Dari dompet'
                              : 'Dompet'),
                      items: ws
                          .map((w) => DropdownMenuItem(
                              value: w.id,
                              child: Text('${w.name} (${w.type.label})')))
                          .toList(),
                      onChanged: (v) => setState(() => _walletId = v),
                    ),
                    if (_type == TransactionType.transfer) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _toWalletId,
                        decoration:
                            const InputDecoration(labelText: 'Ke dompet'),
                        items: ws
                            .where((w) => w.id != _walletId)
                            .map((w) => DropdownMenuItem(
                                value: w.id,
                                child:
                                    Text('${w.name} (${w.type.label})')))
                            .toList(),
                        onChanged: (v) => setState(() => _toWalletId = v),
                      ),
                    ],
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Gagal: $e'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _note,
                    decoration: const InputDecoration(
                      labelText: 'Catatan (opsional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Tanggal',
                  icon: const Icon(Icons.calendar_today),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 1)),
                    );
                    if (picked != null) setState(() => _date = picked);
                  },
                ),
                IconButton(
                  tooltip: 'Foto struk',
                  icon: Icon(Icons.receipt_long,
                      color: _receiptPath == null ? null : Colors.green),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      builder: (ctx) => SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              leading: const Icon(Icons.camera_alt),
                              title: const Text('Ambil foto'),
                              onTap: () {
                                Navigator.pop(ctx);
                                _pickReceipt(ImageSource.camera);
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.photo),
                              title: const Text('Dari galeri'),
                              onTap: () {
                                Navigator.pop(ctx);
                                _pickReceipt(ImageSource.gallery);
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            if (_receiptPath != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(File(_receiptPath!),
                          width: 64, height: 64, fit: BoxFit.cover),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                        child: Text('Struk terlampir.',
                            style: TextStyle(fontSize: 13))),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () =>
                          setState(() => _receiptPath = null),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(widget.edit == null ? 'Simpan' : 'Simpan perubahan'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
