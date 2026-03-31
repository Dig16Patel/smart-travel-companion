enum SegmentType { taxi, train, walk, bus, metro }

class Train {
  final String number;
  final String name;
  final String departure;
  final String arrival;
  final String duration;
  final List<String> stops;

  Train({
    required this.number,
    required this.name,
    required this.departure,
    required this.arrival,
    required this.duration,
    required this.stops,
  });
}

class Station {
  final String name;
  final String distance;
  final String location;

  Station({
    required this.name,
    required this.distance,
    required this.location,
  });
}

class TransportOption {
  final String provider;
  final String eta;
  final String duration;
  final String fare;
  final double convenience; // 0.0 to 5.0
  final bool isBest;
  final String vehicleType;
  final String emoji;
  final int rawFare;       // numeric fare for calculations
  final bool isPerPerson;  // true = public (Bus/Train), false = per vehicle

  TransportOption({
    required this.provider,
    required this.eta,
    required this.duration,
    required this.fare,
    required this.convenience,
    this.isBest = false,
    this.vehicleType = '',
    this.emoji = '',
    this.rawFare = 0,
    this.isPerPerson = false,
  });
}



class NavStep {
  final String instruction;
  final String distance;

  NavStep({
    required this.instruction,
    required this.distance,
  });
}
