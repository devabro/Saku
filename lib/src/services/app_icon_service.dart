import 'package:flutter/services.dart';

/// Ganti ikon launcher aplikasi tanpa install ulang (Android saja).
///
/// Bekerja via activity-alias di AndroidManifest + PackageManager.
/// Di platform lain (atau bila channel gagal) semua method jadi no-op aman.
class AppIconService {
  AppIconService._();
  static final AppIconService instance = AppIconService._();

  static const _channel = MethodChannel('id.saku.saku/app_icon');

  /// 'a' = Kuncup Mawar (default), 'b' = Bulan Mutiara, 'c' = A Azha.
  static const List<AppIconOption> options = [
    AppIconOption(
      id: 'a',
      name: 'Kuncup Mawar',
      desc: 'Mawar mekar di saku — lembut dan elegan.',
      asset: 'assets/icons/icon_a.png',
    ),
    AppIconOption(
      id: 'b',
      name: 'Bulan Mutiara',
      desc: 'Bulan sabit memangku mutiara — tenang.',
      asset: 'assets/icons/icon_b.png',
    ),
    AppIconOption(
      id: 'c',
      name: 'A Azha',
      desc: 'Inisial Azha yang manis.',
      asset: 'assets/icons/icon_c.png',
    ),
  ];

  Future<String> getCurrentIcon() async {
    try {
      final v = await _channel.invokeMethod<String>('getCurrentIcon');
      return v ?? 'a';
    } on PlatformException {
      return 'a';
    } on MissingPluginException {
      return 'a';
    }
  }

  /// Ganti ikon. Mengembalikan true bila channel berhasil dipanggil.
  /// Catatan: Android me-restart activity — UI Flutter dibangun ulang otomatis.
  Future<bool> setIcon(String id) async {
    try {
      await _channel.invokeMethod('setIcon', {'name': id});
      return true;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}

class AppIconOption {
  const AppIconOption({
    required this.id,
    required this.name,
    required this.desc,
    required this.asset,
  });

  final String id;
  final String name;
  final String desc;
  final String asset;
}
