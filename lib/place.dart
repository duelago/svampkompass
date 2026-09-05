import 'dart:convert';

/// En sparad plats: hempositionen eller ett svampställe.
class Place {
  const Place({
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  final String name;
  final double latitude;
  final double longitude;

  Map<String, dynamic> toJson() => {
    'name': name,
    'lat': latitude,
    'lng': longitude,
  };

  /// Tolkar en post, eller ger null om den inte går att lita på.
  ///
  /// Sparad data är det enda i appen användaren inte kan återskapa, så en
  /// trasig post ska aldrig kunna hindra resten från att läsas in.
  static Place? tryParse(Object? value) {
    if (value is! Map) return null;
    final name = value['name'];
    final latitude = value['lat'];
    final longitude = value['lng'];
    if (name is! String || latitude is! num || longitude is! num) return null;
    if (latitude.isNaN || longitude.isNaN) return null;
    if (latitude < -90 || latitude > 90) return null;
    if (longitude < -180 || longitude > 180) return null;
    return Place(
      name: name,
      latitude: latitude.toDouble(),
      longitude: longitude.toDouble(),
    );
  }
}

/// Läser den sparade hempositionen. Trasig eller saknad data ger null.
Place? decodePlace(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  try {
    return Place.tryParse(jsonDecode(raw));
  } on FormatException {
    return null;
  }
}

/// Läser sparade svampställen och hoppar över poster som inte går att tolka.
List<Place> decodePlaces(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  final Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException {
    return const [];
  }
  if (decoded is! List) return const [];
  return [for (final item in decoded) ?Place.tryParse(item)];
}
