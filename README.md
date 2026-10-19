# Saku — aplikasi budgeting pribadi

Aplikasi budgeting Flutter untuk pemakaian pribadi. Terinspirasi fitur
Budggt (multi-dompet, wizard budget, health score, target nabung) dan
Cashew (utang-piutang, transaksi terjadwal, memori judul, budget
multi-periode, notifikasi, kunci biometrik), tapi **seluruh kode
ditulis fresh** — clean-room, tanpa menyalin apa pun.

Prinsip:
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

## Fitur

- Dompet multi-tipe (tunai, bank, e-wallet, kartu kredit, paylater)
- Wizard onboarding 6 langkah (metode 50/30/20 atau nominal tetap)
- Quick-add <10 detik + foto struk (OCR stub, server Tesseract di fase 2)
- Transfer antar-dompet tanpa double-count (dikunci unit test)
- Transaksi rutin/recurring (langganan, cicilan, gaji)
- **Cari & filter transaksi**: teks, rentang tanggal, kategori, dompet,
  tipe, min/maks nominal
- **Kategori custom**: tambah/edit/nonaktifkan/hapus, pilih ikon & warna
- **Utang-piutang**: catat utang/ke orang, cicilan, jatuh tempo,
  saldo dompet ikut bergerak
- **Transaksi terjadwal**: catat sekarang, jadi transaksi beneran
  saat ditandai dibayar (+ pengingat)
- **Memori judul**: ketik judul yang pernah dipakai → kategori
  disarankan otomatis
- **Budget multi-periode**: mingguan, bulanan, atau rentang tanggal bebas
- **Notifikasi lokal**: budget 80%/100%, jadwal jatuh tempo, utang
  ≤3 hari / terlewat, pengingat harian jam 8 pagi (semua bisa dimatikan)
- **Kunci biometrik**: sidik jari / PIN perangkat saat buka aplikasi
  (terpisah dari mode privasi yang menyamarkan nominal)
- Financial Health Score 0–100, insight engine lokal, "Tanya Kuncung"
- Export CSV/JSON

## Struktur folder

```
lib/
  main.dart                  # entry point (ProviderScope)
  src/
    config/
      app_config.dart        # SATU konstanta nama aplikasi + versi
      app_theme.dart         # tema dark-first + light
      seed_data.dart         # kategori Indonesia bawaan
    models/                  # wallet, category, budget (+periode),
                             # transaction, debt, upcoming, goal,
                             # recurring — toMap/fromMap manual
    data/
      app_database.dart      # skema SQLite v2 (+migrasi v1→v2)
      repository.dart        # ABSTRAKSI: kontrak penyimpanan
      local_repository.dart  # implementasi SQLite
      sync_repository.dart   # INTERFACE STUB sinkronisasi (fase 2)
    logic/                   # murni Dart, tanpa Flutter — unit-testable
      money.dart             # format IDR, monthKey, newId, parse input
      totals.dart            # ANTI DOUBLE-COUNT: transfer dikecualikan
      health_score.dart      # Financial Health Score 0–100
      insight_engine.dart    # burn rate, proyeksi, anomali, dst.
      debt_logic.dart        # status/sisa/validasi utang, sort, overdue
      title_memory.dart      # normalisasi + suggest judul→kategori
      budget_periods.dart    # rentang weekly/monthly/custom, spent
      tx_filter.dart         # filter transaksi (query+rentang+kategori…)
      notification_rules.dart# aturan kapan notifikasi muncul
    services/
      ocr_service.dart       # interface OCR + STUB lokal + hook fase 2
      export_service.dart    # export CSV/JSON -> share sheet
      notification_service.dart # flutter_local_notifications wrapper
      biometric_service.dart    # local_auth wrapper
    state/
      providers.dart         # Riverpod: repo, preferensi, data
    ui/
      app.dart, splash_screen.dart (biometrik + cek notifikasi),
      home_screen.dart       # 6 tab: Beranda, Transaksi, Budget,
                             # Target, Dompet, Utang
      dashboard_screen.dart
      transactions_screen.dart  # cari + filter lengkap
      quick_add_sheet.dart   # quick-add + saran kategori + jadwalkan
      budgets_screen.dart    # budget multi-periode
      debts_screen.dart      # utang-piutang + terjadwal (2 tab)
      categories_screen.dart # kelola kategori custom
      goals_screen.dart
      wallets_screen.dart
      recurrings_screen.dart
      settings_screen.dart   # privasi, biometrik, notifikasi, kategori
      onboarding/            # wizard 6 langkah
      widgets/masked_amount.dart
test/
  transfer_exclusion_test.dart
  health_score_test.dart
  insight_engine_test.dart
  debt_logic_test.dart
  title_memory_test.dart
  budget_periods_test.dart
  notification_rules_test.dart  # termasuk TxFilter
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
  *sudah* bisa dilampirkan ke transaksi.
- **Sync antar-device**: implementasikan `SyncRepository`
  (`data/sync_repository.dart`) — butuh kolom `updated_at` + soft-delete
  per tabel untuk merge last-write-wins. UI/provider tidak perlu berubah.
- Widget home-screen, multi-bahasa.

## Catatan platform

- **Notifikasi terjadwal** (`scheduleDailyCheck`) memakai alarm
  inexact agar tidak butuh izin `SCHEDULE_EXACT_ALARM`. Jadwal hilang
  setelah reboot sampai aplikasi dibuka lagi (tidak ada receiver boot).
- **Kunci biometrik** memakai `biometricOnly: false` — jatuh ke
  PIN/pola perangkat bila biometrik tidak tersedia, jadi tidak terkunci.
