import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'navigation.dart';

const _chanterelle = Color(0xffff8c00);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const SvampkompassApp());
}

class SvampkompassApp extends StatelessWidget {
  const SvampkompassApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Svampkompass',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff315c34)),
    ),
    home: const CompassScreen(),
  );
}

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
  factory Place.fromJson(Map<String, dynamic> json) => Place(
    name: json['name'] as String,
    latitude: (json['lat'] as num).toDouble(),
    longitude: (json['lng'] as num).toDouble(),
  );
}

/// En radering som fortfarande går att ångra.
class _Deletion {
  const _Deletion(this.place, this.index, this.wasSelected);
  final Place place;
  final int index;
  final bool wasSelected;
}

class CompassScreen extends StatefulWidget {
  const CompassScreen({super.key});
  @override
  State<CompassScreen> createState() => _CompassScreenState();
}

class _CompassScreenState extends State<CompassScreen> {
  static const _homeKey = 'saved_home_place';
  static const _spotsKey = 'mushroom_spots';
  Position? _position;
  Place? _home;
  List<Place> _spots = [];
  Place? _selectedSpot;
  double _heading = 0;
  double? _courseHeading;
  String? _error;
  bool _loading = true;
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<CompassEvent>? _compassSubscription;
  final List<_Deletion> _pendingDeletions = [];

