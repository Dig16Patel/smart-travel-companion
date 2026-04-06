import 'package:flutter/material.dart';
import '../../data/database_helper.dart';

// Transport mode data (mirrored from assistant_screen for icon rendering)
const _kModes = {
  'Cab':  {'icon': Icons.local_taxi,        'color': Color(0xFF1A73E8)},
  'Bike': {'icon': Icons.two_wheeler,        'color': Color(0xFFF9A825)},
  'Auto': {'icon': Icons.electric_rickshaw,  'color': Color(0xFFFF6D00)},
  'Bus':  {'icon': Icons.directions_bus,     'color': Color(0xFF1E88E5)},
  'Walk': {'icon': Icons.directions_walk,    'color': Color(0xFF43A047)},
};

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _allJourneys = [];
  bool _loading = true;
  final Set<int> _expandedIds = {}; // tracks which saved-trip cards are expanded

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final data = await DatabaseHelper().getJourneys();
    if (mounted) setState(() { _allJourneys = data; _loading = false; });
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final int id = item['id'] as int;
    await DatabaseHelper().deleteJourney(id);
    await _load();

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deleted "${item['source']} → ${item['destination']}"'),
          action: SnackBarAction(
            label: 'UNDO',
            onPressed: () async {
              await DatabaseHelper().insertJourney({
                'source': item['source'],
                'destination': item['destination'],
                'date': item['date'],
                'notes': item['notes'],
              });
              await _load();
            },
          ),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _clearAll(List<Map<String, dynamic>> items) async {
    if (items.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All'),
        content: const Text('Delete all entries in this section?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete All', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final deletedItems = List<Map<String, dynamic>>.from(items);
      for (final j in items) {
        await DatabaseHelper().deleteJourney(j['id'] as int);
      }
      await _load();

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cleared ${deletedItems.length} trips.'),
            action: SnackBarAction(
              label: 'UNDO',
              onPressed: () async {
                for (final j in deletedItems) {
                  await DatabaseHelper().insertJourney({
                    'source': j['source'],
                    'destination': j['destination'],
                    'date': j['date'],
                    'notes': j['notes'],
                  });
                }
                await _load();
              },
            ),
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // Saved trips from assistant: notes contain "Pickup:"
  bool _isSavedTrip(Map<String, dynamic> j) =>
      ((j['notes'] as String?) ?? '').contains('Pickup:');

  List<Map<String, dynamic>> get _travelHistory =>
      _allJourneys.where((j) => !_isSavedTrip(j)).toList();

  List<Map<String, dynamic>> get _savedTrips =>
      _allJourneys.where(_isSavedTrip).toList();

  // ── Helpers ────────────────────────────────────────────────────────────────
  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso);
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}  '
             '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) { return iso; }
  }

  Map<String, String> _parseNotes(String? notes) {
    final r = <String, String>{'pickup':'','firstMile':'','dropoff':'','lastMile':''};
    if (notes == null || notes.isEmpty) return r;
    for (final part in notes.split('|')) {
      final kv = part.trim().split(':');
      if (kv.length < 2) continue;
      final key = kv[0].trim().toLowerCase();
      final val = kv.sublist(1).join(':').trim();
      if (key == 'pickup')     r['pickup']    = val;
      if (key == 'first-mile') r['firstMile'] = val;
      if (key == 'dropoff')    r['dropoff']   = val;
      if (key == 'last-mile')  r['lastMile']  = val;
    }
    return r;
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Travel & Saved Trips'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded),
            tooltip: 'Clear current tab',
            onPressed: () {
              final items = _tabController.index == 0 ? _travelHistory : _savedTrips;
              if (items.isNotEmpty) _clearAll(items);
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(
              icon: const Icon(Icons.history_rounded, size: 20),
              text: 'Smart Travel${_travelHistory.isEmpty ? '' : ' (${_travelHistory.length})'}',
            ),
            Tab(
              icon: const Icon(Icons.bookmark_rounded, size: 20),
              text: 'Saved Trips${_savedTrips.isEmpty ? '' : ' (${_savedTrips.length})'}',
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildHistoryTab(theme),
                _buildSavedTripsTab(theme),
              ],
            ),
    );
  }

  // ── Tab 1: Smart Travel (train journeys from smart_plan_screen) ──────────
  Widget _buildHistoryTab(ThemeData theme) {
    final items = _travelHistory;
    if (items.isEmpty) {
      return _emptyState(
        Icons.history_rounded,
        'No smart travel yet',
        'Save a journey from the Smart Planner',
        actionLabel: 'Plan a Journey',
        onAction: () => Navigator.pushNamed(context, '/smart_plan'),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (ctx, i) {
        final item = items[i];
        return _dismissibleCard(
          item: item,
          key: 'hist_${item['id']}',
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.primary.withOpacity(0.12),
              child: Icon(Icons.train_rounded, color: theme.colorScheme.primary),
            ),
            title: Text(
              '${item['source']} → ${item['destination']}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if ((item['notes'] as String?)?.isNotEmpty == true)
                  Text(
                    item['notes'] as String,
                    style: TextStyle(fontSize: 12, color: theme.colorScheme.secondary),
                  ),
                Text(
                  _formatDate(item['date'] as String?),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
            isThreeLine: true,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  color: Colors.red.shade400,
                  tooltip: 'Delete trip',
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete Trip'),
                        content: Text('Delete "${item['source']} → ${item['destination']}"?'),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Delete', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) await _delete(item);
                  },
                ),
                IconButton(
                  icon: Icon(Icons.directions, color: theme.colorScheme.secondary),
                  tooltip: 'View Route',
                  onPressed: () => Navigator.pushNamed(context, '/guide', arguments: {
                    'source': item['source'], 'destination': item['destination'],
                  }),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Tab 2: Saved Trips (assistant multimodal plans) ───────────────────────
  Widget _buildSavedTripsTab(ThemeData theme) {
    final items = _savedTrips;
    if (items.isEmpty) {
      return _emptyState(
        Icons.bookmark_border_rounded,
        'No saved trips yet',
        'Complete all 6 steps in the Rail Assistant\nand tap "Save Trip"',
        actionLabel: 'Go to Assistant',
        onAction: () => Navigator.pushNamed(context, '/assistant'),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (ctx, i) {
        final item    = items[i];
        final tripId  = item['id'] as int;
        final parsed  = _parseNotes(item['notes'] as String?);
        final fm      = parsed['firstMile'];
        final lm      = parsed['lastMile'];
        final fmData  = _kModes[fm];
        final lmData  = _kModes[lm];
        final isOpen  = _expandedIds.contains(tripId);

        return _dismissibleCard(
          item: item,
          key: 'saved_$tripId',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Collapsed header (always visible) ─────────────────────
              ListTile(
                contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                leading: CircleAvatar(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Icon(Icons.bookmark_rounded, size: 18,
                      color: theme.colorScheme.primary),
                ),
                title: Text(
                  '${item['source']} → ${item['destination']}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Transport mode chips
                    if ((fm?.isNotEmpty == true) || (lm?.isNotEmpty == true))
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Wrap(spacing: 6, children: [
                          if (fm?.isNotEmpty == true) _modeChip(fmData, fm!, theme),
                          if (fm?.isNotEmpty == true && lm?.isNotEmpty == true)
                            Text('→ 🚉 →',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                          if (lm?.isNotEmpty == true) _modeChip(lmData, lm!, theme),
                        ]),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(_formatDate(item['date'] as String?),
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                    ),
                  ],
                ),
                isThreeLine: true,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Delete button ────────────────────────────────
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 20),
                      color: Colors.red.shade400,
                      tooltip: 'Delete trip',
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete Trip'),
                            content: Text(
                              'Delete "${item['source']} → ${item['destination']}"?',
                            ),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Delete',
                                    style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) await _delete(item);
                      },
                    ),
                    // ── Expand / collapse ────────────────────────────
                    TextButton.icon(
                      onPressed: () => setState(() {
                        if (isOpen) _expandedIds.remove(tripId);
                        else _expandedIds.add(tripId);
                      }),
                      icon: AnimatedRotation(
                        turns: isOpen ? 0.5 : 0,
                        duration: const Duration(milliseconds: 250),
                        child: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
                      ),
                      label: Text(isOpen ? 'Hide' : 'Details',
                          style: const TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Animated expandable timeline ───────────────────────────
              AnimatedSize(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeInOut,
                child: isOpen
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                        child: Column(children: [
                          Divider(height: 1,
                              color: theme.colorScheme.primary.withOpacity(0.15)),
                          const SizedBox(height: 10),
                          _tripTimeline(
                            pickup:  parsed['pickup']              ?? '',
                            source:  item['source']   as String?  ?? '',
                            dest:    item['destination'] as String? ?? '',
                            dropoff: parsed['dropoff']             ?? '',
                            fmLabel: fm ?? '',
                            lmLabel: lm ?? '',
                            fmIcon:  fmData?['icon']  as IconData? ?? Icons.directions_car,
                            lmIcon:  lmData?['icon']  as IconData? ?? Icons.directions_car,
                            fmColor: fmData?['color'] as Color?    ?? Colors.blue,
                            lmColor: lmData?['color'] as Color?    ?? Colors.blue,
                            theme:   theme,
                          ),
                        ]),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Compact mode chip ──────────────────────────────────────────────────────
  Widget _modeChip(Map<Object, Object>? data, String label, ThemeData theme) {
    final icon  = data?['icon']  as IconData? ?? Icons.directions_car;
    final color = data?['color'] as Color?    ?? theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  // ── Journey timeline widget ───────────────────────────────────────────────
  Widget _tripTimeline({
    required String pickup, required String source,
    required String dest,   required String dropoff,
    required String fmLabel, required String lmLabel,
    required IconData fmIcon, required IconData lmIcon,
    required Color fmColor,   required Color lmColor,
    required ThemeData theme,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.12)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _tlRow(Icons.home_rounded,    Colors.teal,               pickup.isEmpty ? '—' : pickup),
        _tlConnector(fmIcon, fmColor, fmLabel.isEmpty ? 'Transport' : fmLabel),
        _tlRow(Icons.train_rounded,   theme.colorScheme.primary, source, bold: true),
        _tlConnector(Icons.train,     Colors.teal,               'Train'),
        _tlRow(Icons.train_outlined,  theme.colorScheme.primary, dest,   bold: true),
        _tlConnector(lmIcon, lmColor, lmLabel.isEmpty ? 'Transport' : lmLabel),
        _tlRow(Icons.flag_rounded,    Colors.redAccent,          dropoff.isEmpty ? '—' : dropoff),
      ]),
    );
  }

  Widget _tlRow(IconData icon, Color color, String label, {bool bold = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          CircleAvatar(radius: 12, backgroundColor: color.withOpacity(0.15),
              child: Icon(icon, size: 13, color: color)),
          const SizedBox(width: 8),
          Expanded(child: Text(label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, fontWeight: bold ? FontWeight.bold : FontWeight.normal))),
        ]),
      );

  Widget _tlConnector(IconData icon, Color color, String label) =>
      Padding(
        padding: const EdgeInsets.only(left: 11, top: 1, bottom: 1),
        child: Row(children: [
          Container(width: 2, height: 14, color: color.withOpacity(0.35)),
          const SizedBox(width: 14),
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
        ]),
      );

  // ── Swipe-to-delete wrapper ───────────────────────────────────────────────
  Widget _dismissibleCard({
    required Map<String, dynamic> item,
    required String key,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    return Dismissible(
      key: Key(key),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      onDismissed: (_) => _delete(item),
      child: Card(
        color: theme.colorScheme.surface,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
        child: child,
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────
  Widget _emptyState(IconData icon, String title, String subtitle,
      {String? actionLabel, VoidCallback? onAction}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(title, style: TextStyle(fontSize: 16, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(subtitle, textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: Text(actionLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
