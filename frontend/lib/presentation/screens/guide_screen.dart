import 'package:flutter/material.dart';
import '../../data/database_helper.dart';
import '../../models/travel_models.dart';
import '../widgets/travel_timeline_item.dart';

class GuideScreen extends StatelessWidget {
  const GuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final source = args?['source'] as String? ?? 'Your Location';
    final destination = args?['destination'] as String? ?? 'Destination';
    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            const Text("Route Guide", style: TextStyle(fontSize: 18)),
            Text(
              "$source to $destination",
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 16),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    "Your Multi-Modal Journey",
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () async {
                    await DatabaseHelper().insertJourney({
                      'source': source,
                      'destination': destination,
                      'date': DateTime.now().toIso8601String(),
                      'notes': 'Saved from search',
                    });
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Journey saved to history!')),
                      );
                    }
                  },
                  icon: const Icon(Icons.save_rounded, size: 18),
                  label: const Text("Save"),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    minimumSize: const Size(0, 36),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          TravelTimelineItem(
            type: SegmentType.taxi,
            title: "Phase 1: To Station",
            subtitle: "Book Ola/Uber/Rapido from $source to Nadiad Railway Station",
            duration: "15 mins",
            fare: "₹80 - ₹120",
          ),
          const TravelTimelineItem(
            type: SegmentType.train,
            title: "Phase 2: Inter-City",
            subtitle: "Take Train 12901 Gujarat Mail to Ahmedabad Junction",
            duration: "1h 15m",
            fare: "₹155 (Sleeper)",
          ),
          TravelTimelineItem(
            type: SegmentType.taxi,
            title: "Phase 3: Final Destination",
            subtitle: "Take Auto/Cab from Ahmedabad Junction to $destination",
            duration: "20 mins",
            fare: "₹100 - ₹150",
            isLast: true,
          ),
        ],
      ),
    );
  }
}
