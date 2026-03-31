import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Model for Uber price estimate
class UberPriceEstimate {
  final String productId;
  final String displayName;
  final String currencyCode;
  final int lowEstimate;
  final int highEstimate;
  final double distance;
  final int duration; // in seconds
  final String surgeMultiplier;

  UberPriceEstimate({
    required this.productId,
    required this.displayName,
    required this.currencyCode,
    required this.lowEstimate,
    required this.highEstimate,
    required this.distance,
    required this.duration,
    required this.surgeMultiplier,
  });

  factory UberPriceEstimate.fromJson(Map<String, dynamic> json) {
    return UberPriceEstimate(
      productId: json['product_id']?.toString() ?? '',
      displayName: json['display_name']?.toString() ?? 'Uber',
      currencyCode: json['currency_code']?.toString() ?? 'INR',
      lowEstimate: _parseInt(json['low_estimate']) ?? 0,
      highEstimate: _parseInt(json['high_estimate']) ?? 0,
      distance: _parseDouble(json['distance']) ?? 0.0,
      duration: _parseInt(json['duration']) ?? 0,
      surgeMultiplier: json['surge_multiplier']?.toString() ?? '1.0',
    );
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  /// Returns formatted price range string
  String get priceRange => '$currencyCode $lowEstimate - $highEstimate';

  /// Returns formatted duration string
  String get durationFormatted {
    final minutes = (duration / 60).round();
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    return '${hours}h ${remainingMinutes}m';
  }
}

/// Service to fetch Uber price estimates
class UberService {
  static String get _serverToken => dotenv.env['UBER_SERVER_TOKEN'] ?? '';
  static const String _baseUrl = 'https://sandbox-api.uber.com/v1.2';

  final http.Client _client;

  UberService({http.Client? client}) : _client = client ?? http.Client();

  /// Fetches price estimates from Uber API
  /// [startLat], [startLng] - Pickup location coordinates
  /// [endLat], [endLng] - Dropoff location coordinates
  Future<List<UberPriceEstimate>> getUberPrice(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) async {
    final uri = Uri.parse('$_baseUrl/estimates/price').replace(
      queryParameters: {
        'start_latitude': startLat.toString(),
        'start_longitude': startLng.toString(),
        'end_latitude': endLat.toString(),
        'end_longitude': endLng.toString(),
      },
    );

    try {
      final response = await _client.get(
        uri,
        headers: {
          'Authorization': 'Token $_serverToken',
          'Accept-Language': 'en_US',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final prices = data['prices'] as List<dynamic>? ?? [];
        
        return prices
            .map((json) => UberPriceEstimate.fromJson(json as Map<String, dynamic>))
            .toList();
      } else if (response.statusCode == 401) {
        throw UberServiceException('Invalid Server Token. Please check your Uber credentials.');
      } else if (response.statusCode == 422) {
        throw UberServiceException('Invalid coordinates provided.');
      } else if (response.statusCode == 429) {
        throw UberServiceException('Rate limit exceeded. Please try again later.');
      } else {
        throw UberServiceException('Failed to fetch prices: ${response.statusCode}');
      }
    } on FormatException {
      throw UberServiceException('Invalid response format from API');
    } catch (e) {
      if (e is UberServiceException) rethrow;
      throw UberServiceException('Network error: $e');
    }
  }

  void dispose() {
    _client.close();
  }
}

/// Custom exception for Uber Service errors
class UberServiceException implements Exception {
  final String message;
  UberServiceException(this.message);

  @override
  String toString() => 'UberServiceException: $message';
}
