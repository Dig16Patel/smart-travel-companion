import 'dart:math';

/// The four transport modes evaluated for availability.
enum TransportMode { car, bike, auto, bus }

extension TransportModeLabel on TransportMode {
  String get label {
    switch (this) {
      case TransportMode.car:   return 'Car (Ola / Uber)';
      case TransportMode.bike:  return 'Bike (Rapido)';
      case TransportMode.auto:  return 'Auto Rickshaw';
      case TransportMode.bus:   return 'City Bus';
    }
  }

  String get emoji {
    switch (this) {
      case TransportMode.car:   return '🚗';
      case TransportMode.bike:  return '🏍️';
      case TransportMode.auto:  return '🛺';
      case TransportMode.bus:   return '🚌';
    }
  }
}


enum AvailabilityLevel { none, low, medium, high }

/// Result for a single transport mode.
class TransportAvailability {
  final TransportMode mode;
  final AvailabilityLevel level;
  final int percentage;
  final String reason; // why unavailable (empty when available)

  const TransportAvailability({
    required this.mode,
    required this.level,
    required this.percentage,
    this.reason = '',
  });
}

/// Pure, stateless service — easy to unit-test and reuse.
class TransportAvailabilityService {
  /// Computes availability for all four modes.
  ///
  /// [distanceKm]     road distance between origin and destination.
  /// [now]            current date-time (injected so it's testable).
  /// [routeFound]     false when Nominatim could not geocode a location.
  /// [passengerCount] number of passengers to validate capacity against.
  List<TransportAvailability> compute(
    double distanceKm,
    DateTime now, {
    bool routeFound = true,
    int passengerCount = 1,
  }) {
    // If the route itself doesn't exist, nothing is available.
    if (!routeFound) {
      return TransportMode.values
          .map((m) => TransportAvailability(
                mode: m,
                level: AvailabilityLevel.none,
                percentage: 0,
                reason: 'Route not found',
              ))
          .toList();
    }

    // ── 1. Distance-eligible modes ─────────────────────────────────────────
    final distanceEligible = <TransportMode>{};

    if (distanceKm < 2) {
      // Very short: bike and auto make sense
      distanceEligible.addAll([TransportMode.bike, TransportMode.auto]);
    } else if (distanceKm <= 50) {
      // Short-Medium (City bounds): all local options
      distanceEligible.addAll([
        TransportMode.bike,
        TransportMode.auto,
        TransportMode.car,
        TransportMode.bus,
      ]);
    } else {
      // Long / Intercity: no bike, no auto
      distanceEligible.addAll([
        TransportMode.car,
        TransportMode.bus,
      ]);
    }

    // ── 2. Time-eligible modes ─────────────────────────────────────────────
    final hour = now.hour;
    final isNight = hour >= 22 || hour < 6; // 10 PM – 6 AM

    // ── 3. Random availability factor ──────────────────────────────────────
    // Seed by distance so results are stable per route but vary across routes.
    final rng = Random(distanceKm.toInt() + now.minute);

    // ── 4. Combine and return ──────────────────────────────────────────────
    return TransportMode.values.map((mode) {
      // Capacity check
      if (mode == TransportMode.bike && passengerCount > 1) {
        return TransportAvailability(
          mode: mode,
          level: AvailabilityLevel.none,
          percentage: 0,
          reason: 'Max 1 passenger',
        );
      }
      if (mode == TransportMode.auto && passengerCount > 3) {
        return TransportAvailability(
          mode: mode,
          level: AvailabilityLevel.none,
          percentage: 0,
          reason: 'Max 3 passengers',
        );
      }
      if (mode == TransportMode.car && passengerCount > 4) {
        return TransportAvailability(
          mode: mode,
          level: AvailabilityLevel.none,
          percentage: 0,
          reason: 'Max 4 passengers',
        );
      }

      // Distance check
      if (!distanceEligible.contains(mode)) {
        final reason = distanceKm < 2
            ? 'Too short for ${mode.label}'
            : (mode == TransportMode.bike || mode == TransportMode.auto)
                ? '${mode.label.split(' ')[0]} not available for long distance'
                : 'Not suitable for this distance';
        return TransportAvailability(
          mode: mode,
          level: AvailabilityLevel.none,
          percentage: 0,
          reason: reason,
        );
      }

      // Night-time check (bus only)
      if (isNight && mode == TransportMode.bus) {
        return TransportAvailability(
          mode: mode,
          level: AvailabilityLevel.none,
          percentage: 0,
          reason: 'Not available at night (10 PM – 6 AM)',
        );
      }

      // Base percentages based on mode, tweaked slightly if it's night
      int minP = 0, maxP = 100;
      switch (mode) {
        case TransportMode.car:   minP = isNight ? 50 : 75; maxP = isNight ? 85 : 95; break;
        case TransportMode.bike:  minP = isNight ? 30 : 60; maxP = isNight ? 70 : 85; break;
        case TransportMode.auto:  minP = isNight ? 40 : 65; maxP = isNight ? 75 : 90; break;
        case TransportMode.bus:   minP = 85; maxP = 98; break;
      }

      final pct = minP + rng.nextInt(maxP - minP + 1);

      AvailabilityLevel level;
      if (pct >= 80) {
        level = AvailabilityLevel.high;
      } else if (pct >= 50) {
        level = AvailabilityLevel.medium;
      } else {
        level = AvailabilityLevel.low;
      }

      return TransportAvailability(
        mode: mode,
        level: level,
        percentage: pct,
        reason: '',
      );
    }).toList();
  }
}
