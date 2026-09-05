import 'package:flutter_test/flutter_test.dart';
import 'package:svampkompass/place.dart';

// Sparade platser är det enda i appen som inte går att återskapa. Testerna
// nedan handlar därför inte om att tolka rätt data rätt, utan om att fel
// data aldrig ska kunna hindra resten från att läsas in.

void main() {
  group('decodePlace', () {
    test('läser en giltig post', () {
      final place = decodePlace('{"name":"Startplats","lat":59.3,"lng":18.1}');
      expect(place?.name, 'Startplats');
      expect(place?.latitude, 59.3);
      expect(place?.longitude, 18.1);
    });

    test('ger null för saknad, tom och trasig data', () {
      expect(decodePlace(null), isNull);
      expect(decodePlace(''), isNull);
      expect(decodePlace('{"name":"Trunkerad","lat":59.3'), isNull);
      expect(decodePlace('inte json alls'), isNull);
    });

    test('ger null när fält saknas eller har fel typ', () {
      expect(decodePlace('{"lat":59.3,"lng":18.1}'), isNull);
      expect(decodePlace('{"name":"X","lng":18.1}'), isNull);
      expect(decodePlace('{"name":42,"lat":59.3,"lng":18.1}'), isNull);
      expect(decodePlace('{"name":"X","lat":"59.3","lng":18.1}'), isNull);
    });

    test('avvisar koordinater utanför jordklotet', () {
      expect(decodePlace('{"name":"X","lat":91,"lng":18.1}'), isNull);
      expect(decodePlace('{"name":"X","lat":59.3,"lng":181}'), isNull);
    });

    test('accepterar heltalskoordinater', () {
      expect(decodePlace('{"name":"X","lat":59,"lng":18}')?.latitude, 59.0);
    });
  });

  group('decodePlaces', () {
    test('läser en lista i ordning', () {
      final spots = decodePlaces(
        '[{"name":"A","lat":59.0,"lng":18.0},'
        '{"name":"B","lat":60.0,"lng":17.0}]',
      );
      expect(spots.map((s) => s.name), ['A', 'B']);
    });

    test('hoppar över trasiga poster men behåller resten', () {
      // Det här är hela poängen: en dålig post ska inte kosta de andra.
      final spots = decodePlaces(
        '[{"name":"A","lat":59.0,"lng":18.0},'
        '{"name":"Trasig"},'
        'null,'
        '"inte ett objekt",'
        '{"name":"B","lat":60.0,"lng":17.0}]',
      );
      expect(spots.map((s) => s.name), ['A', 'B']);
    });

    test('ger tom lista för saknad, tom och trasig data', () {
      expect(decodePlaces(null), isEmpty);
      expect(decodePlaces(''), isEmpty);
      expect(decodePlaces('{"name":"inte en lista"}'), isEmpty);
      expect(decodePlaces('[{"name":"A","lat":59.0'), isEmpty);
    });
  });
}
