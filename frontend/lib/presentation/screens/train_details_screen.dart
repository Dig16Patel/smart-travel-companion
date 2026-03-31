import 'package:flutter/material.dart';

class TrainDetailsScreen extends StatelessWidget {
  const TrainDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Train Details')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Train Number: --', style: theme.textTheme.titleLarge),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInfoColumn('Departure', '--'),
                _buildInfoColumn('Arrival', '--'),
              ],
            ),
            const SizedBox(height: 24),
            Text('Duration: --', style: TextStyle(color: theme.colorScheme.primary)),
            const SizedBox(height: 48),
            Text('Stops', style: theme.textTheme.titleMedium),
            const Expanded(
              child: Center(
                child: Text('No stop data available', style: TextStyle(color: Colors.grey)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ],
    );
  }
}
