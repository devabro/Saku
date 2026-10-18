# Saku — aplikasi budgeting pribadi (fase 1: local-first)

Aplikasi budgeting Flutter untuk pemakaian pribadi. Terinspirasi fitur
Budggt (multi-dompet, wizard budget, health score, target nabung), tapi
**seluruh kode ditulis fresh** — clean-room, tanpa menyalin apa pun.

Prinsip fase 1:
- **Local-first**: semua data di SQLite perangkat. Nol network call.
- **Tanpa iklan, tanpa analytics**, tanpa akun.
- **Fitur "PRO" ala Budggt dibuat gratis**: insight engine lokal
  (tanpa API) + tombol "Tanya Kuncung" (ringkasan teks siap share).
- Bahasa Indonesia, dark-first.

> **Ganti nama aplikasi**: cukup ubah `AppConfig.appName` di
> `lib/src/config/app_config.dart`. ("Saku" adalah working title.)

## Cara jalan

Butuh Flutter stable (teruji di 3.47.7).

```bash
cd budget-app
flutter pub get
flutter run            # ke HP/emulator
flutter test           # unit test
flutter analyze        # harus 0 issue
```

Build APK release:

```bash
flutter build apk --release
```

## Struktur folder

```
lib/
  main.dart                  # entry point (ProviderScope)
  src/
    config/
      app_config.dart        # SATU konstanta nama aplikasi + versi
      app_theme.dart         # tema dark-first + light
      seed_data.dart         # kategori Indonesia bawaan
    models/                  # wallet, category, budget, transaction,
                             # goal, recurring — toMap/fromMap manual
    data/
      app_database.dart      # skema SQLite v1
      repository.dart        # ABSTRAKSI: kontrak penyimpanan
      local_repository.dart  # implementasi SQLite (fase 1)
      sync_repository.dart   # INTERFACE STUB sinkronisasi (fase 2)
    logic/                   # murni Dart, tanpa Flutter — unit-testable
      money.dart             # format IDR, monthKey, newId, parse input
      totals.dart            # ANTI DOUBLE-COUNT: transfer dikecualikan
      health_score.dart      # Financial Health Score 0–100 (formula di komen)
      insight_engine.dart    # burn rate, proyeksi, anomali, savings rate,
                             # + buildKuncungSummary() untuk "Tanya Kuncung"
    services/
      ocr_service.dart       # interface OCR + STUB lokal + hook fase 2
      export_service.dart    # export CSV/JSON -> share sheet
    state/
      providers.dart         # Riverpod: repo, preferensi, data per bulan
    ui/
      app.dart, splash_screen.dart, home_screen.dart
      dashboard_screen.dart  # skor, net worth, tren (fl_chart), breakdown,
                             # vs bulan lalu, insight, Tanya Kuncung
      transactions_screen.dart
      quick_add_sheet.dart   # catat <10 detik; dipakai juga edit & transfer
      budgets_screen.dart    # peringatan 80% kuning / 100%+ merah
      goals_screen.dart
      wallets_screen.dart
      recurrings_screen.dart # langganan/cicilan/gaji otomatis
      settings_screen.dart   # privasi, tema, export, tentang
      onboarding/            # wizard 6 langkah
      widgets/masked_amount.dart  # tampil •••••• saat privacy mode
test/
  transfer_exclusion_test.dart  # transfer TIDAK dihitung belanja/masuk
  health_score_test.dart
  insight_engine_test.dart
```

## Aturan kunci yang dikunci test

1. **Transfer antar dompet sendiri bukan pengeluaran/pemasukan**
   (`totals.dart` + `transfer_exclusion_test.dart`). Transfer tetap
   menggerakkan saldo dua dompet — bayar tagihan kartu kredit = transfer
   bank → kartu kredit, yang *mengurangi* utang.
2. **Dompet utang** (kartu kredit, paylater): balance = jumlah utang.
   Net worth = aset − utang.
3. **Health score** = 40% kepatuhan budget + 25% savings rate +
   20% stabilitas belanja + 15% progres target. Bobot tunable di
   `health_score.dart`; formula didokumentasikan di komentar.

## Fase 2 (belum dikerjakan — hook sudah disiapkan)

- **OCR struk server-side**: implementasikan `ServerTesseractOcrService`
  (kerangka TODO ada di `services/ocr_service.dart`) yang POST ke
  endpoint Tesseract, lalu ganti `ocrServiceProvider`. Foto struk
  *sudah* bisa dilampirkan ke transaksi sejak fase 1.
- **Sync antar-device**: implementasikan `SyncRepository`
  (`data/sync_repository.dart`) — butuh kolom `updated_at` + soft-delete
  per tabel untuk merge last-write-wins. UI/provider tidak perlu berubah.
- Kategori custom, PIN/biometrik, widget home-screen, multi-bahasa.
