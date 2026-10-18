import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/transaction.dart';
import '../models/wallet.dart';

/// Export CSV & JSON → file di direktori temporer → dibagikan via share sheet.
/// Tidak ada upload ke mana pun.
class ExportService {
  ExportService._();

  static String transactionsToCsv(
    List<SakuTransaction> txs,
    Map<String, String> walletNames,
    Map<String, String> categoryNames,
  ) {
    final b = StringBuffer();
    b.writeln('tanggal,tipe,jumlah,kategori,dompet,dompet_tujuan,catatan');
    for (final t in txs) {
      final row = [
        t.date.toIso8601String(),
        t.type.name,
        t.amount.toString(),
        _csv(t.categoryId == null ? '' : (categoryNames[t.categoryId] ?? '')),
        _csv(walletNames[t.walletId] ?? ''),
        _csv(t.toWalletId == null ? '' : (walletNames[t.toWalletId] ?? '')),
        _csv(t.note),
      ];
      b.writeln(row.join(','));
    }
    return b.toString();
  }

  static String _csv(String v) {
    if (v.contains(',') || v.contains('"') || v.contains('\n')) {
      return '"${v.replaceAll('"', '""')}"';
    }
    return v;
  }

  static String walletsToJson(List<Wallet> wallets) {
    final b = StringBuffer()..writeln('[');
    for (var i = 0; i < wallets.length; i++) {
      final w = wallets[i];
      b.writeln('  {"id": "${w.id}", "name": "${w.name}", '
          '"type": "${w.type.name}", "balance": ${w.balance}}'
          '${i < wallets.length - 1 ? ',' : ''}');
    }
    b.writeln(']');
    return b.toString();
  }

  /// Tulis [content] ke file temporer lalu buka share sheet.
  static Future<void> shareTextFile(String fileName, String content) async {
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, fileName));
    await file.writeAsString(content);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], text: fileName),
    );
  }
}
