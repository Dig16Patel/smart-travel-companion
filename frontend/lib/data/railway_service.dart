import '../models/travel_models.dart';

abstract class RailwayService {
  Future<List<Train>> getTrainsBetweenStations(String fromStation, String toStation);
}

class MockRailwayService implements RailwayService {
  @override
  Future<List<Train>> getTrainsBetweenStations(String fromStation, String toStation) async {
    // Simulate API delay
    await Future.delayed(const Duration(milliseconds: 500));
    return [
      Train(
        number: "12901",
        name: "Gujarat Mail",
        departure: "22:10",
        arrival: "01:25",
        duration: "3h 15m",
        stops: ["Mumbai", "Surat", "Ahmedabad"],
      ),
      Train(
        number: "12009",
        name: "Shatabdi Exp",
        departure: "14:40",
        arrival: "15:45",
        duration: "1h 05m",
        stops: ["Mumbai", "Vapi", "Surat"],
      ),
      Train(
        number: "22945",
        name: "Saurashtra Exp",
        departure: "05:30",
        arrival: "06:45",
        duration: "1h 15m",
        stops: ["Mumbai", "Borivali", "Surat"],
      ),
    ];
  }
}
