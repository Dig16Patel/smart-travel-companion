import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../data/location_service.dart';

class MapGuideScreen extends StatefulWidget {
  const MapGuideScreen({super.key});

  @override
  State<MapGuideScreen> createState() => _MapGuideScreenState();
}

class _MapGuideScreenState extends State<MapGuideScreen> {
  final MapController _mapController = MapController();
  LatLng? _userLocation;
  bool _isLoading = true;
  bool _mapReady = false;
  int _currentStep = 0;

  // Destination - nearest railway station
  final LatLng _stationLocation = const LatLng(19.0680, 72.8347);
  final String _stationName = 'Mumbai Central Station';

  // Navigation steps
  List<NavigationStep> _steps = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeNavigation();
    });
  }

  Future<void> _initializeNavigation() async {
    if (!mounted) return;

    final locationService = context.read<LocationService>();

    try {
      final position = await locationService.getCurrentPosition();

      if (mounted) {
        setState(() {
          _isLoading = false;
          if (position != null) {
            _userLocation = LatLng(position.latitude, position.longitude);
          } else {
            _userLocation = const LatLng(19.0760, 72.8777);
          }
          _generateNavigationSteps();
        });
        _fitBounds();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _userLocation = const LatLng(19.0760, 72.8777);
          _generateNavigationSteps();
        });
      }
    }
  }

  void _generateNavigationSteps() {
    if (_userLocation == null) return;

    final distance = const Distance();
    final totalDistance = distance.as(LengthUnit.Kilometer, _userLocation!, _stationLocation);

    _steps = [
      NavigationStep(
        instruction: 'Start from your current location',
        distance: '0 m',
        icon: Icons.my_location,
        location: _userLocation!,
      ),
      NavigationStep(
        instruction: 'Head towards the main road',
        distance: '${(totalDistance * 0.15).toStringAsFixed(1)} km',
        icon: Icons.directions_walk,
        location: _interpolate(_userLocation!, _stationLocation, 0.15),
      ),
      NavigationStep(
        instruction: 'Continue straight on main road',
        distance: '${(totalDistance * 0.35).toStringAsFixed(1)} km',
        icon: Icons.straight,
        location: _interpolate(_userLocation!, _stationLocation, 0.5),
      ),
      NavigationStep(
        instruction: 'Turn left at the junction',
        distance: '${(totalDistance * 0.25).toStringAsFixed(1)} km',
        icon: Icons.turn_left,
        location: _interpolate(_userLocation!, _stationLocation, 0.75),
      ),
      NavigationStep(
        instruction: 'Arrive at $_stationName',
        distance: '${(totalDistance * 0.25).toStringAsFixed(1)} km',
        icon: Icons.train,
        location: _stationLocation,
      ),
    ];
  }

  LatLng _interpolate(LatLng start, LatLng end, double t) {
    return LatLng(
      start.latitude + (end.latitude - start.latitude) * t,
      start.longitude + (end.longitude - start.longitude) * t,
    );
  }

  void _fitBounds() {
    if (_userLocation == null || !_mapReady) return;

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        final bounds = LatLngBounds.fromPoints([_userLocation!, _stationLocation]);
        _mapController.fitCamera(
          CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(60)),
        );
      }
    });
  }

  void _nextStep() {
    if (_currentStep < _steps.length - 1) {
      setState(() => _currentStep++);
      _mapController.move(_steps[_currentStep].location, 16);
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _mapController.move(_steps[_currentStep].location, 16);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mapCenter = _userLocation ?? const LatLng(19.0760, 72.8777);

    return Scaffold(
      body: Stack(
        children: [
          // Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: mapCenter,
              initialZoom: 14.0,
              onMapReady: () {
                _mapReady = true;
                _fitBounds();
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.travel_guide_app',
              ),
              // Route line
              if (_userLocation != null && _steps.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _steps.map((s) => s.location).toList(),
                      strokeWidth: 5,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ),
              // Markers
              MarkerLayer(
                markers: [
                  if (_userLocation != null)
                    Marker(
                      point: _userLocation!,
                      width: 45,
                      height: 45,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                        ),
                        child: const Icon(Icons.person, color: Colors.white, size: 22),
                      ),
                    ),
                  Marker(
                    point: _stationLocation,
                    width: 50,
                    height: 50,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                      ),
                      child: const Icon(Icons.train, color: Colors.white, size: 26),
                    ),
                  ),
                  // Step markers
                  ...List.generate(_steps.length - 2, (i) {
                    final stepIndex = i + 1;
                    return Marker(
                      point: _steps[stepIndex].location,
                      width: 28,
                      height: 28,
                      child: Container(
                        decoration: BoxDecoration(
                          color: _currentStep == stepIndex 
                              ? theme.colorScheme.primary 
                              : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.colorScheme.primary,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '${stepIndex + 1}',
                            style: TextStyle(
                              color: _currentStep == stepIndex 
                                  ? Colors.black 
                                  : theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ],
          ),

          // Loading
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text('Calculating route...', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),

          // Top controls
          Positioned(
            top: 48,
            left: 16,
            child: FloatingActionButton(
              onPressed: () => Navigator.pop(context),
              mini: true,
              heroTag: 'back',
              backgroundColor: theme.colorScheme.surface,
              child: const Icon(Icons.arrow_back),
            ),
          ),
          Positioned(
            top: 48,
            right: 16,
            child: FloatingActionButton(
              onPressed: _fitBounds,
              mini: true,
              heroTag: 'fit',
              backgroundColor: theme.colorScheme.surface,
              child: const Icon(Icons.zoom_out_map),
            ),
          ),

          // Destination card
          Positioned(
            top: 100,
            left: 16,
            right: 16,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.train, color: Colors.red, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Destination', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          Text(_stationName, style: const TextStyle(fontWeight: FontWeight.bold)),
                          if (_userLocation != null)
                            Text(
                              '${const Distance().as(LengthUnit.Kilometer, _userLocation!, _stationLocation).toStringAsFixed(1)} km • ~${(_steps.length * 5)} min',
                              style: TextStyle(fontSize: 12, color: theme.colorScheme.primary),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Navigation panel
          if (_steps.isNotEmpty)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: const Offset(0, -2))],
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Handle
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade600,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      // Step info
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                _steps[_currentStep].icon,
                                color: theme.colorScheme.primary,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Step ${_currentStep + 1} of ${_steps.length}',
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _steps[_currentStep].instruction,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.straighten, size: 14, color: theme.colorScheme.primary),
                                      const SizedBox(width: 4),
                                      Text(
                                        _steps[_currentStep].distance,
                                        style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Buttons
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _currentStep > 0 ? _prevStep : null,
                                icon: const Icon(Icons.arrow_back),
                                label: const Text('Back'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton.icon(
                                onPressed: _currentStep < _steps.length - 1 ? _nextStep : null,
                                icon: Icon(_currentStep == _steps.length - 1 ? Icons.check : Icons.arrow_forward),
                                label: Text(_currentStep == _steps.length - 1 ? 'Arrived!' : 'Next Step'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.colorScheme.primary,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class NavigationStep {
  final String instruction;
  final String distance;
  final IconData icon;
  final LatLng location;

  NavigationStep({
    required this.instruction,
    required this.distance,
    required this.icon,
    required this.location,
  });
}
