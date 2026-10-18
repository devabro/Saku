import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/sample_data_service.dart';
import '../state/providers.dart';

/// Aksi "pasang data contoh" + dialog konfirmasi + snackbar.
/// Dipakai di Pengaturan dan empty state dashboard (satu sumber).
Future<void> installSampleData(
    BuildContext context, WidgetRef ref) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Pasang data contoh?'),
      content: const Text(
          'Saku akan mengisi ~2 bulan transaksi dummy (gaji, jajan, kopi, skincare, dll) biar kamu bisa eksplor semua fitur. Data asli kamu tidak diapa-apakan, dan bisa dihapus kapan aja.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Pasang')),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(
      const SnackBar(content: Text('Menyiapkan data contoh...')));
  final n =
      await SampleDataService.install(ref.read(repositoryProvider));
  await ref.read(sampleDataActiveProvider.notifier).set(true);
  invalidateAll(ref);
  if (context.mounted) {
    messenger.showSnackBar(SnackBar(
        content: Text(n > 0
            ? '$n transaksi contoh dipasang. Selamat eksplor!'
            : 'Data contoh sudah aktif.')));
  }
}
