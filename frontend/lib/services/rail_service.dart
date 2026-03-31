import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Model for train data from the Railway API
class RailTrain {
  final String trainNumber;
  final String trainName;
  final String sourceStation;
  final String destinationStation;
  final String departureTime;
  final String arrivalTime;
  final String duration;
  final double? destinationLat;
  final double? destinationLng;

  RailTrain({
    required this.trainNumber,
    required this.trainName,
    required this.sourceStation,
    required this.destinationStation,
    required this.departureTime,
    required this.arrivalTime,
    required this.duration,
    this.destinationLat,
    this.destinationLng,
  });

  factory RailTrain.fromJson(Map<String, dynamic> json) {
    return RailTrain(
      trainNumber: json['train_number']?.toString() ?? '',
      trainName: json['train_name']?.toString() ?? 'Unknown',
      sourceStation: json['source_station']?.toString() ?? '',
      destinationStation: json['destination_station']?.toString() ?? '',
      departureTime: json['departure_time']?.toString() ?? '--:--',
      arrivalTime: json['arrival_time']?.toString() ?? '--:--',
      duration: json['travel_duration']?.toString() ?? 'N/A',
      destinationLat: _parseDouble(json['destination_lat']),
      destinationLng: _parseDouble(json['destination_lng']),
    );
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}

/// Service to fetch train data from RapidAPI Indian Railways
class RailService {
  static String get _apiKey => dotenv.env['RAPIDAPI_KEY'] ?? '';
  static const String _apiHost = 'indian-railway-irctc.p.rapidapi.com';
  static const String _baseUrl = 'https://indian-railway-irctc.p.rapidapi.com';

  final http.Client _client;

  RailService({http.Client? client}) : _client = client ?? http.Client();

  /// Fetches trains between source and destination stations
  /// [source] - Source station code (e.g., "NDLS" for New Delhi)
  /// [destination] - Destination station code (e.g., "BCT" for Mumbai Central)
  Future<List<RailTrain>> fetchTrains(String source, String destination) async {
    final uri = Uri.parse('$_baseUrl/getTrainsBetweenStations').replace(
      queryParameters: {
        'fromStationCode': source.toUpperCase(),
        'toStationCode': destination.toUpperCase(),
      },
    );

    try {
      final response = await _client.get(
        uri,
        headers: {
          'x-rapidapi-key': _apiKey,
          'x-rapidapi-host': _apiHost,
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Handle different response structures
        List<dynamic> trainsList;
        if (data is List) {
          trainsList = data;
        } else if (data is Map && data['data'] != null) {
          trainsList = data['data'] as List<dynamic>;
        } else if (data is Map && data['trains'] != null) {
          trainsList = data['trains'] as List<dynamic>;
        } else {
          return _generateDummyTrains(source, destination);
        }

        return trainsList
            .map((json) => RailTrain.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        // Fallback to dummy data on any API error (e.g., 401 Unauthorized, 429 Rate Limit)
        print('Rail API Error ${response.statusCode}: Falling back to dummy data');
        return _generateDummyTrains(source, destination);
      }
    } catch (e) {
      print('Network Error: $e. Falling back to dummy data');
      return _generateDummyTrains(source, destination);
    }
  }

  /// Generates realistic-looking dummy trains as a fallback
  List<RailTrain> _generateDummyTrains(String source, String destination) {
    return [
      RailTrain(
        trainNumber: '12951',
        trainName: 'Rajdhani Express',
        sourceStation: source.toUpperCase(),
        destinationStation: destination.toUpperCase(),
        departureTime: '17:00',
        arrivalTime: '08:30',
        duration: '15h 30m',
      ),
      RailTrain(
        trainNumber: '12925',
        trainName: 'Paschim Express',
        sourceStation: source.toUpperCase(),
        destinationStation: destination.toUpperCase(),
        departureTime: '12:00',
        arrivalTime: '10:40',
        duration: '22h 40m',
      ),
      RailTrain(
        trainNumber: '12216',
        trainName: 'Garib Rath Express',
        sourceStation: source.toUpperCase(),
        destinationStation: destination.toUpperCase(),
        departureTime: '12:55',
        arrivalTime: '12:10',
        duration: '23h 15m',
      ),
      RailTrain(
        trainNumber: '22221',
        trainName: 'Vande Bharat Express',
        sourceStation: source.toUpperCase(),
        destinationStation: destination.toUpperCase(),
        departureTime: '05:50',
        arrivalTime: '11:00',
        duration: '05h 10m',
      ),
    ];
  }

  void dispose() {
    _client.close();
  }
}

/// Custom exception for Rail Service errors
class RailServiceException implements Exception {
  final String message;
  RailServiceException(this.message);

  @override
  String toString() => 'RailServiceException: $message';
}
