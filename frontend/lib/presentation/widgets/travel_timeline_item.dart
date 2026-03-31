import 'package:flutter/material.dart';
import '../../models/travel_models.dart';

class TravelTimelineItem extends StatelessWidget {
  final SegmentType type;
  final String title;
  final String subtitle;
  final String duration;
  final String fare;
  final bool isLast;

  const TravelTimelineItem({
    super.key,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.duration,
    required this.fare,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                    ),
                  ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24.0, right: 16.0),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            duration,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.secondary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Est. Fare: $fare",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.tertiary,
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                              minimumSize: const Size(0, 32),
                            ),
                            child: const Text("View Guide", style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
