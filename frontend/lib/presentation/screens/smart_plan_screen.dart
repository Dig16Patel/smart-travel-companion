import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../services/smart_planner.dart';
import '../../services/uber_service.dart';
import '../../data/location_service.dart';
import '../../data/database_helper.dart';
import '../../data/station_data.dart';

// ─── Reusable station-search field ──────────────────────────────────────────
class _StationSearchField extends StatefulWidget {
  final String label;
  final IconData icon;
  final String? initialCode;
  final ValueChanged<String?> onSelected;

  const _StationSearchField({
    required this.label,
    required this.icon,
    required this.onSelected,
    this.initialCode,
  });

  @override
  State<_StationSearchField> createState() => _StationSearchFieldState();
}

class _StationSearchFieldState extends State<_StationSearchField> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  List<Map<String, dynamic>> _suggestions = [];
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialCode != null) {
      final match = StationData.stations.firstWhere(
        (s) => s['code'] == widget.initialCode, orElse: () => {});
      if (match.isNotEmpty) {
        _controller.text = '${match['name']} (${match['code']})';
      }
    }
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 150), () {
          if (mounted) setState(() => _showSuggestions = false);
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    final query = value.toLowerCase().trim();
    if (query.isEmpty) {
      setState(() { _suggestions = []; _showSuggestions = false; });
      widget.onSelected(null);
      return;
    }
    final filtered = StationData.stations.where((s) {
      final name = (s['name'] as String).toLowerCase();
      final code = (s['code'] as String).toLowerCase();
      return name.contains(query) || code.contains(query);
    }).toList();
    setState(() { _suggestions = filtered; _showSuggestions = filtered.isNotEmpty; });
  }

  void _select(Map<String, dynamic> station) {
    _controller.text = '${station['name']} (${station['code']})';
    _focusNode.unfocus();
    setState(() => _showSuggestions = false);
    widget.onSelected(station['code'] as String);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          onChanged: _onChanged,
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: 'Type station name...',
            prefixIcon: Icon(widget.icon),
            border: const OutlineInputBorder(),
            suffixIcon: _controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _controller.clear();
                      widget.onSelected(null);
                      setState(() => _showSuggestions = false);
                    })
                : null,
          ),
        ),
        if (_showSuggestions)
          Container(
            margin: const EdgeInsets.only(top: 2),
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 3))],
            ),
            child: ListView.separated(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: _suggestions.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
              itemBuilder: (context, index) {
                final s = _suggestions[index];
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.train, size: 18),
                  title: Text(s['name'] as String,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(s['code'] as String,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal.shade700)),
                  ),
                  onTap: () => _select(s),
                );
              },
            ),
          ),
      ],
    );
  }
}



class SmartPlanScreen extends StatefulWidget {
  const SmartPlanScreen({super.key});

  @override
  State<SmartPlanScreen> createState() => _SmartPlanScreenState();
}

class _SmartPlanScreenState extends State<SmartPlanScreen> {
  String? _selectedSource;
  String? _selectedDest;
  final _pickupAddressController = TextEditingController();
  final _destAddressController = TextEditingController();

  Future<List<CombinedTravelPlan>>? _planFuture;
  final SmartPlanner _planner = SmartPlanner();
  bool _fetchingLocation = false;
  bool _isSearching = false;

  bool _initialized = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      
      // Read args if navigated from assistant screen
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      bool hasArgs = false;
      if (args != null) {
        hasArgs = true;
        if (args['source'] != null) _selectedSource = args['source'];
        if (args['destination'] != null) _selectedDest = args['destination'];
        if (args['pickup'] != null && args['pickup'].toString().trim().isNotEmpty) {
          _pickupAddressController.text = args['pickup'];
        }
        if (args['dropoff'] != null && args['dropoff'].toString().trim().isNotEmpty) {
          _destAddressController.text = args['dropoff'];
        }
      }
      
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        // Auto-load GPS location if pickup is empty
        if (_pickupAddressController.text.trim().isEmpty) {
          await _useCurrentLocation();
        }

