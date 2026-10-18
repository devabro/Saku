import 'package:flutter_test/flutter_test.dart';
import 'package:saku/src/logic/streak.dart';

void main() {
  // "Hari ini" = Rabu 2026-10-21.
  final today = DateTime(2026, 10, 21, 15, 30);

  group('Streak.calc', () {
    test('kosong = 0', () {
      expect(Streak.calc([], today), 0);
    });

    test('cuma hari ini = 1', () {
      expect(Streak.calc([today], today), 1);
    });

    test('3 hari beruntun sampai kemarin = 3 (hari ini belum catat)', () {
      final dates = [
        DateTime(2026, 10, 20),
        DateTime(2026, 10, 19),
        DateTime(2026, 10, 18),
      ];
      expect(Streak.calc(dates, today), 3);
    });

    test('bolong sehari memutus rantai', () {
      final dates = [
        DateTime(2026, 10, 21),
        DateTime(2026, 10, 20),
        // 19 bolong
        DateTime(2026, 10, 18),
        DateTime(2026, 10, 17),
      ];
      expect(Streak.calc(dates, today), 2);
    });

    test('transaksi ganda sehari tetap dihitung 1 hari', () {
      final dates = [
        DateTime(2026, 10, 21, 8),
        DateTime(2026, 10, 21, 12),
        DateTime(2026, 10, 21, 20),
      ];
      expect(Streak.calc(dates, today), 1);
    });

    test('terakhir catat 2 hari lalu = 0 (putus)', () {
      final dates = [DateTime(2026, 10, 19)];
      expect(Streak.calc(dates, today), 0);
    });

    test('jam diabaikan, cuma tanggal', () {
      final dates = [
        DateTime(2026, 10, 21, 23, 59),
        DateTime(2026, 10, 20, 0, 1),
      ];
      expect(Streak.calc(dates, today), 2);
    });
  });

  group('Streak.message', () {
    test('copy hangat per milestone', () {
      expect(Streak.message(0), contains('Yuk'));
      expect(Streak.message(1), contains('Hari pertama'));
      expect(Streak.message(7), contains('Seminggu'));
      expect(Streak.message(30), contains('Sebulan'));
    });
  });
}
