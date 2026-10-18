/// Memori judul → kategori. Judul dinormalisasi (lowercase + trim)
/// sebelum disimpan/dicari, jadi "Kopi Kenangan" cocok dengan
/// "kopi kenangan  ". Murni Dart — unit-testable.
class TitleMemory {
  TitleMemory._();

  /// Normalisasi judul untuk kunci pencocokan.
  static String normalize(String title) => title.trim().toLowerCase();

  /// Cari kategori untuk [query]. Urutan: cocok persis dulu,
  /// lalu awalan (query adalah awalan judul tersimpan atau sebaliknya),
  /// lalu mengandung. Mengembalikan categoryId atau null.
  static String? suggest(Map<String, String> memory, String query) {
    final q = normalize(query);
    if (q.isEmpty) return null;
    if (memory.containsKey(q)) return memory[q];
    // Awalan: "kopi" cocok dengan "kopi kenangan".
    for (final e in memory.entries) {
      if (e.key.startsWith(q) || q.startsWith(e.key)) return e.value;
    }
    // Mengandung.
    for (final e in memory.entries) {
      if (e.key.contains(q) || q.contains(e.key)) return e.value;
    }
    return null;
  }

  /// Beberapa saran (maks [limit]), untuk ditampilkan sebagai chip.
  static List<String> suggestAll(
    Map<String, String> memory,
    String query, {
    int limit = 3,
  }) {
    final q = normalize(query);
    if (q.isEmpty) return [];
    final exact = <String>[];
    final prefix = <String>[];
    final contains = <String>[];
    for (final e in memory.entries) {
      if (e.key == q) {
        exact.add(e.value);
      } else if (e.key.startsWith(q) || q.startsWith(e.key)) {
        prefix.add(e.value);
      } else if (e.key.contains(q) || q.contains(e.key)) {
        contains.add(e.value);
      }
    }
    final out = <String>[];
    for (final bucket in [exact, prefix, contains]) {
      for (final id in bucket) {
        if (!out.contains(id) && out.length < limit) out.add(id);
      }
    }
    return out;
  }
}
