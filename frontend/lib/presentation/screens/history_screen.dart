import 'package:flutter/material.dart';
import '../../data/database_helper.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<Map<String, dynamic>>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  void _loadHistory() {
    _historyFuture = DatabaseHelper().getJourneys();
  }

  Future<void> _deleteJourney(int id) async {
    await DatabaseHelper().deleteJourney(id);
    setState(() => _loadHistory());
  }

  String _formatDate(String? isoDate) {
    if (isoDate == null) return '';
    try {
      final dt = DateTime.parse(isoDate);
      final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return isoDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Travel History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded),
            tooltip: 'Clear all',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Clear History'),
                  content: const Text('Delete all saved journeys?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                  ],
                ),
              );
              if (confirm == true) {
                final journeys = await DatabaseHelper().getJourneys();
                for (final j in journeys) {
                  await DatabaseHelper().deleteJourney(j['id'] as int);
                }
                setState(() => _loadHistory());
              }
            },
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _historyFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final history = snapshot.data ?? [];

          if (history.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_rounded, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'No journeys saved yet',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Save a journey from the Route Guide screen',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pushNamed(context, '/smart_plan'),
                    icon: const Icon(Icons.search),
                    label: const Text('Plan a Journey'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: history.length,
            itemBuilder: (context, index) {
              final item = history[index];
              return Dismissible(
                key: Key('journey_${item['id']}'),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  decoration: BoxDecoration(
                    color: Colors.red.shade400,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (_) => _deleteJourney(item['id'] as int),
                child: Card(
                  color: theme.colorScheme.surface,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                      child: Icon(Icons.train_rounded, color: theme.colorScheme.primary),
                    ),
                    title: Text(
                      '${item['source']} → ${item['destination']}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      _formatDate(item['date'] as String?),
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.directions, color: theme.colorScheme.secondary),
                      onPressed: () => Navigator.pushNamed(
                        context,
                        '/guide',
                        arguments: {
                          'source': item['source'],
                          'destination': item['destination'],
                        },
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