  @override
  void initState() {
    super.initState();
    _loadAndStart();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _compassSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadAndStart() async {
    final prefs = await SharedPreferences.getInstance();
    final homeString = prefs.getString(_homeKey);
    final spotsString = prefs.getString(_spotsKey);
    if (mounted) {
      setState(() {
        if (homeString != null) {
          _home = Place.fromJson(
            jsonDecode(homeString) as Map<String, dynamic>,
          );
        }
        if (spotsString != null) {
          _spots = (jsonDecode(spotsString) as List<dynamic>)
              .map((item) => Place.fromJson(item as Map<String, dynamic>))
              .toList();
          _selectedSpot = _spots.isEmpty ? null : _spots.first;
        }
      });
    }
    _compassSubscription = FlutterCompass.events?.listen(_updateHeading);
    await _startLocation();
  }

  void _updateHeading(CompassEvent event) {
    final value = event.heading;
    if (value != null && mounted) {
      setState(() => _heading = value % 360);
    }
  }

  Future<void> _startLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _fail('Platstjänster är avstängda.');
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _fail('Tillåt platsåtkomst för att använda kompassen.');
        return;
      }
      final first = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
        ),
      );
      _updatePosition(first);
      _positionSubscription?.cancel();
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 2,
        ),
      ).listen(_updatePosition);
    } catch (_) {
      // Behörighetskontrollerna ovan kan också kasta, till exempel på
      // enheter utan Play Services. Utan det här blocket lämnades appen
      // på en laddningssnurra utan felmeddelande och utan väg vidare.
      _fail('Kunde inte hämta din position än.');
    } finally {
      // Sista utvägen: lämna aldrig kvar spinnern, oavsett hur vi tog oss ut.
      if (mounted && _loading) {
        setState(() => _loading = false);
      }
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _error = message;
      _loading = false;
    });
  }

  void _updatePosition(Position position) {
    if (!mounted) return;
    // GPS:ens course over ground är den verkliga riktningen som användaren
    // färdas i. När man går är den stabilare än magnetometern och är därför
    // den primära referensen för vägvisaren.
    final hasCourse =
        position.speed >= .7 && position.heading >= 0 && position.heading < 360;
    setState(() {
      _position = position;
      _courseHeading = hasCourse ? position.heading : null;
      _loading = false;
      _error = null;
    });
  }

  Future<void> _setHome() async {
    final position = _position;
    if (position == null) return;
    final previous = _home;
    if (previous != null) {
      // Hempositionen är det appen finns för. Ett felklick på hus-ikonen
      // ska inte kunna ersätta bilens position med var man råkar stå.
      final meters = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        previous.latitude,
        previous.longitude,
      );
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Ersätt hempositionen?'),
          content: Text(
            'Du har redan en hemposition ${formatDistance(meters)} härifrån. '
            'Ersätter du den med platsen du står på nu går den gamla inte '
            'att få tillbaka.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Behåll den gamla'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Ersätt'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    final place = Place(
      name: 'Startplats',
      latitude: position.latitude,
      longitude: position.longitude,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_homeKey, jsonEncode(place.toJson()));
    if (mounted) setState(() => _home = place);
  }

  Future<void> _saveSpots() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _spotsKey,
      jsonEncode(_spots.map((spot) => spot.toJson()).toList()),
    );
  }

  Future<void> _addSpot() async {
    if (_position == null) return;
    final controller = TextEditingController(
      text: 'Svampställe ${_spots.length + 1}',
    );
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Spara svampställe'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Namn på stället'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Avbryt'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Spara'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || !mounted) return;
    final spot = Place(
      name: name,
      latitude: _position!.latitude,
      longitude: _position!.longitude,
    );
    setState(() {
      _spots = [..._spots, spot];
      _selectedSpot = spot;
    });
    await _saveSpots();
  }

  Future<void> _deleteSpot(Place spot) async {
    final index = _spots.indexOf(spot);
    if (index < 0) return;
    final wasSelected = _selectedSpot == spot;
    setState(() {
      _spots = [..._spots]..removeAt(index);
      if (wasSelected) {
        _selectedSpot = _spots.isEmpty ? null : _spots.first;
      }
    });
    await _saveSpots();
    if (!mounted) return;

    // Papperskorgen sitter i samma rad som man trycker på för att välja
    // ställe, så feltryck är att räkna med.
    //
    // Raderingar samlas ihop i stället för att ersätta varandra. Att bara
    // visa en ny SnackBar hade dolt den föregående och tagit med sig dess
    // Ångra, så en snabb andra radering hade gjort den första permanent.
    _pendingDeletions.add(_Deletion(spot, index, wasSelected));
    final pending = List<_Deletion>.of(_pendingDeletions);
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    final snackBar = messenger.showSnackBar(
      SnackBar(
        content: Text(
          pending.length == 1
              ? '${spot.name} borttaget'
              : '${pending.length} ställen borttagna',
        ),
        action: SnackBarAction(
          label: 'Ångra',
          onPressed: () => _restoreDeletions(pending),
        ),
      ),
    );
    // Stängs den för att vi själva visar nästa lever ångra-möjligheten
    // vidare i den nya. Alla andra sätt att stänga innebär att raderingen
    // står fast.
    snackBar.closed.then((reason) {
      if (reason != SnackBarClosedReason.hide) {
        _pendingDeletions.clear();
      }
    });
  }

  Future<void> _restoreDeletions(List<_Deletion> pending) async {
    if (!mounted) return;
    // Stigande ordning, så att varje post hamnar på sitt ursprungliga index.
    final ordered = [...pending]..sort((a, b) => a.index.compareTo(b.index));
    setState(() {
      final spots = [..._spots];
      for (final deletion in ordered) {
        spots.insert(deletion.index.clamp(0, spots.length), deletion.place);
      }
      _spots = spots;
      for (final deletion in ordered) {
        if (deletion.wasSelected) {
          _selectedSpot = deletion.place;
          break;
        }
      }
    });
    _pendingDeletions.clear();
    await _saveSpots();
  }

  double _distanceTo(Place place) => Geolocator.distanceBetween(
    _position!.latitude,
    _position!.longitude,
    place.latitude,
    place.longitude,
  );
  double _bearingTo(Place place) => bearingBetween(
    _position!.latitude,
    _position!.longitude,
    place.latitude,
    place.longitude,
  );

  double _relativeBearing(Place place) =>
      (_bearingTo(place) - (_courseHeading ?? _heading)) * math.pi / 180;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Svampkompass'),
        actions: [
          IconButton(
            onPressed: _position == null ? null : _setHome,
            tooltip: 'Spara ny hemposition',
            icon: const Icon(Icons.home_work_outlined),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ErrorState(message: _error!, onRetry: _startLocation)
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
                children: [
                  const Text(
                    'Din vägvisare i skogen',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _home == null
                        ? 'Vänta på GPS och tryck sedan på Spara hemposition.'
                        : 'Hempunkten är låst och finns kvar när du öppnar appen igen.',
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _courseHeading != null
                        ? 'Riktning från din GPS-rörelse'
                        : 'Riktning från telefonens kompass',
                    style: TextStyle(color: Colors.black.withValues(alpha: .6)),
                  ),
                  const SizedBox(height: 18),
                  if (_home != null)
                    _CompassCard(
                      color: Colors.black,
                      title: 'HEM',
                      distance: formatDistance(_distanceTo(_home!)),
                      angle: _relativeBearing(_home!),
                      prominent: true,
                    )
                  else
                    _SaveHomeCard(onSave: _setHome),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _position == null ? null : _setHome,
                    icon: const Icon(Icons.bookmark_add_outlined),
                    label: Text(
                      _home == null
                          ? 'Spara hemposition'
                          : 'Ersätt sparad hemposition',
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_selectedSpot != null)
                    _CompassCard(
                      color: _chanterelle,
                      title: _selectedSpot!.name,
                      distance: formatDistance(_distanceTo(_selectedSpot!)),
                      angle: _relativeBearing(_selectedSpot!),
                    )
                  else
                    const _EmptyMushroomCard(),
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: _chanterelle,
                      foregroundColor: Colors.black,
                      minimumSize: const Size.fromHeight(54),
                    ),
                    onPressed: _addSpot,
                    icon: const Icon(Icons.add_location_alt_outlined),
                    label: const Text('Spara svampställe'),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Sparade svampställen',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  if (_spots.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('Inga sparade ställen ännu.'),
                    )
                  else
                    ..._spots.map((spot) {
                      final meters = _distanceTo(spot);
                      return Card(
                        clipBehavior: Clip.antiAlias,
                        child: ListTile(
                          selected: _selectedSpot == spot,
                          selectedTileColor: _chanterelle.withValues(
                            alpha: .12,
                          ),
                          onTap: () => setState(() => _selectedSpot = spot),
                          title: Text(spot.name),
                          subtitle: Text(
                            meters < 4
                                ? 'Du är framme'
                                : '${formatDistance(meters)} bort',
                          ),
                          leading: Icon(
                            _selectedSpot == spot
                                ? Icons.location_on
                                : Icons.location_on_outlined,
                            color: _chanterelle,
                          ),
                          trailing: IconButton(
                            onPressed: () => _deleteSpot(spot),
                            tooltip: 'Ta bort',
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}

class _CompassCard extends StatelessWidget {
  const _CompassCard({
    required this.color,
    required this.title,
    required this.distance,
    required this.angle,
    this.prominent = false,
  });
  final Color color;
  final String title;
  final String distance;
  final double angle;
  final bool prominent;
  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    color: color.withValues(alpha: color == Colors.black ? .06 : .13),
    child: Padding(
      padding: EdgeInsets.all(prominent ? 18 : 20),
      child: Row(
        children: [
          SizedBox(
            width: prominent ? 156 : 96,
            height: prominent ? 156 : 96,
            child: CustomPaint(
              painter: _ArrowPainter(
                color: color,
                angle: angle,
                long: prominent,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: prominent ? 22 : 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: prominent ? 1.5 : 0,
                    color: color,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  distance,
                  style: TextStyle(
                    fontSize: prominent ? 38 : 30,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Text('fågelvägen'),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _SaveHomeCard extends StatelessWidget {
  const _SaveHomeCard({required this.onSave});
  final VoidCallback onSave;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(Icons.home_outlined, size: 50),
          const SizedBox(height: 10),
          const Text(
            'Ingen hemposition sparad',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: onSave,
            child: const Text('Spara hemposition här'),
          ),
        ],
      ),
    ),
  );
}

class _EmptyMushroomCard extends StatelessWidget {
  const _EmptyMushroomCard();
  @override
  Widget build(BuildContext context) => const Card(
    child: Padding(
      padding: EdgeInsets.all(22),
      child: Row(
        children: [
          Icon(Icons.location_searching, color: _chanterelle, size: 42),
          SizedBox(width: 16),
          Expanded(
            child: Text('Spara ett svampställe för att få en orange pil dit.'),
          ),
        ],
      ),
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.location_off_outlined, size: 56),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 18),
          FilledButton(onPressed: onRetry, child: const Text('Försök igen')),
        ],
      ),
    ),
  );
}

class _ArrowPainter extends CustomPainter {
  const _ArrowPainter({
    required this.color,
    required this.angle,
    required this.long,
  });
  final Color color;
  final double angle;
  final bool long;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(angle);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final length = long ? 67.0 : 44.0;
    final halfWidth = long ? 18.0 : 14.0;
    final shaftWidth = long ? 7.0 : 6.0;
    final path = Path()
      ..moveTo(0, -length)
      ..lineTo(halfWidth, -length + 30)
      ..lineTo(shaftWidth, -length + 24)
      ..lineTo(shaftWidth, length - 12)
      ..lineTo(-shaftWidth, length - 12)
      ..lineTo(-shaftWidth, -length + 24)
      ..lineTo(-halfWidth, -length + 30)
      ..close();
    canvas.drawPath(path, paint);
    canvas.drawCircle(Offset.zero, long ? 8 : 6, Paint()..color = Colors.white);
    canvas.drawCircle(Offset.zero, long ? 4 : 3, paint);
  }

  @override
  bool shouldRepaint(covariant _ArrowPainter old) =>
      old.angle != angle || old.color != color || old.long != long;
}
