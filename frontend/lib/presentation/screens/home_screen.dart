import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../data/auth_service.dart';
import '../../data/location_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MapController _mapController = MapController();
  bool _mapReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadLocation();
    });
  }

  Future<void> _loadLocation() async {
    final locationService = context.read<LocationService>();
    await locationService.getCurrentPosition();
    // Move map if already ready
    if (mounted && locationService.currentLatLng != null) {
      if (_mapReady) {
        _mapController.move(locationService.currentLatLng!, 14.0);
      }
      setState(() {}); // trigger rebuild to update marker
    }
  }

  void _onMapReady(LocationService locationService) {
    _mapReady = true;
    // If location already fetched by the time map loads, center immediately
    if (locationService.currentLatLng != null) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) _mapController.move(locationService.currentLatLng!, 14.0);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authService = context.watch<AuthService>();
    final locationService = context.watch<LocationService>();

    final defaultCenter = const LatLng(20.5937, 78.9629); // Center of India
    final mapCenter = locationService.currentLatLng ?? defaultCenter;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'Hello, ${authService.currentUserName ?? 'Traveller'} 👋',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              titlePadding: const EdgeInsets.only(left: 16, bottom: 12),
              background: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: mapCenter,
                      initialZoom: 13.0,
                      onMapReady: () => _onMapReady(locationService),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.antigravity.travel_guide',
                      ),
                      if (locationService.currentLatLng != null)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: locationService.currentLatLng!,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 3),
                                  boxShadow: [
                                    BoxShadow(
                                      color: theme.colorScheme.primary.withOpacity(0.4),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.all(6),
                                child: const Icon(Icons.person, color: Colors.white, size: 16),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  // Dark overlay for readability
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.5),
                        ],
                      ),
                    ),
                  ),
                  // Loading indicator
                  if (locationService.isLoading)
                    const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                ],
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.person_rounded),
                onPressed: () => Navigator.pushNamed(context, '/profile'),
              ),
            ],
          ),

          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.1,
              ),
              delegate: SliverChildListDelegate([
                _buildHomeButton(
                  context,
                  'Rail\nAssistant',
                  Icons.smart_toy_rounded,
                  '/assistant',
                  Colors.purple,
                ),
                _buildHomeButton(
                  context,
                  'Compare\nTransport',
                  Icons.compare_arrows_rounded,
                  '/compare',
                  theme.colorScheme.secondary,
                ),
                _buildHomeButton(
                  context,
                  'Nearby\nStations',
                  Icons.train_rounded,
                  '/nearby',
                  Colors.orange,
                ),
                _buildHomeButton(
                  context,
                  'Local\nTransport',
                  Icons.directions_bus_rounded,
                  '/local',
                  theme.colorScheme.tertiary,
                ),
                _buildHomeButton(
                  context,
                  'Smart\nTravel',
                  Icons.history_rounded,
                  '/history',
                  Colors.teal,
                ),
                _buildHomeButton(
                  context,
                  'Profile\nSettings',
                  Icons.person_rounded,
                  '/profile',
                  Colors.grey,
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeButton(
    BuildContext context,
    String label,
    IconData icon,
    String route,
    Color color,
  ) {
    return InkWell(
      onTap: () => Navigator.pushNamed(context, route),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: color),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
