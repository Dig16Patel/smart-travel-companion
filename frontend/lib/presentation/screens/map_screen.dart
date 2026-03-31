import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../data/location_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  LatLng? _userLocation;
  bool _isLoading = true;
  bool _mapReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getCurrentLocation();
    });
  }

  Future<void> _getCurrentLocation() async {
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
            _userLocation = LatLng(22.6916, 72.8634); // Fallback
          }
        });
        // Auto-center on user
        _centerOnUser();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _userLocation = LatLng(22.6916, 72.8634); // Fallback
        });
      }
    }
  }

  void _centerOnUser() {
    if (_userLocation != null && _mapReady) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _mapController.move(_userLocation!, 15.0);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mapCenter = _userLocation ?? LatLng(22.6916, 72.8634);
    
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: mapCenter,
              initialZoom: 13.0,
              onMapReady: () {
                _mapReady = true;
                if (_userLocation != null) {
                  _centerOnUser();
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.travel_guide_app',
              ),
              MarkerLayer(
                markers: [
                  if (_userLocation != null)
                    Marker(
                      point: _userLocation!,
                      width: 50,
                      height: 50,
                      child: Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.person, color: Colors.white, size: 24),
                      ),
                    ),
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
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Getting your location...', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),
          // Back button
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
          // Center on user button
          Positioned(
            top: 48,
            right: 16,
            child: FloatingActionButton(
              onPressed: _centerOnUser,
              mini: true,
              heroTag: 'location',
              backgroundColor: theme.colorScheme.surface,
              child: Icon(Icons.my_location, color: theme.colorScheme.secondary),
            ),
          ),
          // Location info
          if (_userLocation != null)
            Positioned(
              top: 100,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.location_on, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Lat: ${_userLocation!.latitude.toStringAsFixed(4)}, Lng: ${_userLocation!.longitude.toStringAsFixed(4)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Compare button
          Positioned(
            bottom: 24,
            left: 24,
            right: 24,
            child: ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/compare'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                backgroundColor: theme.colorScheme.primary,
              ),
              child: const Text('Compare All Transport Options'),
            ),
          ),
        ],
      ),
    );
  }
}
