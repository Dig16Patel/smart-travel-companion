class TaxiEstimate {
  final String provider;
  final int estimatedFare;
  final String tripTime; // estimated travel time based on distance
  final String vehicleType;
  final int maxPassengers;

  TaxiEstimate({
    required this.provider,
    required this.estimatedFare,
    required this.tripTime,
    this.vehicleType = 'Car',
    this.maxPassengers = 4,
  });
}

class TaxiFareEstimator {
  // Realistic 2025 Indian taxi rates
  // Base fare covers first 2km, then per-km rate applies

  static const double _olaBaseFare = 50.0;
  static const double _olaPerKm = 9.0;

  static const double _uberBaseFare = 55.0;
  static const double _uberPerKm = 10.0;

  static const double _rapidoBaseFare = 20.0;
  static const double _rapidoPerKm = 4.0;

  static const double _autoBaseFare = 30.0;
  static const double _autoPerKm = 6.0;

  /// Returns estimated travel time label based on distance and speed (km/h)
  static String _travelTime(double distanceKm, double avgSpeedKmh) {
    final minutes = (distanceKm / avgSpeedKmh * 60).round();
    if (minutes < 60) return '~$minutes min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '~${h}h' : '~${h}h ${m}m';
  }

  List<TaxiEstimate> getEstimates(double distanceKm) {
    final effectiveDistance = distanceKm < 1 ? 1.0 : distanceKm;
    final extraKm = (effectiveDistance - 2.0).clamp(0, double.infinity);

    final olaFare = (_olaBaseFare + (extraKm * _olaPerKm)).round();
    final uberFare = (_uberBaseFare + (extraKm * _uberPerKm)).round();
    final rapidoFare = (_rapidoBaseFare + (effectiveDistance * _rapidoPerKm)).round();
    final autoFare = (_autoBaseFare + (extraKm * _autoPerKm)).round();
    
    // Simulate city bus fare (₹10 minimum, roughly ₹2 per km after 5km)
    final busFare = effectiveDistance <= 5 ? 10 : (10 + ((effectiveDistance - 5) * 2)).round();

    return [
      TaxiEstimate(
        provider: "City Bus",
        estimatedFare: busFare,
        tripTime: _travelTime(effectiveDistance, 20), // bus: avg 20 km/h with stops
        vehicleType: "Bus",
        maxPassengers: 50,
      ),
      TaxiEstimate(
        provider: "Rapido",
        estimatedFare: rapidoFare,
        tripTime: _travelTime(effectiveDistance, 35), // bike: avg 35 km/h in city
        vehicleType: "Bike",
        maxPassengers: 1,
      ),
      TaxiEstimate(
        provider: "Auto",
        estimatedFare: autoFare,
        tripTime: _travelTime(effectiveDistance, 25), // auto: avg 25 km/h
        vehicleType: "Auto",
        maxPassengers: 3,
      ),
      TaxiEstimate(
        provider: "Ola",
        estimatedFare: olaFare,
        tripTime: _travelTime(effectiveDistance, 30), // car: avg 30 km/h
        vehicleType: "Mini",
        maxPassengers: 4,
      ),
      TaxiEstimate(
        provider: "Uber",
        estimatedFare: uberFare,
        tripTime: _travelTime(effectiveDistance, 30),
        vehicleType: "Go",
        maxPassengers: 4,
      ),
    ];
  }
}
