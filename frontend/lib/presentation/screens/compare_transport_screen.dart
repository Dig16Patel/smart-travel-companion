import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../data/location_service.dart';
import '../../data/locations_data.dart';
import '../../data/taxi_estimator.dart';
import '../../models/travel_models.dart';

class CompareTransportScreen extends StatefulWidget {
  const CompareTransportScreen({super.key});

  @override
  State<CompareTransportScreen> createState() => _CompareTransportScreenState();
}

class _CompareTransportScreenState extends State<CompareTransportScreen> {
  final _fromController = TextEditingController(text: 'My Location');
  final _toController = TextEditingController();
  final _fromFocusNode = FocusNode();
  final _toFocusNode = FocusNode();
  bool _useCurrentLocation = true;
  int _passengerCount = 1;
  final _passengerController = TextEditingController(text: '1');

  List<TransportOption> _options = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _bestSuggestion = '';
  double? _distanceKm;

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    _fromFocusNode.dispose();
    _toFocusNode.dispose();
    _passengerController.dispose();
    super.dispose();
  }

  Future<void> _compareRoutes() async {
    final origin = _fromController.text.trim();
    final destination = _toController.text.trim();

    if (origin.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a starting location')),
      );
      return;
    }
    if (destination.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a destination')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _options = [];
      _distanceKm = null;
      _bestSuggestion = '';
    });

    try {
      double originLat, originLng;

      if (_useCurrentLocation) {
        // Use GPS
        final locationService = context.read<LocationService>();
        final position = await locationService.getCurrentPosition();
        if (position == null) {
          throw Exception('Could not get your current location. Enable GPS.');
        }
        originLat = position.latitude;
        originLng = position.longitude;
      } else {
        // Geocode the custom From location
        final fromUrl = Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(origin)}&format=json&limit=1',
        );
        final fromResponse = await http.get(fromUrl, headers: {
          'User-Agent': 'SmartTravelApp/1.0',
        }).timeout(const Duration(seconds: 10));

        if (fromResponse.statusCode != 200) {
          throw Exception('Could not geocode the starting location.');
        }
        final fromData = jsonDecode(fromResponse.body) as List;
        if (fromData.isEmpty) {
          throw Exception('Starting location not found. Try a more specific name.');
        }
        originLat = double.parse(fromData[0]['lat'] as String);
        originLng = double.parse(fromData[0]['lon'] as String);
      }

      // Geocode destination using Nominatim
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
        throw Exception('Destination not found. Try a more specific name.');
      }

      final destLat = double.parse(geoData[0]['lat'] as String);
      final destLng = double.parse(geoData[0]['lon'] as String);

      // Calculate distance
      final distMeters = Geolocator.distanceBetween(
        originLat, originLng,
        destLat, destLng,
      );
      final roadKm = (distMeters / 1000) * 1.3;

      if (roadKm > 1000) {
        throw Exception('Destination is too far (> 1000km). Use flights instead.');
      }

      // Generate local transport options
      final taxiEstimator = TaxiFareEstimator();
      final taxiEstimates = taxiEstimator.getEstimates(roadKm);

      final List<TransportOption> options = [];

      // Add intercity Train option if distance is > 50km
      if (roadKm > 50) {
        final trainFare = (roadKm * 2.5).round();
        final trainHours = (roadKm / 60).toStringAsFixed(1);
        options.add(TransportOption(
          provider: 'Train',
          eta: '~$trainHours hrs',
          duration: '~$trainHours hrs',
          fare: '₹$trainFare',
          convenience: 3.5,
          emoji: '🚆',
          vehicleType: 'Train',
          rawFare: trainFare,
          isPerPerson: true, // each passenger needs a ticket
        ));
      }

      // Capacity per vehicle type
      const Map<String, int> capacity = {
        'bus': 50,
        'bike': 1,
        'auto': 3,
        'mini': 4,
        'go': 4,
        'train': 500,
        'car': 4,
      };

      // Add taxi options (filter by capacity)
      for (final taxi in taxiEstimates) {
        String icon = '';
        double convenience = 4.0;

        switch (taxi.provider.toLowerCase()) {
          case 'city bus':
            icon = '🚌';
            convenience = 2.5;
            break;
          case 'rapido':
            icon = '🏍️';
            convenience = 3.5;
            break;
          case 'auto':
            icon = '🛺';
            convenience = 3.8;
            break;
          case 'ola':
            icon = '🚕';
            convenience = 4.2;
            break;
          case 'uber':
            icon = '🚗';
            convenience = 4.5;
            break;
        }

        final cap = capacity[taxi.vehicleType.toLowerCase()] ?? 4;
        if (cap < _passengerCount) continue; // skip if can't fit passengers

        final perPerson = taxi.vehicleType.toLowerCase() == 'bus';
        options.add(TransportOption(
          provider: taxi.provider,
          eta: taxi.tripTime,
          duration: taxi.tripTime,
          fare: '₹${taxi.estimatedFare}',
          convenience: convenience,
          emoji: icon,
          vehicleType: taxi.vehicleType,
          rawFare: taxi.estimatedFare,
          isPerPerson: perPerson, // bus = per person; others = per vehicle
        ));
      }

      // Mark best option based on passenger count & distance
      if (options.isNotEmpty) {
        int bestIndex = 0;

        if (roadKm > 50) {
          // Long distance: train first, else bus
          final trainIdx = options.indexWhere((o) => o.vehicleType.toLowerCase() == 'train');
          final busIdx   = options.indexWhere((o) => o.vehicleType.toLowerCase() == 'bus');
          bestIndex = trainIdx != -1 ? trainIdx : (busIdx != -1 ? busIdx : 0);
          _bestSuggestion = trainIdx != -1
              ? 'Train is up to 70% cheaper for intercity travel.'
              : 'Bus is the most economical option for this distance.';
        } else if (_passengerCount == 1) {
          // Solo: Rapido Bike
          bestIndex = options.indexWhere((o) => o.vehicleType.toLowerCase() == 'bike');
          if (bestIndex == -1) bestIndex = 0;
          _bestSuggestion = 'Rapido Bike is the fastest and cheapest for a solo ride.';
        } else if (_passengerCount == 2) {
          // 2 people: Auto is most economical
          bestIndex = options.indexWhere((o) => o.vehicleType.toLowerCase() == 'auto');
          if (bestIndex == -1) bestIndex = options.indexWhere((o) => ['mini','go'].contains(o.vehicleType.toLowerCase()));
          if (bestIndex == -1) bestIndex = 0;
          _bestSuggestion = 'Auto splits the cost perfectly for 2 passengers.';
        } else if (_passengerCount <= 4) {
          // 3–4 people: Car is best value per person
          bestIndex = options.indexWhere((o) => o.vehicleType.toLowerCase() == 'mini');
          if (bestIndex == -1) bestIndex = options.indexWhere((o) => o.vehicleType.toLowerCase() == 'go');
          if (bestIndex == -1) bestIndex = 0;
          _bestSuggestion = 'A cab shared among $_passengerCount is the best per-person value.';
        } else {
          // 5+ people: Bus is only option that fits
          bestIndex = options.indexWhere((o) => o.vehicleType.toLowerCase() == 'bus');
          if (bestIndex == -1) bestIndex = 0;
          _bestSuggestion = 'City Bus is ideal for groups of $_passengerCount or more passengers.';
        }

        final best = options[bestIndex];
        options[bestIndex] = TransportOption(
          provider: best.provider,
          eta: best.eta,
          duration: best.duration,
          fare: best.fare,
          convenience: best.convenience,
          emoji: best.emoji,
          vehicleType: best.vehicleType,
          rawFare: best.rawFare,
          isPerPerson: best.isPerPerson,
          isBest: true,
        );
      }

      setState(() {
        _distanceKm = roadKm;
        _options = options;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Compare Options'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // ── Search Header ──────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            color: theme.colorScheme.surface,
            child: Column(
              children: [
                _buildLocationField(
                  controller: _fromController,
                  label: 'From',
                  icon: Icons.trip_origin,
                  iconColor: null,
                  showLocationReset: true,
                ),
                const SizedBox(height: 8),
                _buildLocationField(
                  controller: _toController,
                  label: 'To Destination',
                  icon: Icons.place,
                  iconColor: Colors.red,
                  showLocationReset: false,
                ),
                const SizedBox(height: 12),
                // ── Passenger selector ─────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 8),
                      const Icon(Icons.people, size: 20),
                      const SizedBox(width: 8),
                      const Text('Passengers', style: TextStyle(fontSize: 14)),
                      const Spacer(),
                      // Decrease
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
                      // Editable count field
                      Container(
                        width: 52,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
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
                      // Increase
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
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _compareRoutes,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.compare_arrows),
                    label: Text(_isLoading ? 'Comparing...' : 'Compare Fares'),
                  ),
                ),
              ],
            ),
          ),

          // ── Results Body ──────────────────────────────────────────────
          Expanded(child: _buildBody(theme)),
        ],
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.orange),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    if (_options.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'Enter a destination to compare modes',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildSuggestionBanner(theme),
        if (_distanceKm != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            child: Text(
              'Route distance: ~${_distanceKm!.toStringAsFixed(1)} km',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _options.length,
            itemBuilder: (context, index) {
              final option = _options[index];
              return _buildComparisonCard(theme, option);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSuggestionBanner(ThemeData theme) {
    if (_bestSuggestion.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      color: theme.colorScheme.primaryContainer,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: [
          Icon(Icons.tips_and_updates, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Smart Suggestion',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _bestSuggestion,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonCard(ThemeData theme, TransportOption option) {
    // Map vehicle types to colours for the chip
    Color chipColor;
    switch (option.vehicleType.toLowerCase()) {
      case 'bus':
        chipColor = Colors.green.shade700;
        break;
      case 'bike':
        chipColor = Colors.orange.shade700;
        break;
      case 'auto':
        chipColor = Colors.amber.shade800;
        break;
      case 'mini':
      case 'go':
        chipColor = Colors.blue.shade700;
        break;
      case 'train':
        chipColor = Colors.purple.shade700;
        break;
      default:
        chipColor = Colors.grey.shade700;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: option.isBest ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: option.isBest ? theme.colorScheme.primary : Colors.transparent,
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Left: emoji + provider name + BEST badge
                Expanded(
                  child: Row(
                    children: [
                      // Big emoji
                      Text(option.emoji, style: const TextStyle(fontSize: 28)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Provider name
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    option.provider,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold, fontSize: 16),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (option.isBest) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text('BEST',
                                        style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            // Vehicle-type chip
                            if (option.vehicleType.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: chipColor,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  option.vehicleType,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Right: fare column
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Main fare figure
                    Text(
                      _passengerCount > 1 && option.isPerPerson
                          ? '₹${option.rawFare * _passengerCount}'  // total for public
                          : option.fare,                             // vehicle fare
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: option.isBest ? theme.colorScheme.primary : null,
                      ),
                    ),
                    // Breakdown subtitle
                    if (_passengerCount > 1 && option.rawFare > 0) ...[
                      const SizedBox(height: 2),
                      if (option.isPerPerson)
                        Text(
                          '₹${option.rawFare}/person',
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        )
                      else
                        Text(
                          '₹${(option.rawFare / _passengerCount).ceil()}/person',
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMetric(Icons.timer, 'Time', option.duration),
                _buildMetric(Icons.star, 'Comfort', '${option.convenience}/5.0'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetric(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 4),
        Text(
          '$label: $value',
          style: const TextStyle(color: Colors.grey, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildLocationField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    Color? iconColor,
    required bool showLocationReset,
  }) {
    return RawAutocomplete<String>(
      textEditingController: controller,
      focusNode: showLocationReset ? _fromFocusNode : _toFocusNode,
      optionsBuilder: (TextEditingValue tv) {
        return LocationsData.search(tv.text);
      },
      onSelected: (String selection) {
        controller.text = selection;
        if (showLocationReset) {
          setState(() {
            _useCurrentLocation = false;
          });
        }
      },
      fieldViewBuilder: (context, ctrl, focusNode, onFieldSubmitted) {
        return TextField(
          controller: ctrl,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon, color: iconColor),
            border: const OutlineInputBorder(),
            suffixIcon: showLocationReset
                ? IconButton(
                    tooltip: 'Use my current location',
                    icon: Icon(
                      Icons.my_location,
                      color: _useCurrentLocation
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        controller.text = 'My Location';
                        _useCurrentLocation = true;
                      });
                    },
                  )
                : null,
          ),
          onChanged: (v) {
            if (showLocationReset) {
              setState(() {
                _useCurrentLocation = v.trim().isEmpty ||
                    v.trim().toLowerCase() == 'my location';
              });
            }
          },
          onSubmitted: (_) {
            onFieldSubmitted();
            _compareRoutes();
          },
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220, maxWidth: 400),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.location_city, size: 18),
                    title: Text(option),
                    onTap: () => onSelected(option),
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
