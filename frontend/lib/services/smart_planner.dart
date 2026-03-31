import 'package:geolocator/geolocator.dart';
import 'rail_service.dart';
import 'uber_service.dart';
import '../data/taxi_estimator.dart';
import '../data/station_data.dart';

/// Combined travel plan with train and local transport details
class CombinedTravelPlan {
  final RailTrain train;
  final List<UberPriceEstimate> originTransportOptions;
  final List<UberPriceEstimate> destTransportOptions;
  final double sourceLat;
  final double sourceLng;
  final double destLat;
  final double destLng;
  final double originLat;
  final double originLng;
  final double finalDestLat;
  final double finalDestLng;
  final String? errorMessage;

  CombinedTravelPlan({
    required this.train,
    required this.originTransportOptions,
    required this.destTransportOptions,
    required this.sourceLat,
    required this.sourceLng,
    required this.destLat,
    required this.destLng,
    required this.originLat,
    required this.originLng,
    required this.finalDestLat,
    required this.finalDestLng,
    this.errorMessage,
  });

  /// Returns the cheapest origin local transport
  UberPriceEstimate? get cheapestOriginTransport {
    if (originTransportOptions.isEmpty) return null;
    return originTransportOptions.reduce((a, b) => 
      a.lowEstimate < b.lowEstimate ? a : b);
  }

  /// Returns the cheapest destination local transport
  UberPriceEstimate? get cheapestDestTransport {
    if (destTransportOptions.isEmpty) return null;
    return destTransportOptions.reduce((a, b) => 
      a.lowEstimate < b.lowEstimate ? a : b);
  }

  /// Returns total estimated transport cost (train fare not included)
  String get estimatedTransportCost {
    final origin = cheapestOriginTransport;
    final dest = cheapestDestTransport;
    
    if (origin == null && dest == null) return 'N/A';
    
    int min = (origin?.lowEstimate ?? 0) + (dest?.lowEstimate ?? 0);
    int max = (origin?.highEstimate ?? 0) + (dest?.highEstimate ?? 0);
    
    return 'INR $min - $max';
  }

  /// Checks if the plan has any transport options available
  bool get hasTransportOptions => originTransportOptions.isNotEmpty || destTransportOptions.isNotEmpty;
}

/// Smart planner that combines train and cab bookings
class SmartPlanner {
  final RailService _railService;
  final UberService _uberService;

  SmartPlanner({
    RailService? railService,
    UberService? uberService,
  })  : _railService = railService ?? RailService(),
        _uberService = uberService ?? UberService();

  /// Gets station coordinates from code
  /// Returns null if station not found
  Map<String, double>? getStationCoordinates(String stationCode) {
    return StationData.getCoordinates(stationCode);
  }

  /// Plans a complete journey from source station to home
  /// 
  /// [sourceStation] - Source station code (e.g., "NDLS")
  /// [destinationStation] - Destination station code (e.g., "BCT")
  /// [homeLat], [homeLng] - User's home/final destination coordinates
  Future<List<CombinedTravelPlan>> planJourney({
    required String sourceStation,
    required String destinationStation,
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  }) async {
    // Step 1: Fetch available trains
    final trains = await _railService.fetchTrains(sourceStation, destinationStation);
    
    if (trains.isEmpty) {
      throw SmartPlannerException('No trains found between $sourceStation and $destinationStation');
    }

    // Step 2: Get station coordinates
    final sourceCoords = getStationCoordinates(sourceStation);
    final statDestCoords = getStationCoordinates(destinationStation);
    
    double statSourceLat;
    double statSourceLng;
    double statDestLat;
    double statDestLng;
    
    if (sourceCoords != null) {
      statSourceLat = sourceCoords['lat']!;
      statSourceLng = sourceCoords['lng']!;
    } else {
      throw SmartPlannerException('Unable to find coordinates for station: $sourceStation');
    }

    if (statDestCoords != null) {
      statDestLat = statDestCoords['lat']!;
      statDestLng = statDestCoords['lng']!;
    } else if (trains.first.destinationLat != null && trains.first.destinationLng != null) {
      statDestLat = trains.first.destinationLat!;
      statDestLng = trains.first.destinationLng!;
    } else {
      throw SmartPlannerException('Unable to find coordinates for station: $destinationStation');
    }

    // Step 3: Fetch local transport options for both legs
    List<UberPriceEstimate> originTransport = [];
    List<UberPriceEstimate> destTransport = [];
    String? transportError;
    
    try {
      // Offline estimator (supports City Bus, Rapido, Auto, Ola, Uber)
      final originDistMeters = Geolocator.distanceBetween(
        originLat, originLng,
        statSourceLat, statSourceLng,
      );
      final destDistMeters = Geolocator.distanceBetween(
        statDestLat, statDestLng,
        destLat, destLng,
      );
      
      final originRoadKm = (originDistMeters / 1000) * 1.3;
      final destRoadKm = (destDistMeters / 1000) * 1.3;
      
      final estimator = TaxiFareEstimator();
      
      originTransport = _mapToUberPrice(estimator.getEstimates(originRoadKm), originRoadKm);
      destTransport = _mapToUberPrice(estimator.getEstimates(destRoadKm), destRoadKm);
      
    } catch (e) {
      transportError = 'Error calculating transport: $e';
    }

    // Step 4: Create combined plans for each train
    return trains.map((train) => CombinedTravelPlan(
      train: train,
      originTransportOptions: originTransport,
      destTransportOptions: destTransport,
      sourceLat: statSourceLat,
      sourceLng: statSourceLng,
      destLat: statDestLat,
      destLng: statDestLng,
      originLat: originLat,
      originLng: originLng,
      finalDestLat: destLat,
      finalDestLng: destLng,
      errorMessage: transportError,
    )).toList();
  }

  List<UberPriceEstimate> _mapToUberPrice(List<TaxiEstimate> estimates, double roadKm) {
    return estimates.map((est) {
      int durationSecs = 1200; // fallback 20 mins
      final match = RegExp(r'(\d+)').firstMatch(est.tripTime);
      if (match != null) {
        final val = int.tryParse(match.group(1) ?? '20') ?? 20;
        if (est.tripTime.contains('h')) {
          durationSecs = val * 3600; 
        } else {
          durationSecs = val * 60; 
        }
      }
      
      return UberPriceEstimate(
        productId: est.provider.toLowerCase(),
        displayName: est.provider,
        currencyCode: 'INR',
        lowEstimate: est.estimatedFare,
        highEstimate: est.estimatedFare + 20,
        distance: roadKm,
        duration: durationSecs,
        surgeMultiplier: '1.0',
      );
    }).toList();
  }

  Future<CombinedTravelPlan?> getQuickPlan({
    required RailTrain train,
    required String destinationStationCode,
    required double homeLat,
    required double homeLng,
  }) async {
    // Quick plan not actively used for door-to-door, but updated signature
    return null;
  }

  void dispose() {
    _railService.dispose();
    _uberService.dispose();
  }
}

/// Custom exception for Smart Planner errors
class SmartPlannerException implements Exception {
  final String message;
  SmartPlannerException(this.message);

  @override
  String toString() => 'SmartPlannerException: $message';
}
