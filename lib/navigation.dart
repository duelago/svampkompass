import 'dart:math' as math;

/// Storcirkelbäring från punkt 1 till punkt 2, i grader 0–360 medurs.
///
/// Referensen är **geografisk** nord, inte magnetisk. Den som jämför värdet
/// mot en magnetkompass måste först lägga på den lokala missvisningen.
double bearingBetween(
  double latitude1,
  double longitude1,
  double latitude2,
  double longitude2,
) {
  final phi1 = latitude1 * math.pi / 180;
  final phi2 = latitude2 * math.pi / 180;
  final deltaLambda = (longitude2 - longitude1) * math.pi / 180;
  final y = math.sin(deltaLambda) * math.cos(phi2);
  final x =
      math.cos(phi1) * math.sin(phi2) -
      math.sin(phi1) * math.cos(phi2) * math.cos(deltaLambda);
  return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
}

/// Avstånd för visning: hela meter under en kilometer, annars en decimal.
String formatDistance(double meters) => meters < 1000
    ? '${meters.round()} m'
    : '${(meters / 1000).toStringAsFixed(1)} km';
