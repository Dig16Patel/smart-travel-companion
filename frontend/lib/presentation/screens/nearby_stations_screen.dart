import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../../data/location_service.dart';

class NearbyStationsScreen extends StatefulWidget {
  const NearbyStationsScreen({super.key});

  @override
  State<NearbyStationsScreen> createState() => _NearbyStationsScreenState();
}

class _NearbyStationsScreenState extends State<NearbyStationsScreen> {
  final MapController _mapController = MapController();
  LatLng? _userLocation;
  bool _isLoading = true;
  bool _isFetchingStations = false;
  String? _error;
  bool _mapReady = false;
  List<Map<String, dynamic>> _nearbyStations = [];
  double _searchRadiusKm = 50.0; // default 50km

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getCurrentLocationAndFetch();
    });
  }

  Future<void> _getCurrentLocationAndFetch() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
      _nearbyStations = [];
    });

    final locationService = context.read<LocationService>();
    final position = await locationService.getCurrentPosition();

    if (!mounted) return;

    if (position != null) {
      final userLatLng = LatLng(position.latitude, position.longitude);
      setState(() {
        _userLocation = userLatLng;
        _isLoading = false;
      });
      _centerOnUser();
      await _fetchNearbyStations(userLatLng);
    } else {
      setState(() {
        _error = locationService.errorMessage ?? 'Could not get your location. Please enable GPS.';
        _isLoading = false;
      });
    }
  }

  /// Fetches real railway stations from OpenStreetMap Overpass API
  Future<void> _fetchNearbyStations(LatLng center) async {
    if (!mounted) return;
    setState(() { _isFetchingStations = true; });

    final radiusMeters = (_searchRadiusKm * 1000).toInt();
    final lat = center.latitude;
    final lng = center.longitude;

    // Overpass QL: get only main railway stations within radius
    final query =
        '[out:json][timeout:30];'
        '('
        'node["railway"="station"](around:$radiusMeters,$lat,$lng);'
        ');'
        'out body;';

    try {
      final response = await http.post(
        Uri.parse('https://overpass-api.de/api/interpreter'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: 'data=${Uri.encodeComponent(query)}',
      ).timeout(const Duration(seconds: 35));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final elements = (data['elements'] as List?) ?? [];

        final stationsList = <Map<String, dynamic>>[];

        for (final el in elements) {
          final tags = (el['tags'] as Map<String, dynamic>?) ?? {};
          final stLat = (el['lat'] as num?)?.toDouble();
          final stLng = (el['lon'] as num?)?.toDouble();
          if (stLat == null || stLng == null) continue;

          // Use Geolocator.distanceBetween — consistent with rest of codebase
          final distanceMeters = Geolocator.distanceBetween(
            center.latitude, center.longitude,
            stLat, stLng,
          );
          final distanceKm = distanceMeters / 1000.0;

          final name = tags['name'] ??
              tags['name:en'] ??
              tags['official_name'] ??
              'Railway Station';

          final String type = 'Station';

          stationsList.add({
            'name': name,
            'lat': stLat,
            'lng': stLng,
            'distance': distanceKm,
            'distanceText': distanceKm < 1
                ? '${distanceMeters.toStringAsFixed(0)} m'
                : '${distanceKm.toStringAsFixed(1)} km',
            'type': type,
          });
        }

        // Sort by distance and keep only the 10 closest
        stationsList.sort((a, b) =>
            (a['distance'] as double).compareTo(b['distance'] as double));
        final top10 = stationsList.take(10).toList();

        if (mounted) {
          setState(() {
            _nearbyStations = top10;
            _isFetchingStations = false;
          });
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isFetchingStations = false;
          _error = 'Could not fetch stations. Check internet & retry.';
        });
        debugPrint('Overpass API error: $e');
      }
    }
  }

  void _centerOnUser() {
    if (_userLocation != null && _mapReady) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) _mapController.move(_userLocation!, 11.0);
      });
    }
  }

  void _changeRadius(double km) {
    setState(() => _searchRadiusKm = km);
    if (_userLocation != null) {
      _fetchNearbyStations(_userLocation!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mapCenter = _userLocation ?? const LatLng(20.5937, 78.9629);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby Stations'),
        actions: [
          PopupMenuButton<double>(
            icon: const Icon(Icons.radar),
            tooltip: 'Search radius',
            onSelected: _changeRadius,
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: 10.0, child: Text('10 km radius')),
              PopupMenuItem(value: 25.0, child: Text('25 km radius')),
              PopupMenuItem(value: 50.0, child: Text('50 km radius ✓')),
              PopupMenuItem(value: 100.0, child: Text('100 km radius')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _getCurrentLocationAndFetch,
          ),
        ],
      ),

      body: Column(
        children: [
          // Status bar
          Container(
            color: theme.colorScheme.primary.withValues(alpha: 0.08),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.radar, size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _isFetchingStations
                        ? 'Searching within ${_searchRadiusKm.toInt()} km...'
                        : _nearbyStations.isEmpty
                            ? 'No stations found within ${_searchRadiusKm.toInt()} km'
                            : '${_nearbyStations.length} closest station(s) found nearby',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (_isFetchingStations)
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.primary,
                    ),
                  ),
              ],
            ),
          ),

          // Map
          Expanded(
            flex: 2,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: mapCenter,
                    initialZoom: 11.0,
                    onMapReady: () {
                      _mapReady = true;
                      if (_userLocation != null) _centerOnUser();
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.antigravity.travel_guide',
                    ),
                    MarkerLayer(
                      markers: [
                        // User location
                        if (_userLocation != null)
                          Marker(
                            point: _userLocation!,
                            width: 42,
                            height: 42,
                            child: Container(
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 3),
                                boxShadow: [
                                  BoxShadow(
                                    color: theme.colorScheme.primary
                                        .withValues(alpha: 0.4),
                                    blurRadius: 10,
                                    spreadRadius: 3,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.person_pin_circle,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        // Station markers
                        ..._nearbyStations.map((station) => Marker(
                              point: LatLng(
                                station['lat'] as double,
                                station['lng'] as double,
                              ),
                              width: 34,
                              height: 34,
                              child: GestureDetector(
                                onTap: () {
                                  _mapController.move(
                                    LatLng(
                                      station['lat'] as double,
                                      station['lng'] as double,
                                    ),
                                    14.0,
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '${station['name']}  •  ${station['distanceText']}',
                                      ),
                                      duration: const Duration(seconds: 2),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade700,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black26,
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.train,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                            )),
                      ],
                    ),
                  ],
                ),

                // Loading overlay
                if (_isLoading)
                  Container(
                    color: Colors.black45,
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: Colors.white),
                          SizedBox(height: 12),
                          Text(
                            'Getting your location...',
                            style: TextStyle(color: Colors.white, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),

                // My location FAB
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: FloatingActionButton.small(
                    heroTag: 'centerBtn',
                    onPressed: _centerOnUser,
                    backgroundColor: theme.colorScheme.surface,
                    child: Icon(
                      Icons.my_location,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Station list
          Expanded(
            flex: 1,
            child: _buildBottomPanel(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomPanel(ThemeData theme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _nearbyStations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.location_off_rounded, size: 48, color: Colors.grey),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _getCurrentLocationAndFetch,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_isFetchingStations && _nearbyStations.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Fetching real railway stations...'),
          ],
        ),
      );
    }

    if (_nearbyStations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.train_outlined, size: 44, color: Colors.grey),
            const SizedBox(height: 8),
            const Text(
              'No stations found in this range',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: () => _changeRadius(_searchRadiusKm + 25),
              icon: const Icon(Icons.expand_more),
              label: Text('Expand to ${(_searchRadiusKm + 25).toInt()} km'),
            ),
          ],
        ),
      );
    }

    const rankLabels = ['NEAREST', '2nd', '3rd', '4th', '5th', '6th', '7th', '8th', '9th', '10th'];
    const rankColors = [
      Colors.green, Colors.orange, Colors.blueGrey,
      Colors.purple, Colors.teal, Colors.redAccent,
      Colors.indigo, Colors.brown, Colors.cyan, Colors.pink,
    ];

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      itemCount: _nearbyStations.length,
      itemBuilder: (context, index) {
        final station = _nearbyStations[index];
        final isClosest = index == 0;
        final rankLabel = index < rankLabels.length ? rankLabels[index] : null;
        final rankColor = index < rankColors.length ? rankColors[index] : Colors.grey;
        return Card(
          color: isClosest
              ? theme.colorScheme.primary.withValues(alpha: 0.08)
              : theme.colorScheme.surface,
          margin: const EdgeInsets.only(bottom: 6),
          child: ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 18,
              backgroundColor: isClosest
                  ? theme.colorScheme.primary
                  : theme.colorScheme.primary.withValues(alpha: 0.15),
              child: Icon(
                Icons.train,
                size: 16,
                color: isClosest ? Colors.white : theme.colorScheme.primary,
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    station['name'] as String,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (rankLabel != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: rankColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      rankLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            subtitle: Text(
              '${station['type']}  •  ${station['distanceText']}',
              style: const TextStyle(fontSize: 11),
            ),
            trailing: IconButton(
              icon: Icon(Icons.directions, color: theme.colorScheme.secondary),
              onPressed: () => _mapController.move(
                LatLng(station['lat'] as double, station['lng'] as double),
                15.0,
              ),
            ),
          ),
        );
      },
    );
  }
}
