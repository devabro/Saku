import 'package:flutter_test/flutter_test.dart';
import 'package:saku/src/logic/title_memory.dart';

void main() {
  group('TitleMemory.normalize', () {
    test('lowercase + trim', () {
      expect(TitleMemory.normalize('  Kopi Kenangan  '), 'kopi kenangan');
      expect(TitleMemory.normalize('KOPi'), 'kopi');
    });
  });

  group('TitleMemory.suggest', () {
    final memory = {
      'kopi kenangan': 'cat_makan',
      'bensin shell': 'cat_transport',
      'netflix': 'cat_hiburan',
    };

    test('cocok persis (case-insensitive)', () {
      expect(TitleMemory.suggest(memory, 'Kopi Kenangan'), 'cat_makan');
    });

    test('awalan cocok', () {
      expect(TitleMemory.suggest(memory, 'kopi'), 'cat_makan');
    });

    test('query lebih panjang dari judul tersimpan', () {
      expect(
          TitleMemory.suggest(memory, 'kopi kenangan grande'), 'cat_makan');
    });

    test('mengandung cocok', () {
      expect(
          TitleMemory.suggest(memory, 'nsin sh'), 'cat_transport');
    });

    test('tidak cocok = null', () {
      expect(TitleMemory.suggest(memory, 'sepatu baru'), isNull);
    });

    test('query kosong = null', () {
      expect(TitleMemory.suggest(memory, '   '), isNull);
    });
  });

  group('TitleMemory.suggestAll', () {
    test('urutan: persis > awalan > mengandung, tanpa duplikat', () {
      final memory = {
        'kopi kenangan': 'cat_a',
        'kopi tubruk': 'cat_b',
        'toko kopi jaya': 'cat_c',
      };
      final out = TitleMemory.suggestAll(memory, 'kopi kenangan');
      expect(out.first, 'cat_a');
      expect(out.toSet().length, out.length);
      expect(out.length, lessThanOrEqualTo(3));
    });

    test('limit dihormati', () {
      final memory = {
        for (var i = 0; i < 10; i++) 'kopi $i': 'cat_$i',
      };
      expect(TitleMemory.suggestAll(memory, 'kopi').length,
          lessThanOrEqualTo(3));
    });
  });
}
