import 'repository.dart';

/// FASE 2 — HOOK SINKRONISASI ANTAR-DEVICE.
///
/// Fase 1 (sekarang): semua data di SQLite lokal, tidak ada network.
/// Interface ini adalah kontrak yang akan diimplementasikan saat backend
/// sync dibangun, TANPA mengubah satu pun screen/provider.
///
/// Rencana implementasi fase 2 (lihat README):
/// - `HttpSyncRepository implements SyncRepository`
/// - Setiap tabel punya kolom `updated_at` + `deleted` (soft delete)
///   agar push/pull bisa merge per-record (last-write-wins).
/// - `push()`: kirim record yang berubah sejak `last_sync` ke server.
/// - `pull()`: ambil perubahan server, merge ke SQLite lokal.
/// - Konflik: last-write-wins berdasarkan `updated_at`; transaksi
///   tidak pernah di-merge otomatis — duplikat dicegah via idempotent id.
/// - Auth: token per-device yang disimpan di secure storage.
///
/// Sampai saat itu, seluruh aplikasi memakai [LocalRepository].
enum SyncStatus { idle, syncing, error, offline }

abstract class SyncRepository implements Repository {
  /// Kirim perubahan lokal ke server.
  Future<void> push();

  /// Tarik perubahan server ke lokal.
  Future<void> pull();

  /// Status sinkronisasi untuk indikator UI.
  Stream<SyncStatus> get status;

  /// Waktu sinkronisasi terakhir yang berhasil (null = belum pernah).
  Future<DateTime?> get lastSyncedAt;
}
