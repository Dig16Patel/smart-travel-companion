import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../data/station_data.dart';

// ─── Reusable station-search field ──────────────────────────────────────────
class _StationSearchField extends StatefulWidget {
  final String label;
  final IconData icon;
  final String? initialCode;
  final ValueChanged<String?> onSelected; // returns station code

  const _StationSearchField({
    required this.label,
    required this.icon,
    required this.onSelected,
    this.initialCode,
  });

  @override
  State<_StationSearchField> createState() => _StationSearchFieldState();
}

class _StationSearchFieldState extends State<_StationSearchField> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  List<Map<String, dynamic>> _suggestions = [];
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill with station name if initial code was provided
    if (widget.initialCode != null) {
      final match = StationData.stations
          .firstWhere((s) => s['code'] == widget.initialCode,
              orElse: () => {});
      if (match.isNotEmpty) {
        _controller.text = '${match['name']} (${match['code']})';
      }
    }
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 150), () {
          if (mounted) setState(() => _showSuggestions = false);
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    final query = value.toLowerCase().trim();
    if (query.isEmpty) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
      widget.onSelected(null);
      return;
    }
    final filtered = StationData.stations.where((s) {
      final name = (s['name'] as String).toLowerCase();
      final code = (s['code'] as String).toLowerCase();
      return name.contains(query) || code.contains(query);
    }).toList();

    setState(() {
      _suggestions = filtered;
      _showSuggestions = filtered.isNotEmpty;
    });
  }

  void _select(Map<String, dynamic> station) {
    _controller.text = '${station['name']} (${station['code']})';
    _focusNode.unfocus();
    setState(() => _showSuggestions = false);
    widget.onSelected(station['code'] as String);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          onChanged: _onChanged,
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: 'Type station name...',
            prefixIcon: Icon(widget.icon),
            border: const OutlineInputBorder(),
            suffixIcon: _controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _controller.clear();
                      widget.onSelected(null);
                      setState(() => _showSuggestions = false);
                    },
                  )
                : null,
          ),
        ),
        if (_showSuggestions)
          Container(
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.separated(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: _suggestions.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: Colors.grey.shade200),
              itemBuilder: (context, index) {
                final s = _suggestions[index];
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.train, size: 18),
                  title: Text(s['name'] as String,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      s['code'] as String,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  onTap: () => _select(s),
                );
              },
            ),
          ),
      ],
    );
  }
}

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final _pickupController = TextEditingController();
  final _dropoffController = TextEditingController();
  
  String? _selectedSource;
  String? _selectedDest;
  List<Map<String, String>> _recentSearches = [];

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
  }

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('recent_searches');
    if (raw != null) {
      final list = (jsonDecode(raw) as List)
          .map((e) => Map<String, String>.from(e as Map))
          .toList();
      setState(() => _recentSearches = list);
    }
  }

  Future<void> _saveSearch(String source, String dest) async {
    final prefs = await SharedPreferences.getInstance();
    final search = {'source': source, 'destination': dest};
    _recentSearches.removeWhere((s) => s['source'] == source && s['destination'] == dest);
    _recentSearches.insert(0, search);
    if (_recentSearches.length > 5) _recentSearches = _recentSearches.sublist(0, 5);
    await prefs.setString('recent_searches', jsonEncode(_recentSearches));
  }

  void _planJourney() async {
    final source = _selectedSource;
    final dest = _selectedDest;

    if (source == null || dest == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both a boarding and destination station')),
      );
      return;
    }

    await _saveSearch(source, dest);
    setState(() {}); // refresh recent searches display

    final pickup = _pickupController.text.trim();
    final dropoff = _dropoffController.text.trim();

    if (!mounted) return;
    Navigator.pushNamed(
      context,
      '/smart_plan',
      arguments: {
        'source': source, 
        'destination': dest,
        'pickup': pickup,
        'dropoff': dropoff,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Smart Rail Assistant')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Input Section
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Plan your journey', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Select starting and ending locations', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _pickupController,
                      decoration: const InputDecoration(
                        labelText: 'Pick-up Location',
                        hintText: 'e.g., Home, Hotel, Gateway of India',
                        prefixIcon: Icon(Icons.home),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _StationSearchField(
                      label: 'Boarding Station',
                      icon: Icons.train,
                      initialCode: _selectedSource,
                      onSelected: (code) => setState(() => _selectedSource = code),
                    ),
                    const SizedBox(height: 12),
                    _StationSearchField(
                      label: 'Destination Station',
                      icon: Icons.train,
                      initialCode: _selectedDest,
                      onSelected: (code) => setState(() => _selectedDest = code),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _dropoffController,
                      decoration: const InputDecoration(
                        labelText: 'Drop-off Location',
                        hintText: 'e.g., Office, Airport, Taj Mahal',
                        prefixIcon: Icon(Icons.flag),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _planJourney,
                      icon: const Icon(Icons.search),
                      label: const Text('Find Smart Plans'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 52),
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.pushNamed(context, '/compare'),
                      icon: const Icon(Icons.compare_arrows),
                      label: const Text('Compare Transport Modes'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
            Text('Explore Features', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildFeatureTile(context, Icons.train, 'Nearby Railway Station', 'Find nearest stations on map', '/nearby', theme.colorScheme.secondary),
            _buildFeatureTile(context, Icons.directions_bus, 'Local Transport', 'Ola, Uber, Rapido & Auto fares', '/local', theme.colorScheme.tertiary),
            _buildFeatureTile(context, Icons.map_rounded, 'Map View', 'Explore your area on map', '/map', Colors.green),

            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Recent Searches', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                if (_recentSearches.isNotEmpty)
                  TextButton(
                    onPressed: () async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.remove('recent_searches');
                      setState(() => _recentSearches = []);
                    },
                    child: const Text('Clear', style: TextStyle(color: Colors.red)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (_recentSearches.isEmpty)
              Center(
                child: Column(
                  children: [
                    Icon(Icons.history, size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 8),
                    Text('No recent searches', style: TextStyle(color: Colors.grey.shade400)),
                  ],
                ),
              )
            else
              ..._recentSearches.map((search) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.history),
                  title: Text('${search['source']} → ${search['destination']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () {
                    setState(() {
                      _selectedSource = search['source'];
                      _selectedDest = search['destination'];
                    });
                    _planJourney();
                  },
                ),
              )),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureTile(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    String route,
    Color color,
  ) {
    return Card(
      color: Theme.of(context).colorScheme.surface,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.15),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.pushNamed(context, route),
      ),
    );
  }
}
