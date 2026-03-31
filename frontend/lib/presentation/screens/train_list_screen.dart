import 'package:flutter/material.dart';

class TrainListScreen extends StatelessWidget {
  const TrainListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Train List')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.train_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No data available', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
