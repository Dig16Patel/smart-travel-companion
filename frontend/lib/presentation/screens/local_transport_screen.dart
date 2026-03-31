import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../data/location_service.dart';
import '../../data/locations_data.dart';
import '../../data/taxi_estimator.dart';
import '../../data/transport_availability.dart';

class LocalTransportScreen extends StatefulWidget {
  const LocalTransportScreen({super.key});
  @override
  State<LocalTransportScreen> createState() => _LocalTransportScreenState();
}

class _LocalTransportScreenState extends State<LocalTransportScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Local Transport'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.route), text: 'Route Planner'),
            Tab(icon: Icon(Icons.directions_bus), text: 'Bus Stops'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _RoutePlannerTab(),
          _BusStopsTab(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 1: ROUTE PLANNER
// ─────────────────────────────────────────────────────────────────────────────

class _RoutePlannerTab extends StatefulWidget {
  const _RoutePlannerTab();
  @override
  State<_RoutePlannerTab> createState() => _RoutePlannerTabState();
}

class _RoutePlannerTabState extends State<_RoutePlannerTab> {
  final _fromController = TextEditingController(text: 'My Location');
  final _toController   = TextEditingController();
  final _passengerController = TextEditingController(text: '1');
  final _fromFocusNode  = FocusNode();
  final _toFocusNode    = FocusNode();
  bool _useCurrentLocation = true;
  int  _passengerCount = 1;
  bool _isSearching = false;
  String? _error;
  double? _distanceKm;
  String? _destinationName;
  List<TaxiEstimate> _estimates = [];
  List<TransportAvailability> _availability = [];

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    _passengerController.dispose();
    _fromFocusNode.dispose();
    _toFocusNode.dispose();
    super.dispose();
  }

  Future<void> _searchRoute() async {
    final origin      = _fromController.text.trim();
    final destination = _toController.text.trim();
    if (origin.isEmpty) {
      setState(() => _error = 'Please enter a starting location.');
      return;
    }
    if (destination.isEmpty) {
      setState(() => _error = 'Please enter a destination.');
      return;
    }
    setState(() {
      _isSearching = true;
      _error = null;
      _estimates = [];
      _distanceKm = null;
      _availability = [];
    });

    try {
      double originLat, originLng;

      if (_useCurrentLocation) {
        final locationService = context.read<LocationService>();
        final position = await locationService.getCurrentPosition();
        if (position == null) {
          setState(() {
            _error = 'Could not get your current location. Enable GPS.';
            _isSearching = false;
          });
          return;
        }
        originLat = position.latitude;
        originLng = position.longitude;
      } else {
        final fromUrl = Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(origin)}&format=json&limit=1',
        );
        final fromResp = await http.get(fromUrl, headers: {
          'User-Agent': 'SmartTravelApp/1.0',
        }).timeout(const Duration(seconds: 10));
        final fromData = jsonDecode(fromResp.body) as List;
        if (fromData.isEmpty) {
          setState(() {
            _error = 'Starting location not found. Try a more specific name.';
            _isSearching = false;
          });
          return;
        }
        originLat = double.parse(fromData[0]['lat'] as String);
        originLng = double.parse(fromData[0]['lon'] as String);
      }

      // Geocode destination
      final geoUrl = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(destination)}&format=json&limit=1',
      );
      final geoResponse = await http.get(geoUrl, headers: {
        'User-Agent': 'SmartTravelApp/1.0',
      }).timeout(const Duration(seconds: 10));

      if (geoResponse.statusCode != 200) {
        throw Exception('Geocoding failed');
      }

      final geoData = jsonDecode(geoResponse.body) as List;
      if (geoData.isEmpty) {
        setState(() {
          _error = 'Destination not found. Try a more specific name.';
          _isSearching = false;
        });
        return;
      }

      final destLat = double.parse(geoData[0]['lat'] as String);
      final destLng = double.parse(geoData[0]['lon'] as String);
      final resolvedName = geoData[0]['display_name'] as String;

      final distMeters = Geolocator.distanceBetween(
        originLat, originLng,
        destLat, destLng,
      );
      final roadKm = (distMeters / 1000) * 1.3;

      final estimator = TaxiFareEstimator();
      final estimates = estimator.getEstimates(roadKm)
          .where((e) => e.maxPassengers >= _passengerCount)
          .toList();
      // Sort cheapest first
      estimates.sort((a, b) => a.estimatedFare.compareTo(b.estimatedFare));

      // Compute transport availability
      final availability = TransportAvailabilityService()
          .compute(roadKm, DateTime.now(), passengerCount: _passengerCount);

      setState(() {
        _distanceKm = roadKm;
        _destinationName = resolvedName.split(',').take(2).join(',');
        _estimates = estimates;
        _availability = availability;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Search failed. Check internet connection.';
        _isSearching = false;
      });
    }
  }

  void _openCabApp(BuildContext context, String provider, String destination) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.open_in_new, size: 20),
            const SizedBox(width: 8),
            Text('Open $provider'),
          ],
        ),
        content: Text(
          'Open the $provider app on your phone and search for:\n\n"$destination"',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Input Card ──────────────────────────────────────────────────
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // ── From field with autocomplete ──────────────────────────
                  _buildLocationField(
                    controller: _fromController,
                    focusNode: _fromFocusNode,
                    label: 'From',
                    prefixIcon: Icon(Icons.trip_origin,
                        color: theme.colorScheme.primary),
                    suffixIcon: IconButton(
                      tooltip: 'Use my current location',
                      icon: Icon(Icons.my_location,
                          color: _useCurrentLocation
                              ? theme.colorScheme.primary
                              : Colors.grey),
                      onPressed: () => setState(() {
                        _fromController.text = 'My Location';
                        _useCurrentLocation = true;
                      }),
                    ),
                    onChanged: (v) => setState(() {
                      _useCurrentLocation = v.trim().isEmpty ||
                          v.trim().toLowerCase() == 'my location';
                    }),
                  ),
                  const SizedBox(height: 8),
                  Icon(Icons.swap_vert, color: theme.colorScheme.primary),
                  const SizedBox(height: 8),
                  // ── To field with autocomplete ───────────────────────────
                  _buildLocationField(
                    controller: _toController,
                    focusNode: _toFocusNode,
                    label: 'To — enter destination',
                    prefixIcon: const Icon(Icons.location_on,
                        color: Colors.redAccent),
                    onSubmitted: _searchRoute,
                  ),
                  const SizedBox(height: 12),
                  // ── Passenger selector ───────────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 8),
                        const Icon(Icons.people, size: 20),
                        const SizedBox(width: 8),
                        const Text('Passengers', style: TextStyle(fontSize: 14)),
                        const Spacer(),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: _passengerCount > 1
                              ? () => setState(() {
                                    _passengerCount--;
                                    _passengerController.text = '$_passengerCount';
                                  })
                              : null,
                        ),
                        // Editable count
                        Container(
                          width: 52,
                          height: 34,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Center(
                            child: TextField(
                              controller: _passengerController,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              maxLength: 2,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              decoration: const InputDecoration(
                                counterText: '',
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                              onChanged: (val) {
                                final n = int.tryParse(val);
                                if (n != null && n >= 1 && n <= 50) {
                                  setState(() => _passengerCount = n);
                                }
                              },
                              onSubmitted: (val) {
                                final n = int.tryParse(val);
                                if (n == null || n < 1) {
                                  setState(() => _passengerCount = 1);
                                  _passengerController.text = '1';
                                } else if (n > 50) {
                                  setState(() => _passengerCount = 50);
                                  _passengerController.text = '50';
                                }
                              },
                            ),
                          ),
                        ),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: _passengerCount < 50
                              ? () => setState(() {
                                    _passengerCount++;
                                    _passengerController.text = '$_passengerCount';
                                  })
                              : null,
                        ),
                        const SizedBox(width: 4),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _isSearching ? null : _searchRoute,
                      icon: _isSearching
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.black),
                            )
                          : const Icon(Icons.search),
                      label: Text(_isSearching ? 'Searching...' : 'Search Route'),
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Error ────────────────────────────────────────────────────────
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.shade300),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(_error!,
                          style: const TextStyle(color: Colors.red))),
                ],
              ),
            ),
          ],

          // ── Route Info Banner ─────────────────────────────────────────────
          if (_distanceKm != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary.withValues(alpha: 0.15),
                    theme.colorScheme.primary.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.route, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _destinationName ?? '',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '📏 Estimated road distance: ${_distanceKm!.toStringAsFixed(1)} km',
                    style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withOpacity(0.7)),
                  ),
                ],
              ),
            ),

            // ── Availability Section ────────────────────────────────────────
            const SizedBox(height: 16),
            Text('Transport Availability',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            if (_availability.isNotEmpty)
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.8,
                children: _availability
                    .map((a) => _AvailabilityCard(availability: a))
                    .toList(),
              ),

            // ── Fare Cards ─────────────────────────────────────────────────
            const SizedBox(height: 16),
            Text('Fare Estimates',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ..._estimates.asMap().entries.map((entry) {
              final i = entry.key;
              final e = entry.value;
              return _FareCard(
                estimate: e,
                isCheapest: i == 0,
                passengerCount: _passengerCount,
                onBook: () => _openCabApp(
                    context, e.provider, _toController.text.trim()),
              );
            }),
          ],

          // ── Placeholder before search ─────────────────────────────────────
          if (_distanceKm == null && !_isSearching && _error == null) ...[
            const SizedBox(height: 48),
            Center(
              child: Column(
                children: [
                  Icon(Icons.directions_car_outlined,
                      size: 64,
                      color: theme.colorScheme.primary.withValues(alpha: 0.3)),
                  const SizedBox(height: 12),
                  Text(
                    'Enter a destination to see\ncab fares and booking options',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Shared autocomplete field for From/To
  Widget _buildLocationField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required Widget prefixIcon,
    Widget? suffixIcon,
    void Function(String)? onChanged,
    VoidCallback? onSubmitted,
  }) {
    return RawAutocomplete<String>(
      textEditingController: controller,
      focusNode: focusNode,
      optionsBuilder: (tv) => LocationsData.search(tv.text),
      onSelected: (sel) {
        controller.text = sel;
        if (onChanged != null) onChanged(sel);
      },
      fieldViewBuilder: (ctx, ctrl, fn, onFieldSubmitted) {
        return TextField(
          controller: ctrl,
          focusNode: fn,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
          ),
          onChanged: onChanged,
          onSubmitted: (_) {
            onFieldSubmitted();
            onSubmitted?.call();
          },
        );
      },
      optionsViewBuilder: (ctx, onSel, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200, maxWidth: 380),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (_, i) {
                  final opt = options.elementAt(i);
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.location_city, size: 18),
                    title: Text(opt),
                    onTap: () => onSel(opt),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Availability Card Widget ────────────────────────────────────────────────

class _AvailabilityCard extends StatelessWidget {
  final TransportAvailability availability;

  const _AvailabilityCard({required this.availability});

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;
    String statusText;

    switch (availability.level) {
      case AvailabilityLevel.high:
        color = Colors.green;
        icon = Icons.check_circle;
        statusText = 'High Chance (${availability.percentage}%)';
        break;
      case AvailabilityLevel.medium:
        color = Colors.orange;
        icon = Icons.info;
        statusText = 'Medium Chance (${availability.percentage}%)';
        break;
      case AvailabilityLevel.low:
        color = Colors.deepOrange;
        icon = Icons.warning;
        statusText = 'Low Chance (${availability.percentage}%)';
        break;
      case AvailabilityLevel.none:
        color = Colors.red;
        icon = Icons.cancel;
        statusText = 'Not Available';
        break;
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: color.withOpacity(0.3), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Text(availability.mode.emoji, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    availability.mode.label,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(icon, color: color, size: 16),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              statusText,
              style: TextStyle(
                color: availability.level == AvailabilityLevel.none ? Colors.red.shade700 : color,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (availability.level == AvailabilityLevel.none && availability.reason.isNotEmpty)
              Text(
                availability.reason,
                style: TextStyle(color: Colors.red.shade700, fontSize: 9),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Fare Card Widget ────────────────────────────────────────────────────────

class _FareCard extends StatelessWidget {
  final TaxiEstimate estimate;
  final bool isCheapest;
  final int passengerCount;
  final VoidCallback onBook;

  const _FareCard({
    required this.estimate,
    required this.isCheapest,
    required this.passengerCount,
    required this.onBook,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    IconData icon;
    Color color;
    switch (estimate.provider.toLowerCase()) {
      case 'ola':
        icon = Icons.local_taxi;
        color = Colors.green;
        break;
      case 'city bus':
        icon = Icons.directions_bus;
        color = Colors.indigo;
        break;
      case 'uber':
        icon = Icons.directions_car;
        color = Colors.black87;
        break;
      case 'rapido':
        icon = Icons.two_wheeler;
        color = Colors.amber.shade700;
        break;
      case 'auto':
        icon = Icons.electric_rickshaw;
        color = Colors.orange;
        break;
      default:
        icon = Icons.local_taxi;
        color = Colors.blue;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isCheapest ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: isCheapest
            ? BorderSide(color: theme.colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Icon
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.15),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(estimate.provider,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(width: 6),
                      Text(estimate.vehicleType,
                          style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.5))),
                      if (isCheapest) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('CHEAPEST',
                              style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text('Est. travel time: ${estimate.tripTime}',
                      style: TextStyle(
                          fontSize: 12,
                          color:
                              theme.colorScheme.onSurface.withValues(alpha: 0.5))),
                ],
              ),
            ),
            // Fare + Book Button
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Main fare
                Text(
                  passengerCount > 1 && estimate.provider.toLowerCase() == 'city bus'
                      ? '₹${estimate.estimatedFare * passengerCount}' // total for bus
                      : '₹${estimate.estimatedFare}',                 // vehicle fare
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary),
                ),
                // Per-person / breakdown
                if (passengerCount > 1) ...[
                  const SizedBox(height: 2),
                  if (estimate.provider.toLowerCase() == 'city bus')
                    Text(
                      '₹${estimate.estimatedFare}/person',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    )
                  else
                    Text(
                      '₹${(estimate.estimatedFare / passengerCount).ceil()}/person',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                ],
                const SizedBox(height: 4),
                ElevatedButton(
                  onPressed: onBook,
                  style: ElevatedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Book', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 2: NEARBY BUS STOPS
// ─────────────────────────────────────────────────────────────────────────────

class _BusStopsTab extends StatefulWidget {
  const _BusStopsTab();
  @override
  State<_BusStopsTab> createState() => _BusStopsTabState();
}

class _BusStopsTabState extends State<_BusStopsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final MapController _mapController = MapController();
  bool _isLoading = true;
  bool _mapReady = false;
  String? _error;
  LatLng? _userLocation;
  List<Map<String, dynamic>> _busStops = [];
  int _radiusKm = 10; // default 10km

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchBusStops());
  }

  Future<void> _fetchBusStops() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final locationService = context.read<LocationService>();
    final position = await locationService.getCurrentPosition();

    if (!mounted) return;
    if (position == null) {
      setState(() {
        _error = 'Could not get location. Please enable GPS.';
        _isLoading = false;
      });
      return;
    }

    final userLatLng = LatLng(position.latitude, position.longitude);
    setState(() => _userLocation = userLatLng);

    try {
      const int radiusMeters = 0; // placeholder
      final int actualRadius = _radiusKm * 1000;
      final lat = userLatLng.latitude;
      final lng = userLatLng.longitude;

      final query =
          '[out:json][timeout:30];'
          '('
          'node["highway"="bus_stop"](around:$actualRadius,$lat,$lng);'
          'node["amenity"="bus_station"](around:$actualRadius,$lat,$lng);'
          'node["public_transport"="platform"](around:$actualRadius,$lat,$lng);'
          'node["public_transport"="stop_position"]["bus"="yes"](around:$actualRadius,$lat,$lng);'
          'node["amenity"="shelter"]["bus"="yes"](around:$actualRadius,$lat,$lng);'
          ');'
          'out body;';

      final response = await http.post(
        Uri.parse('https://overpass-api.de/api/interpreter'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: 'data=${Uri.encodeComponent(query)}',
      ).timeout(const Duration(seconds: 30));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final elements = (data['elements'] as List?) ?? [];

        final stops = <Map<String, dynamic>>[];
        for (final el in elements) {
          final tags = (el['tags'] as Map<String, dynamic>?) ?? {};
          final stLat = (el['lat'] as num?)?.toDouble();
          final stLng = (el['lon'] as num?)?.toDouble();
          if (stLat == null || stLng == null) continue;

          final distMeters = Geolocator.distanceBetween(
              lat, lng, stLat, stLng);
          final name = tags['name'] ??
              tags['ref'] ??
              tags['operator'] ??
              'Bus Stop';
          final type = tags['amenity'] == 'bus_station'
              ? 'Bus Station'
              : tags['public_transport'] == 'platform'
                  ? 'Platform'
                  : 'Bus Stop';

          stops.add({
            'name': name,
            'lat': stLat,
            'lng': stLng,
            'distance': distMeters,
            'distanceText': distMeters < 1000
                ? '${distMeters.toStringAsFixed(0)} m'
                : '${(distMeters / 1000).toStringAsFixed(1)} km',
            'type': type,
          });
        }

        stops.sort(
            (a, b) => (a['distance'] as double).compareTo(b['distance'] as double));
        final top20 = stops.take(20).toList();

        if (mounted) {
          setState(() {
            _busStops = top20;
            _isLoading = false;
          });
          if (_mapReady) {
            Future.delayed(const Duration(milliseconds: 200), () {
              if (mounted) _mapController.move(userLatLng, 14.0);
            });
          }
        }
      } else {
        throw Exception('API error ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Could not fetch bus stops. Check internet and retry.';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final mapCenter = _userLocation ?? const LatLng(20.5937, 78.9629);

    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Finding nearby bus stops...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.directions_bus_filled,
                  size: 52, color: Colors.grey),
              const SizedBox(height: 12),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _fetchBusStops,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Status bar
        Container(
          color: Colors.blue.withValues(alpha: 0.08),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.directions_bus, size: 16, color: Colors.blue),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _busStops.isEmpty
                      ? 'No stops found within $_radiusKm km'
                      : '${_busStops.length} stops found within $_radiusKm km',
                  style: const TextStyle(
                      fontSize: 12,
                      color: Colors.blue,
                      fontWeight: FontWeight.w500),
                ),
              ),
              // Radius picker
              PopupMenuButton<int>(
                icon: const Icon(Icons.radar, size: 18, color: Colors.blue),
                tooltip: 'Search radius',
                onSelected: (km) {
                  setState(() => _radiusKm = km);
                  _fetchBusStops();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 2,  child: Text('2 km radius')),
                  PopupMenuItem(value: 5,  child: Text('5 km radius')),
                  PopupMenuItem(value: 10, child: Text('10 km radius ✓')),
                  PopupMenuItem(value: 25, child: Text('25 km radius')),
                  PopupMenuItem(value: 50, child: Text('50 km radius')),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 18, color: Colors.blue),
                onPressed: _fetchBusStops,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),

        // Map
        Expanded(
          flex: 2,
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: mapCenter,
              initialZoom: 14.0,
              onMapReady: () {
                _mapReady = true;
                if (_userLocation != null) {
                  _mapController.move(_userLocation!, 14.0);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.antigravity.travel_guide',
              ),
              MarkerLayer(
                markers: [
                  if (_userLocation != null)
                    Marker(
                      point: _userLocation!,
                      width: 38,
                      height: 38,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: Colors.white, width: 2.5),
                        ),
                        child: const Icon(Icons.person_pin_circle,
                            color: Colors.white, size: 20),
                      ),
                    ),
                  ..._busStops.map((stop) => Marker(
                        point: LatLng(
                            stop['lat'] as double, stop['lng'] as double),
                        width: 32,
                        height: 32,
                        child: GestureDetector(
                          onTap: () {
                            _mapController.move(
                              LatLng(stop['lat'] as double,
                                  stop['lng'] as double),
                              16.0,
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    '${stop['name']}  •  ${stop['distanceText']}'),
                                duration: const Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.blue.shade700,
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(Icons.directions_bus,
                                color: Colors.white, size: 16),
                          ),
                        ),
                      )),
                ],
              ),
            ],
          ),
        ),

        // Stop list
        Expanded(
          flex: 1,
          child: _busStops.isEmpty
              ? const Center(
                  child: Text('No bus stops found',
                      style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  itemCount: _busStops.length,
                  itemBuilder: (context, index) {
                    final stop = _busStops[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 6),
                      child: ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: index == 0
                              ? Colors.blue
                              : Colors.blue.withValues(alpha: 0.15),
                          child: Icon(
                            Icons.directions_bus,
                            size: 16,
                            color: index == 0
                                ? Colors.white
                                : Colors.blue,
                          ),
                        ),
                        title: Text(
                          stop['name'] as String,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        subtitle: Text(
                          '${stop['type']}  •  ${stop['distanceText']}',
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.map_outlined,
                              color: Colors.blue),
                          onPressed: () => _mapController.move(
                            LatLng(stop['lat'] as double,
                                stop['lng'] as double),
                            16.0,
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
