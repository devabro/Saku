import 'package:intl/intl.dart';

final _idr = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);

/// "Rp1.250.000" — tanpa desimal, sesuai kebiasaan Indonesia.
String formatIdr(int amount) => _idr.format(amount);

/// Versi ringkas untuk kartu kecil: Rp950 rb, Rp1,2 jt, Rp3,5 M.
String formatIdrShort(int amount) {
  final neg = amount < 0;
  final a = amount.abs();
  String out;
  if (a >= 1000000000) {
    out = 'Rp${_trim(a / 1000000000)} M';
  } else if (a >= 1000000) {
    out = 'Rp${_trim(a / 1000000)} jt';
  } else if (a >= 1000) {
    out = 'Rp${_trim(a / 1000)} rb';
  } else {
    out = 'Rp$a';
  }
  return neg ? '-$out' : out;
}

String _trim(double v) {
  final s = v.toStringAsFixed(1).replaceAll('.', ',');
  return s.endsWith(',0') ? s.substring(0, s.length - 2) : s;
}

/// 'yyyy-MM' untuk kunci budget & query bulanan.
String monthKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}';

/// Awal bulan dari kunci 'yyyy-MM'.
DateTime monthStart(String monthKey) {
  final parts = monthKey.split('-');
  return DateTime(int.parse(parts[0]), int.parse(parts[1]));
}

/// "Oktober 2026" — label Indonesia tanpa perlu date formatting locale.
String monthLabel(String key) {
  const names = [
    '', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
  ];
  final parts = key.split('-');
  return '${names[int.parse(parts[1])]} ${parts[0]}';
}

/// ID unik sederhana (cukup untuk pemakaian lokal single-user).
String newId() =>
    '${DateTime.now().microsecondsSinceEpoch}${(1000 + (DateTime.now().microsecond % 9000))}';

/// Ambil angka dari input bebas ("1.250.000" / "Rp 5000" -> 1250000).
int parseIdrInput(String raw) {
  final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  return digits.isEmpty ? 0 : int.parse(digits);
}
