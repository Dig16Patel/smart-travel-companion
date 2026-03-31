import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class LocationService extends ChangeNotifier {
  Position? _currentPosition;
  bool _isLoading = false;
  String? _errorMessage;

  Position? get currentPosition => _currentPosition;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  LatLng? get currentLatLng => _currentPosition != null
      ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
      : null;

  /// Check if location services are enabled and permissions are granted
  Future<bool> checkPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _errorMessage = 'Location services are disabled. Please enable them.';
      notifyListeners();
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _errorMessage = 'Location permissions are denied.';
        notifyListeners();
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _errorMessage = 'Location permissions are permanently denied. Please enable them in settings.';
      notifyListeners();
      return false;
    }

    _errorMessage = null;
    return true;
  }

  /// Get the current position of the user
  Future<Position?> getCurrentPosition() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final hasPermission = await checkPermissions();
      if (!hasPermission) {
        _isLoading = false;
        notifyListeners();
        return null;
      }

      _currentPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 15), // Allow enough time for real GPS fix
        ),
      );

      // Only override if it's exactly the Google HQ Emulator default (Mountain View, CA)
      // Lat: 37.42..., Lng: -122.08... — this never happens on a real device
      if (_currentPosition != null &&
          _currentPosition!.latitude > 37.0 && _currentPosition!.latitude < 38.0 &&
          _currentPosition!.longitude < -121.0 && _currentPosition!.longitude > -123.0) {
        debugPrint('Detected Emulator Default Location (Google HQ). Using Ahmedabad fallback.');
        _currentPosition = Position(
          longitude: 72.5714, // Ahmedabad, Gujarat (emulator fallback only)
          latitude: 23.0225,
          timestamp: DateTime.now(),
          accuracy: 100,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        );
      }

      _isLoading = false;
      notifyListeners();
      return _currentPosition;
    } catch (e) {
      debugPrint('Location error: $e');
      // Surface a real error — do NOT silently use the wrong city on a real device
      _errorMessage = 'Could not get your location. Please ensure GPS is enabled and try again.';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Stream position updates for real-time tracking
  Stream<Position> getPositionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 meters
      ),
    );
  }

  /// Calculate distance between two points in kilometers
  double calculateDistance(LatLng from, LatLng to) {
    return Geolocator.distanceBetween(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    ) / 1000; // Convert to km
  }

  /// Open device location settings
  Future<void> openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }

  /// Open app settings for permissions
  Future<void> openAppSettings() async {
    await Geolocator.openAppSettings();
  }
}
