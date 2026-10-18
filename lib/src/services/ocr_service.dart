/// OCR struk belanja.
///
/// Fase 1: foto struk bisa dilampirkan ke transaksi, tapi ekstraksi item
/// otomatis BELUM jalan — [LocalStubOcrService] hanya mengembalikan hasil
/// kosong yang jujur (tidak mengarang data).
///
/// FASE 2 — HOOK: implementasikan [ServerTesseractOcrService] yang POST
/// gambar ke endpoint backend (`POST /ocr`, lihat README fase 2) lalu
/// parse respons JSON menjadi [OcrResult]. Ganti provider `ocrServiceProvider`
/// ke implementasi server tanpa mengubah UI.
class OcrLineItem {
  final String label;
  final int amount;

  const OcrLineItem({required this.label, required this.amount});
}

class OcrResult {
  final List<OcrLineItem> items;
  final int? total;
  final String rawText;

  /// True jika hasil berasal dari stub (bukan OCR beneran).
  final bool fromStub;

  const OcrResult({
    this.items = const [],
    this.total,
    this.rawText = '',
    this.fromStub = true,
  });
}

abstract class OcrService {
  /// Scan foto struk di [imagePath], kembalikan item + total terdeteksi.
  Future<OcrResult> scanReceipt(String imagePath);
}

/// Stub fase 1: tidak melakukan OCR. Mengembalikan hasil kosong agar UI
/// bisa menampilkan pesan "OCR server belum aktif" alih-alih data palsu.
class LocalStubOcrService implements OcrService {
  @override
  Future<OcrResult> scanReceipt(String imagePath) async {
    return const OcrResult(
      rawText: 'OCR belum aktif di fase 1. Foto tersimpan sebagai lampiran.',
      fromStub: true,
    );
  }
}

// TODO(phase-2): implementasikan OCR server-side.
//
// class ServerTesseractOcrService implements OcrService {
//   ServerTesseractOcrService(this.baseUrl);
//   final String baseUrl; // mis. https://saku-api.example.com
//
//   @override
//   Future<OcrResult> scanReceipt(String imagePath) async {
//     // 1. POST multipart ke `$baseUrl/ocr` dengan file gambar.
//     // 2. Parse JSON: { "items": [{"label": "...", "amount": 25000}],
//     //                  "total": 75000, "raw_text": "..." }
//     // 3. Kembalikan OcrResult(items: ..., total: ..., fromStub: false).
//   }
// }