        // Auto-trigger search if we have all necessary info
        if (hasArgs && _pickupAddressController.text.trim().isNotEmpty && _destAddressController.text.trim().isNotEmpty) {
          _searchPlans();
        }
      });
    }
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _fetchingLocation = true);
    final locationService = context.read<LocationService>();
    await locationService.getCurrentPosition();
    if (mounted && locationService.currentLatLng != null) {
      setState(() {
        _pickupAddressController.text = 'My Current Location';
        _fetchingLocation = false;
      });
    } else {
      if (mounted) setState(() => _fetchingLocation = false);
    }
  }

  Future<void> _searchPlans() async {
    final originAddress = _pickupAddressController.text.trim();
    final destAddress = _destAddressController.text.trim();

    if (_selectedSource == null || _selectedDest == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both boarding and destination stations')),
      );
      return;
    }

    if (originAddress.isEmpty || destAddress.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both origin and destination addresses')),
      );
      return;
    }

    setState(() {
      _isSearching = true;
      _planFuture = null; // clear previous
    });

    try {
      // 1. Geocode Origin Address
      double originLat;
      double originLng;
      if (originAddress == 'My Current Location') {
        final loc = context.read<LocationService>().currentLatLng;
        if (loc == null) throw Exception('Location not available');
        originLat = loc.latitude;
        originLng = loc.longitude;
      } else {
        final originGeoUrl = Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(originAddress)}&format=json&limit=1',
        );
        final originGeoResponse = await http.get(originGeoUrl, headers: {
          'User-Agent': 'SmartTravelApp/1.0',
        }).timeout(const Duration(seconds: 10));

        if (originGeoResponse.statusCode != 200) throw Exception('Origin Geocoding failed');
        final originData = jsonDecode(originGeoResponse.body) as List;
        if (originData.isEmpty) throw Exception('Origin address not found');
        
        originLat = double.parse(originData[0]['lat'] as String);
        originLng = double.parse(originData[0]['lon'] as String);
      }

      // 2. Geocode Destination Address
      double destLat;
      double destLng;
      if (destAddress == 'My Current Location') {
        final loc = context.read<LocationService>().currentLatLng;
        if (loc == null) throw Exception('Location not available');
        destLat = loc.latitude;
        destLng = loc.longitude;
      } else {
        final destGeoUrl = Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(destAddress)}&format=json&limit=1',
        );
        final destGeoResponse = await http.get(destGeoUrl, headers: {
          'User-Agent': 'SmartTravelApp/1.0',
        }).timeout(const Duration(seconds: 10));

        if (destGeoResponse.statusCode != 200) throw Exception('Destination Geocoding failed');
        final destData = jsonDecode(destGeoResponse.body) as List;
        if (destData.isEmpty) throw Exception('Destination address not found');

        destLat = double.parse(destData[0]['lat'] as String);
        destLng = double.parse(destData[0]['lon'] as String);
      }

      setState(() {
        _planFuture = _planner.planJourney(
          sourceStation: _selectedSource!,
          destinationStation: _selectedDest!,
          originLat: originLat,
          originLng: originLng,
          destLat: destLat,
          destLng: destLng,
        );
        _isSearching = false;
      });
    } catch (e) {
      setState(() => _isSearching = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    }
  }

  @override
  void dispose() {
    _pickupAddressController.dispose();
    _destAddressController.dispose();
    _planner.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Travel Planner'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSearchCard(),
            const SizedBox(height: 16),
            if (_planFuture != null) _buildResultsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Plan Your Door-to-Door Journey',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Where are you starting from?',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _pickupAddressController,
                  decoration: const InputDecoration(
                    labelText: 'Origin Address (Pick-up)',
                    hintText: 'e.g., Home, Gateway of India',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.home),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _StationSearchField(
              label: 'Boarding Station',
              icon: Icons.train,
              initialCode: _selectedSource,
              onSelected: (code) => setState(() => _selectedSource = code),
            ),
            const SizedBox(height: 16),
            _StationSearchField(
              label: 'Destination Station',
              icon: Icons.train,
              initialCode: _selectedDest,
              onSelected: (code) => setState(() => _selectedDest = code),
            ),
            const SizedBox(height: 16),
            // Final Destination Row
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Where should the local transport drop you off?',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _destAddressController,
                  decoration: const InputDecoration(
                    labelText: 'Drop-off Location',
                    hintText: 'e.g., Hotel, Gateway of India',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.flag),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // GPS Button
            OutlinedButton.icon(
              onPressed: _fetchingLocation ? null : _useCurrentLocation,
              icon: _fetchingLocation
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.my_location, color: Colors.teal),
              label: Text(
                _fetchingLocation ? 'Getting Location...' : '📍 Use My Location',
                style: const TextStyle(color: Colors.teal),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.teal),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSearching ? null : _searchPlans,
                icon: _isSearching 
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.search),
                label: Text(_isSearching ? 'Planning...' : 'Find Smart Plans'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsSection() {
    return FutureBuilder<List<CombinedTravelPlan>>(
      future: _planFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                children: [
                  CircularProgressIndicator(color: Colors.teal),
                  SizedBox(height: 16),
                  Text('Finding best travel options...'),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Card(
            color: Colors.red.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.error, color: Colors.red),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      snapshot.error.toString().replaceAll('SmartPlannerException: ', ''),
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final plans = snapshot.data ?? [];
        if (plans.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No travel plans found for this route'),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${plans.length} Train Plan(s) Found',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...plans.map((plan) => _buildPlanCard(plan)),
          ],
        );
      },
    );
  }

  Widget _buildPlanCard(CombinedTravelPlan plan) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      child: Column(
        children: [
          // Train Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.train, color: Colors.teal),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        plan.train.trainName,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.teal,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '#${plan.train.trainNumber}',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildTimeColumn('Dep', plan.train.departureTime),
                    const Icon(Icons.arrow_forward, color: Colors.grey),
                    _buildTimeColumn('Arr', plan.train.arrivalTime),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        plan.train.duration,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Origin Transport Section
          if (plan.originTransportOptions.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.directions_bus, color: Colors.amber),
                      const SizedBox(width: 8),
                      const Text('Origin ➔ Boarding Station', style: TextStyle(fontWeight: FontWeight.bold)),
                      const Spacer(),
                      if (plan.errorMessage != null)
                        const Chip(
                          label: Text('Estimate Only'),
                          backgroundColor: Colors.orange,
                          labelStyle: TextStyle(color: Colors.white, fontSize: 10),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...plan.originTransportOptions.take(2).map((cab) => _buildCabOption(cab)),
                ],
              ),
            ),

          // Destination Transport Section
          if (plan.destTransportOptions.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.local_taxi, color: Colors.amber),
                      const SizedBox(width: 8),
                      const Text('Destination Station ➔ Drop-off', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...plan.destTransportOptions.take(2).map((cab) => _buildCabOption(cab)),
                ],
              ),
            ),
          const SizedBox(height: 16),
          // Summary + Save button
          Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Local Transport:', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    Text(
                      plan.estimatedTransportCost,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal, fontSize: 16),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    await DatabaseHelper().insertJourney({
                      'source': plan.train.sourceStation,
                      'destination': plan.train.destinationStation,
                      'date': DateTime.now().toIso8601String(),
                      'notes': '${plan.train.trainName} #${plan.train.trainNumber}',
                    });
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Trip saved to history!')),
                      );
                    }
                  },
                  icon: const Icon(Icons.bookmark_add_rounded, size: 16),
                  label: const Text('Save Trip'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: const Size(0, 36),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeColumn(String label, String time) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        Text(time, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildCabOption(UberPriceEstimate cab) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(cab.displayName),
          Text(cab.priceRange, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(cab.durationFormatted, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }
}
