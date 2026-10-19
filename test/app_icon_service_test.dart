import 'package:flutter_test/flutter_test.dart';
import 'package:saku/src/services/app_icon_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppIconService.options', () {
    test('ada 3 varian dengan id unik', () {
      final ids = AppIconService.options.map((o) => o.id).toList();
      expect(ids, ['a', 'b', 'c']);
      expect(ids.toSet().length, 3);
    });

    test('setiap opsi punya nama, deskripsi, dan asset', () {
      for (final o in AppIconService.options) {
        expect(o.name.isNotEmpty, true);
        expect(o.desc.isNotEmpty, true);
        expect(o.asset, startsWith('assets/icons/'));
        expect(o.asset, endsWith('.png'));
      }
    });

    test('opsi default adalah Kuncup Mawar', () {
      expect(AppIconService.options.first.id, 'a');
      expect(AppIconService.options.first.name, 'Kuncup Mawar');
    });
  });

  group('AppIconService channel (tanpa native)', () {
    test('getCurrentIcon fallback ke a bila channel tidak ada', () async {
      // Di unit test tidak ada MethodChannel native -> MissingPluginException -> 'a'.
      expect(await AppIconService.instance.getCurrentIcon(), 'a');
    });

    test('setIcon mengembalikan false bila channel tidak ada', () async {
      expect(await AppIconService.instance.setIcon('b'), isFalse);
    });
  });
}
