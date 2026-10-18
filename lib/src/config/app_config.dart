/// Konfigurasi tingkat aplikasi.
///
/// GANTI NAMA APLIKASI DI SINI: cukup ubah [appName] — seluruh UI
/// (AppBar, onboarding, about, teks share) membaca dari konstanta ini.
///
/// Catatan: ini hanya nama tampilan. Nama package Android/iOS (`saku`)
/// tidak ikut berubah; itu hanya perlu diganti kalau aplikasi dipublish.
class AppConfig {
  AppConfig._();

  /// Nama aplikasi yang tampil di UI. Working title: "Saku".
  static const String appName = 'Saku';

  static const String tagline = 'Atur uangmu, tanpa drama.';

  static const String version = '0.1.0 (fase 1, local-first)';

  /// Target savings-rate default (20%) untuk insight engine.
  static const double defaultSavingsTarget = 0.20;
}
