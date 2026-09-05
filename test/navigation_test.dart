import 'package:flutter_test/flutter_test.dart';
import 'package:svampkompass/navigation.dart';

// Facit är framräknat med samma storcirkelformel oberoende av appen, mot
// geografisk nord. Se issue #2: kompasspilen jämför de här värdena med
// flutter_compass, som ger magnetisk nord, och blir därför fel när man
// står stilla.

void main() {
  group('bearingBetween', () {
    test('pekar rakt norrut, österut, söderut och västerut från ekvatorn', () {
      expect(bearingBetween(0, 0, 1, 0), closeTo(0, 0.001));
      expect(bearingBetween(0, 0, 0, 1), closeTo(90, 0.001));
      expect(bearingBetween(0, 0, -1, 0), closeTo(180, 0.001));
      expect(bearingBetween(0, 0, 0, -1), closeTo(270, 0.001));
    });

    test('Stockholm till Göteborg är sydväst', () {
      expect(
        bearingBetween(59.3293, 18.0686, 57.7089, 11.9746),
        closeTo(245.6378, 0.001),
      );
    });

    test('motsatt riktning skiljer sig från returbäringen', () {
      // Storcirklar är inte symmetriska: tillbaka är inte 245.64 - 180.
      // Testet låser fast det, så att ingen "förenklar" bort formeln.
      final ut = bearingBetween(59.3293, 18.0686, 57.7089, 11.9746);
      final hem = bearingBetween(57.7089, 11.9746, 59.3293, 18.0686);
      expect(hem, closeTo(60.4389, 0.001));
      expect((ut - 180 - hem).abs(), greaterThan(4));
    });

    test('ligger alltid i intervallet 0 till 360', () {
      for (final longitud in [-179.0, -90.0, -0.1, 0.0, 0.1, 90.0, 179.0]) {
        final v = bearingBetween(59.3, 18.0, 59.4, longitud);
        expect(v, greaterThanOrEqualTo(0));
        expect(v, lessThan(360));
      }
    });

    test('samma punkt ger noll i stället för NaN', () {
      expect(bearingBetween(59.3293, 18.0686, 59.3293, 18.0686), 0);
    });
  });

  group('formatDistance', () {
    test('under en kilometer visas i hela meter', () {
      expect(formatDistance(0), '0 m');
      expect(formatDistance(4.4), '4 m');
      expect(formatDistance(999.4), '999 m');
    });

    test('från en kilometer visas med en decimal', () {
      expect(formatDistance(1000), '1.0 km');
      expect(formatDistance(396893), '396.9 km');
    });

    test('gränsen vid 1000 m hoppar inte över något värde', () {
      expect(formatDistance(999.6), '1000 m');
      expect(formatDistance(1000), '1.0 km');
    });
  });
}
