import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../data/location_service.dart';

class NavigationScreen extends StatefulWidget {
  const NavigationScreen({super.key});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  final MapController _mapController = MapController();
  bool _isNavigating = false;
  bool _isLoading = true;
  LatLng? _userLocation;
  LatLng? _destination;
  StreamSubscription<Position>? _positionSubscription;
  double _distance = 0;
  String _eta = '--';

  // Sample destination (Nadiad Junction)
  final LatLng _defaultDestination = LatLng(22.6950, 72.8680);

  @override
  void initState() {
    super.initState();
    _destination = _defaultDestination;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getCurrentLocation();
    });
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    final locationService = context.read<LocationService>();
    final position = await locationService.getCurrentPosition();
    
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (position != null) {
          _userLocation = LatLng(position.latitude, position.longitude);
          _calculateDistanceAndEta();
        } else {
          _userLocation = LatLng(22.6916, 72.8634);
        }
      });
    }
  }

  void _calculateDistanceAndEta() {
    if (_userLocation != null && _destination != null) {
      final locationService = context.read<LocationService>();
      _distance = locationService.calculateDistance(_userLocation!, _destination!);
      // Assume average walking speed of 5 km/h
      final timeInMinutes = (_distance / 5) * 60;
      _eta = '${timeInMinutes.round()} mins';
    }
  }

  void _startNavigation() {
    final locationService = context.read<LocationService>();
    _positionSubscription = locationService.getPositionStream().listen((position) {
      if (mounted) {
        setState(() {
          _userLocation = LatLng(position.latitude, position.longitude);
          _calculateDistanceAndEta();
        });
        _mapController.move(_userLocation!, 16.0);
      }
    });
    setState(() => _isNavigating = true);
  }

  void _stopNavigation() {
    _positionSubscription?.cancel();
    setState(() => _isNavigating = false);
  }

  void _centerOnUser() {
    if (_userLocation != null) {
      _mapController.move(_userLocation!, 15.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mapCenter = _userLocation ?? LatLng(22.6916, 72.8634);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Navigation'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _centerOnUser,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: mapCenter,
                    initialZoom: 15.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.travel_guide_app',
                    ),
                    // Route line
                    if (_userLocation != null && _destination != null)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: [_userLocation!, _destination!],
                            strokeWidth: 4.0,
                            color: _isNavigating 
                                ? theme.colorScheme.primary 
                                : theme.colorScheme.secondary.withValues(alpha: 0.5),
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers: [
                        // User location
                        if (_userLocation != null)
                          Marker(
                            point: _userLocation!,
                            child: Container(
                              decoration: BoxDecoration(
                                color: _isNavigating 
                                    ? theme.colorScheme.primary 
                                    : theme.colorScheme.secondary,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 3),
                              ),
                              child: const Padding(
                                padding: EdgeInsets.all(6),
                                child: Icon(Icons.navigation, color: Colors.white, size: 16),
                              ),
                            ),
                          ),
                        // Destination
                        if (_destination != null)
                          Marker(
                            point: _destination!,
                            child: Icon(Icons.flag, color: theme.colorScheme.error, size: 36),
                          ),
                      ],
                    ),
                  ],
                ),
                if (_isLoading)
                  const Center(child: CircularProgressIndicator()),
              ],
            ),
          ),
          // Navigation info bar
          Container(
            padding: const EdgeInsets.all(16),
            color: theme.colorScheme.surface,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.straighten, color: theme.colorScheme.secondary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Distance: ${_distance.toStringAsFixed(2)} km',
                      style: TextStyle(color: theme.colorScheme.secondary, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Icon(Icons.timer, color: theme.colorScheme.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'ETA: $_eta',
                      style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Navigation button
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : (_isNavigating ? _stopNavigation : _startNavigation),
              icon: Icon(_isNavigating ? Icons.stop : Icons.navigation),
              label: Text(_isNavigating ? 'Stop Navigation' : 'Start Navigation'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                backgroundColor: _isNavigating ? theme.colorScheme.error : theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
