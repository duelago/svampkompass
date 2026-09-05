import 'package:flutter_test/flutter_test.dart';
import 'package:svampkompass/declination.dart';

// Facit kommer från NOAA:s egna WMM2025_TestValues.txt, som följer med den
// officiella koefficientutgåvan. Går de här testerna sönder är det antingen
// koefficienterna eller beräkningen som ändrats, inte något i appen.
//
// Toleransen är 0,3 grader. Paketet dokumenterar sig som "roughly within
// 0.2 degrees of test values", och för en pil i en skog spelar tiondelar
// ingen roll -- det var de sex till nio hela graderna som var problemet.

/// NOAA anger tidpunkten som decimalår. Paketet räknar om DateTime på samma
/// sätt, så konverteringen måste matcha för att jämförelsen ska bli rättvis.
DateTime dateFromDecimalYear(double decimalYear) {
  final year = decimalYear.floor();
  final leap = year % 400 == 0 || (year % 4 == 0 && year % 100 != 0);
  final millisecondsInYear = (leap ? 366 : 365) * 24 * 60 * 60 * 1000;
  final offset = ((decimalYear - year) * millisecondsInYear).round();
  return DateTime(year, 1, 1).add(Duration(milliseconds: offset));
}

void main() {
  group('magneticDeclination mot NOAA:s testvärden', () {
    // (decimalår, höjd i km, latitud, longitud, förväntad missvisning)
    const cases = <(double, double, double, double, double)>[
      (2025.000000, 28, 89, -121, -99.77),
      (2025.500000, 6, -36, -137, 20.28),
      (2026.000000, 74, -57, 3, -22.51),
      (2026.500000, 14, 0, 80, -3.10),
      (2027.000000, 37, -66, -5, -17.22),
      (2027.500000, 8, 62, 53, 19.39),
      (2028.000000, 49, 20, 167, 5.10),
      (2028.500000, 28, 54, -120, 15.43),
      (2029.000000, 95, -60, -59, 8.58),
      (2029.500000, 31, 13, -132, 9.04),
      (2027.000000, 12, -63, 178, 57.87),
      (2026.000000, 69, 23, 63, 1.17),
      (2027.500000, 96, -46, -85, 17.93),
      (2029.500000, 64, 22, -132, 10.23),
      (2025.000000, 94, -29, -110, 15.74),
      (2025.500000, 63, 26, 81, 0.51),
    ];

    for (final (year, altitude, latitude, longitude, expected) in cases) {
      test('år $year, $latitude°, $longitude°, $altitude km', () {
        expect(
          magneticDeclination(
            latitude,
            longitude,
            at: dateFromDecimalYear(year),
            altitudeKilometres: altitude,
          ),
          closeTo(expected, 0.3),
        );
      });
    }
  });

  group('missvisningen i Sverige', () {
    test('ligger på några grader öster om geografisk nord', () {
      // Det är precis det här felet issue #2 handlade om: pilen pekade
      // så här många grader fel så länge man stod stilla.
      final stockholm = magneticDeclination(59.3293, 18.0686);
      expect(stockholm, greaterThan(3));
      expect(stockholm, lessThan(15));
    });

    test('växer norrut genom landet', () {
      final malmo = magneticDeclination(55.6050, 13.0038);
      final kiruna = magneticDeclination(67.8558, 20.2253);
      expect(kiruna, greaterThan(malmo));
    });
  });

  group('trueHeadingFrom', () {
    test('lägger på missvisningen', () {
      expect(trueHeadingFrom(0, 7.5), closeTo(7.5, 1e-9));
      expect(trueHeadingFrom(90, -3.25), closeTo(86.75, 1e-9));
    });

    test('håller sig inom 0 till 360 åt båda hållen', () {
      expect(trueHeadingFrom(357, 7), closeTo(4, 1e-9));
      expect(trueHeadingFrom(2, -7), closeTo(355, 1e-9));
    });
  });
}
