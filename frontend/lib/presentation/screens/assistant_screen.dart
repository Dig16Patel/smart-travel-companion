import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../data/station_data.dart';
import '../../data/database_helper.dart';

// ─── Transport Mode Model ─────────────────────────────────────────────────────
class _TransportMode {
  final String id;
  final String label;
  final IconData icon;
  final Color color;
  const _TransportMode({required this.id, required this.label, required this.icon, required this.color});
}

const List<_TransportMode> _kModes = [
  _TransportMode(id: 'Cab',  label: 'Cab\n(Ola/Uber)', icon: Icons.local_taxi,        color: Color(0xFF1A73E8)),
  _TransportMode(id: 'Bike', label: 'Bike\n(Rapido)',  icon: Icons.two_wheeler,        color: Color(0xFFF9A825)),
  _TransportMode(id: 'Auto', label: 'Auto',            icon: Icons.electric_rickshaw,  color: Color(0xFFFF6D00)),
  _TransportMode(id: 'Bus',  label: 'Bus',             icon: Icons.directions_bus,     color: Color(0xFF1E88E5)),
  _TransportMode(id: 'Walk', label: 'Walk',            icon: Icons.directions_walk,    color: Color(0xFF43A047)),
];

_TransportMode? _modeFor(String? id) =>
    id == null ? null : _kModes.firstWhere((m) => m.id == id, orElse: () => _kModes.first);

// ─── Station Search Field ─────────────────────────────────────────────────────
class _StationSearchField extends StatefulWidget {
  final String label;
  final IconData icon;
  final String? initialCode;
  final ValueChanged<String?> onSelected;
  const _StationSearchField({required this.label, required this.icon, required this.onSelected, this.initialCode});

  @override
  State<_StationSearchField> createState() => _StationSearchFieldState();
}

class _StationSearchFieldState extends State<_StationSearchField> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  List<Map<String, dynamic>> _suggestions = [];
  bool _show = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialCode != null) {
      final m = StationData.stations.firstWhere(
          (s) => s['code'] == widget.initialCode, orElse: () => {});
      if (m.isNotEmpty) _ctrl.text = '${m['name']} (${m['code']})';
    }
    _focus.addListener(() {
      if (!_focus.hasFocus) {
        Future.delayed(const Duration(milliseconds: 150), () {
          if (mounted) setState(() => _show = false);
        });
      }
    });
  }

  @override
  void dispose() { _ctrl.dispose(); _focus.dispose(); super.dispose(); }

  void _changed(String v) {
    final q = v.toLowerCase().trim();
    if (q.isEmpty) { setState(() { _suggestions = []; _show = false; }); widget.onSelected(null); return; }
    final f = StationData.stations.where((s) {
      final n = (s['name'] as String).toLowerCase();
      final c = (s['code'] as String).toLowerCase();
      return n.contains(q) || c.contains(q);
    }).toList();
    setState(() { _suggestions = f; _show = f.isNotEmpty; });
  }

  void _select(Map<String, dynamic> s) {
    _ctrl.text = '${s['name']} (${s['code']})';
    _focus.unfocus();
    setState(() => _show = false);
    widget.onSelected(s['code'] as String);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextField(
        controller: _ctrl, focusNode: _focus, onChanged: _changed,
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: 'Type station name or code...',
          prefixIcon: Icon(widget.icon, color: theme.colorScheme.primary),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          suffixIcon: _ctrl.text.isNotEmpty
              ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () {
                  _ctrl.clear(); widget.onSelected(null); setState(() => _show = false);
                })
              : null,
        ),
      ),
      if (_show)
        Container(
          margin: const EdgeInsets.only(top: 2),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.10), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          constraints: const BoxConstraints(maxHeight: 200),
          child: ListView.separated(
            padding: EdgeInsets.zero, shrinkWrap: true,
            itemCount: _suggestions.length,
            separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
            itemBuilder: (ctx, i) {
              final s = _suggestions[i];
              return ListTile(
                dense: true,
                leading: const Icon(Icons.train, size: 18, color: Colors.teal),
                title: Text(s['name'] as String, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: theme.colorScheme.primaryContainer, borderRadius: BorderRadius.circular(4)),
                  child: Text(s['code'] as String,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                ),
                onTap: () => _select(s),
              );
            },
          ),
        ),
    ]);
  }
}

// ─── Transport Picker ─────────────────────────────────────────────────────────
class _TransportPicker extends StatelessWidget {
  final String? selected;
  final ValueChanged<String> onSelected;
  const _TransportPicker({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _kModes.map((mode) {
        final isSelected = selected == mode.id;
        return GestureDetector(
          onTap: () => onSelected(mode.id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 80,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: isSelected ? mode.color : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isSelected ? mode.color : Colors.grey.shade300, width: isSelected ? 2 : 1.5),
              boxShadow: isSelected
                  ? [BoxShadow(color: mode.color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))]
                  : [],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(mode.icon, size: 26, color: isSelected ? Colors.white : mode.color),
              const SizedBox(height: 6),
              Text(
                mode.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w600, height: 1.2,
                  color: isSelected ? Colors.white : Colors.grey.shade700,
                ),
              ),
            ]),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Main Screen ──────────────────────────────────────────────────────────────
class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final _pickupCtrl  = TextEditingController();
  final _dropoffCtrl = TextEditingController();

  String? _selectedSource;
  String? _selectedDest;
  String? _firstMileMode;
  String? _lastMileMode;

  int _currentStep = 0;

  // ── Saved trips from SQLite DB ────────────────────────────────────────────
  List<Map<String, dynamic>> _savedTrips = [];
  List<Map<String, dynamic>> _recentSearches = [];

  @override
  void initState() { super.initState(); _loadSavedTrips(); _loadRecentSearches(); }

  @override
  void dispose() { _pickupCtrl.dispose(); _dropoffCtrl.dispose(); super.dispose(); }

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('recent_searches_v2');
    if (data != null && mounted) {
      final List<dynamic> decoded = jsonDecode(data);
      setState(() => _recentSearches = decoded.cast<Map<String, dynamic>>());
    }
  }

  // ── Load saved trips from SQLite ──────────────────────────────────────────
  Future<void> _loadSavedTrips() async {
    final trips = await DatabaseHelper().getJourneys();
    if (mounted) setState(() => _savedTrips = trips);
  }

  /// Parse the structured notes field back into a map.
  /// Format: "Pickup: X | First-mile: Y | Dropoff: Z | Last-mile: W"
  Map<String, String> _parsedTrip(String? notes) {
    final result = <String, String>{'pickup': '', 'firstMile': '', 'dropoff': '', 'lastMile': ''};
    if (notes == null || notes.isEmpty) return result;
    for (final part in notes.split('|')) {
      final kv = part.trim().split(':');
      if (kv.length < 2) continue;
      final key   = kv[0].trim().toLowerCase();
      final value = kv.sublist(1).join(':').trim();
      if (key == 'pickup')      result['pickup']    = value;
      if (key == 'first-mile')  result['firstMile'] = value;
      if (key == 'dropoff')     result['dropoff']   = value;
      if (key == 'last-mile')   result['lastMile']  = value;
    }
    return result;
  }

  Future<void> _saveRecent() async {
    final prefs = await SharedPreferences.getInstance();
    final newSearch = {
      'source': _selectedSource ?? '', 'destination': _selectedDest ?? '',
      'pickup': _pickupCtrl.text.trim(), 'dropoff': _dropoffCtrl.text.trim(),
      'firstMile': _firstMileMode ?? '', 'lastMile': _lastMileMode ?? '',
      'date': DateTime.now().toIso8601String(),
    };
    
    // Maintain a history of 5 recent searches
    final updatedList = [newSearch, ..._recentSearches].take(5).toList();
    await prefs.setString('recent_searches_v2', jsonEncode(updatedList));
    if (mounted) setState(() => _recentSearches = updatedList);
  }

  // ── Validation ───────────────────────────────────────────────────────────
  bool get _s1ok => _pickupCtrl.text.trim().isNotEmpty;
  bool get _s2ok => _selectedSource != null;
  bool get _s3ok => _firstMileMode != null;
  bool get _s4ok => _selectedDest != null;
  bool get _s5ok => _dropoffCtrl.text.trim().isNotEmpty;
  bool get _s6ok => _lastMileMode != null;
  bool get _allOk => _s1ok && _s2ok && _s3ok && _s4ok && _s5ok && _s6ok;

  bool _stepDone(int i) {
    switch (i) {
      case 0: return _s1ok;
      case 1: return _s2ok;
      case 2: return _s3ok;
      case 3: return _s4ok;
      case 4: return _s5ok;
      case 5: return _s6ok;
      default: return false;
    }
  }

  bool _canAdvance() => _stepDone(_currentStep);

  // ── Helpers ──────────────────────────────────────────────────────────────
  String _stationLabel(String? code) {
    if (code == null) return '—';
    final m = StationData.stations.firstWhere((s) => s['code'] == code, orElse: () => {});
    return m.isNotEmpty ? '${m['name']} ($code)' : code;
  }

  Future<void> _planJourney() async {
    if (!_allOk) return;
    await _saveRecent();
    setState(() {});
    if (!mounted) return;
    Navigator.pushNamed(context, '/smart_plan', arguments: {
      'source': _selectedSource, 'destination': _selectedDest,
      'pickup': _pickupCtrl.text.trim(), 'dropoff': _dropoffCtrl.text.trim(),
      'firstMileMode': _firstMileMode, 'lastMileMode': _lastMileMode,
    });
  }

  Future<void> _saveTrip() async {
    if (!_allOk) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all steps before saving.')),
      );
      return;
    }
    final notes =
        'Pickup: ${_pickupCtrl.text.trim()} | '
        'First-mile: $_firstMileMode | '
        'Dropoff: ${_dropoffCtrl.text.trim()} | '
        'Last-mile: $_lastMileMode';
    await DatabaseHelper().insertJourney({
      'source':      _selectedSource,
      'destination': _selectedDest,
      'date':        DateTime.now().toIso8601String(),
      'notes':       notes,
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(children: [
            Icon(Icons.check_circle, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Trip saved to history!'),
          ]),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ),
      );
      // Refresh saved trips list immediately
      await _loadSavedTrips();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        title: const Text('Smart Rail Assistant'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_currentStep + 1) / 6,
            backgroundColor: Colors.white24,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      ),
      // ── Using ListView instead of SingleChildScrollView + Stepper ────────
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // ── Progress chip ─────────────────────────────────────────────
          _ProgressChip(current: _currentStep, theme: theme),
          const SizedBox(height: 16),

          // ── Step cards ────────────────────────────────────────────────
          _stepCard(0, Icons.home_rounded,   'Pick-up Location',
              _s1ok ? _pickupCtrl.text.trim() : 'Where does your journey start?', _buildS1()),
          _stepCard(1, Icons.train_rounded,  'Boarding Station',
              _s2ok ? _stationLabel(_selectedSource) : 'Select departure station', _buildS2()),
          _stepCard(2, Icons.swap_horiz,     'First-Mile Transport',
              _s3ok ? 'By $_firstMileMode' : 'Pickup → Station transport', _buildS3(theme)),
          _stepCard(3, Icons.train_outlined, 'Destination Station',
              _s4ok ? _stationLabel(_selectedDest) : 'Select destination station', _buildS4()),
          _stepCard(4, Icons.flag_rounded,   'Drop-off Location',
              _s5ok ? _dropoffCtrl.text.trim() : 'Where is your final stop?', _buildS5()),
          _stepCard(5, Icons.hail_rounded,   'Last-Mile Transport',
              _s6ok ? 'By $_lastMileMode' : 'Station → Drop-off transport', _buildS6(theme)),

          const SizedBox(height: 8),

          // ── Explore Features ─────────────────────────────────────────
          _sectionTitle('Explore Features', theme),
          const SizedBox(height: 10),
          _featureTile(context, Icons.train,          'Nearby Railway Station', 'Find nearest stations on map',  '/nearby',  theme.colorScheme.secondary),
          _featureTile(context, Icons.directions_bus, 'Local Transport',        'Ola, Uber, Rapido & Auto fares','/local',   theme.colorScheme.tertiary),
          _featureTile(context, Icons.map_rounded,    'Map View',               'Explore your area on map',      '/map',     Colors.green),
          _featureTile(context, Icons.compare_arrows, 'Compare Transport',      'Compare all transport modes',   '/compare', Colors.purple),

          const SizedBox(height: 24),

          // ── Recent Searches ──────────────────────────────────────────
          if (_recentSearches.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _sectionTitle('Recent Searches', theme),
                TextButton(
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.remove('recent_searches_v2');
                    setState(() => _recentSearches.clear());
                  },
                  child: const Text('Clear', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._recentSearches.map((s) => _recentCard(s, theme)),
            const SizedBox(height: 24),
          ],

          // ── Saved Trips (Recent) ─────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sectionTitle('Saved Trips', theme),
              if (_savedTrips.isNotEmpty)
                TextButton.icon(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Clear All Saved Trips'),
                        content: const Text('This will delete all saved trips from history.'),
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
                      for (final t in _savedTrips) {
                        await DatabaseHelper().deleteJourney(t['id'] as int);
                      }
                      await _loadSavedTrips();
                    }
                  },
                  icon: const Icon(Icons.delete_sweep_rounded, size: 16, color: Colors.red),
                  label: const Text('Clear All', style: TextStyle(color: Colors.red)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (_savedTrips.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(children: [
                  Icon(Icons.bookmark_border_rounded, size: 40, color: Colors.grey.shade400),
                  const SizedBox(height: 6),
                  Text('No saved trips yet', style: TextStyle(color: Colors.grey.shade400)),
                  const SizedBox(height: 4),
                  Text('Complete all steps and tap Save Trip',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                ]),
              ),
            )
          else
            ..._savedTrips.map((trip) => _savedTripCard(trip, theme)),
        ],
      ),
    );
  }

  // ─── Custom step card ─────────────────────────────────────────────────────
  Widget _stepCard(int index, IconData icon, String title, String subtitle, Widget content) {
    final theme = Theme.of(context);
    final isActive   = _currentStep == index;
    final isComplete = _stepDone(index) && !isActive;
    final isLocked   = index > _currentStep;

    return GestureDetector(
      onTap: isLocked ? null : () => setState(() => _currentStep = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive
                ? theme.colorScheme.primary
                : isComplete
                    ? Colors.green.shade300
                    : Colors.grey.shade200,
            width: isActive ? 2 : 1,
          ),
          boxShadow: isActive
              ? [BoxShadow(color: theme.colorScheme.primary.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 4))]
              : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header row
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              // Step number / check indicator
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive
                      ? theme.colorScheme.primary
                      : isComplete
                          ? Colors.green
                          : Colors.grey.shade200,
                ),
                child: Center(
                  child: isComplete
                      ? const Icon(Icons.check, color: Colors.white, size: 17)
                      : Icon(icon,
                            color: isActive ? Colors.white : Colors.grey.shade500,
                            size: 17),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isLocked ? Colors.grey : null)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                ]),
              ),
              if (isLocked)
                const Icon(Icons.lock_outline, size: 16, color: Colors.grey)
              else if (isActive)
                Icon(Icons.expand_less, color: theme.colorScheme.primary)
              else
                Icon(Icons.expand_more, color: Colors.grey.shade400),
            ]),
          ),

          // Expanded content
          if (isActive) ...[
            Divider(height: 1, color: theme.colorScheme.primary.withOpacity(0.2)),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: content,
            ),
            // Continue / Back / Save buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                // ── Save Trip button (step 6 only) ──────────────────────
                if (index == 5) ...[
                  OutlinedButton.icon(
                    onPressed: _allOk ? _saveTrip : null,
                    icon: const Icon(Icons.bookmark_add_rounded, size: 18),
                    label: const Text('Save Trip', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: _allOk ? Colors.green.shade600 : Colors.grey.shade300, width: 1.5),
                      foregroundColor: _allOk ? Colors.green.shade700 : Colors.grey,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                // ── Continue / Find Smart Plans + Back ───────────────────
                Row(children: [
                  if (index < 5)
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _canAdvance() ? () => setState(() => _currentStep++) : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Continue →', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  if (index == 5)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _allOk ? _planJourney : null,
                        icon: const Icon(Icons.search),
                        label: const Text('Find Smart Plans', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  if (index > 0) ...[
                    const SizedBox(width: 10),
                    OutlinedButton(
                      onPressed: () => setState(() => _currentStep--),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Back'),
                    ),
                  ],
                ]),
              ]),
            ),
          ],
        ]),
      ),
    );
  }

  // ─── Step content ─────────────────────────────────────────────────────────
  Widget _buildS1() => TextField(
    controller: _pickupCtrl,
    onChanged: (_) => setState(() {}),
    decoration: InputDecoration(
      labelText: 'Pick-up Location',
      hintText: 'e.g., Home, Hotel, Gateway of India',
      prefixIcon: const Icon(Icons.home, color: Colors.teal),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
    ),
  );

  Widget _buildS2() => _StationSearchField(
    label: 'Boarding Station', icon: Icons.train,
    initialCode: _selectedSource,
    onSelected: (c) => setState(() => _selectedSource = c),
  );

  Widget _buildS3(ThemeData theme) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(
        'How will you travel from "${_pickupCtrl.text.trim().isEmpty ? "pickup" : _pickupCtrl.text.trim()}" '
        'to ${_stationLabel(_selectedSource)}?',
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      ),
      const SizedBox(height: 12),
      _TransportPicker(selected: _firstMileMode, onSelected: (m) => setState(() => _firstMileMode = m)),
      if (_firstMileMode != null) ...[
        const SizedBox(height: 10),
        _badge(_firstMileMode!),
      ],
    ]);
  }

  Widget _buildS4() => _StationSearchField(
    label: 'Destination Station', icon: Icons.train,
    initialCode: _selectedDest,
    onSelected: (c) => setState(() => _selectedDest = c),
  );

  Widget _buildS5() => TextField(
    controller: _dropoffCtrl,
    onChanged: (_) => setState(() {}),
    decoration: InputDecoration(
      labelText: 'Drop-off Location',
      hintText: 'e.g., Office, Airport, Hotel',
      prefixIcon: const Icon(Icons.flag, color: Colors.redAccent),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
    ),
  );

  Widget _buildS6(ThemeData theme) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(
        'How will you travel from ${_stationLabel(_selectedDest)} '
        'to "${_dropoffCtrl.text.trim().isEmpty ? "drop-off" : _dropoffCtrl.text.trim()}"?',
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      ),
      const SizedBox(height: 12),
      _TransportPicker(selected: _lastMileMode, onSelected: (m) => setState(() => _lastMileMode = m)),
      if (_lastMileMode != null) ...[
        const SizedBox(height: 10),
        _badge(_lastMileMode!),
      ],
      if (_allOk) ...[
        const SizedBox(height: 20),
        _journeySummary(theme),
      ],
    ]);
  }

  // ─── Selection badge ──────────────────────────────────────────────────────
  Widget _badge(String modeId) {
    final m = _modeFor(modeId)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: m.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: m.color.withOpacity(0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(m.icon, size: 16, color: m.color),
        const SizedBox(width: 6),
        Text('$modeId selected ✓', style: TextStyle(color: m.color, fontWeight: FontWeight.bold, fontSize: 12)),
      ]),
    );
  }

  // ─── Journey summary ──────────────────────────────────────────────────────
  Widget _journeySummary(ThemeData theme) {
    final fm = _modeFor(_firstMileMode)!;
    final lm = _modeFor(_lastMileMode)!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.colorScheme.primary.withOpacity(0.07), theme.colorScheme.secondary.withOpacity(0.05)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.summarize_rounded, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text('Journey Summary', style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary, fontSize: 13)),
        ]),
        const SizedBox(height: 12),
        _sRow(Icons.home_rounded,    Colors.teal,                     _pickupCtrl.text.trim()),
        _connector(fm.icon, fm.color, fm.id),
        _sRow(Icons.train_rounded,   theme.colorScheme.primary,       _stationLabel(_selectedSource), bold: true),
        _connector(Icons.train,      Colors.teal,                     'Train'),
        _sRow(Icons.train_outlined,  theme.colorScheme.primary,       _stationLabel(_selectedDest),  bold: true),
        _connector(lm.icon, lm.color, lm.id),
        _sRow(Icons.flag_rounded,    Colors.redAccent,                _dropoffCtrl.text.trim()),
      ]),
    );
  }

  Widget _sRow(IconData icon, Color color, String label, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      CircleAvatar(radius: 13, backgroundColor: color.withOpacity(0.15),
          child: Icon(icon, size: 14, color: color)),
      const SizedBox(width: 10),
      Expanded(child: Text(label, overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, fontWeight: bold ? FontWeight.bold : FontWeight.normal))),
    ]),
  );

  Widget _connector(IconData icon, Color color, String label) => Padding(
    padding: const EdgeInsets.only(left: 12, top: 2, bottom: 2),
    child: Row(children: [
      Container(width: 2, height: 16, color: color.withOpacity(0.35)),
      const SizedBox(width: 16),
      Icon(icon, size: 13, color: color),
      const SizedBox(width: 5),
      Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
    ]),
  );

  // ─── Shared helpers ───────────────────────────────────────────────────────
  Widget _sectionTitle(String text, ThemeData theme) =>
      Text(text, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold));

  Widget _featureTile(BuildContext ctx, IconData icon, String title, String sub, String route, Color color) =>
      Card(
        margin: const EdgeInsets.only(bottom: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          leading: CircleAvatar(backgroundColor: color.withOpacity(0.15), child: Icon(icon, color: color)),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(sub, style: const TextStyle(fontSize: 12)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.pushNamed(ctx, route),
        ),
      );

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso);
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}  ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
    } catch (_) { return iso; }
  }

  Widget _savedTripCard(Map<String, dynamic> trip, ThemeData theme) {
    final parsed  = _parsedTrip(trip['notes'] as String?);
    final fm      = _modeFor(parsed['firstMile']?.isEmpty == true ? null : parsed['firstMile']);
    final lm      = _modeFor(parsed['lastMile']?.isEmpty  == true ? null : parsed['lastMile']);
    final tripId  = trip['id'] as int;

    return Dismissible(
      key: Key('saved_trip_$tripId'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 8),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      onDismissed: (_) async {
        await DatabaseHelper().deleteJourney(tripId);
        await _loadSavedTrips();
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: CircleAvatar(
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Icon(Icons.bookmark_rounded, color: theme.colorScheme.primary, size: 20),
          ),
          title: Text(
            '${trip['source']} → ${trip['destination']}',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Transport modes row
              if (fm != null || lm != null)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Wrap(spacing: 4, children: [
                    if (fm != null) Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(fm.icon, size: 12, color: fm.color),
                      Text(' ${parsed['firstMile']}', style: const TextStyle(fontSize: 11)),
                    ]),
                    if (fm != null && lm != null)
                      const Text(' → 🚉 → ', style: TextStyle(fontSize: 11)),
                    if (lm != null) Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(lm.icon, size: 12, color: lm.color),
                      Text(' ${parsed['lastMile']}', style: const TextStyle(fontSize: 11)),
                    ]),
                  ]),
                ),
              // Date
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  _formatDate(trip['date'] as String?),
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                ),
              ),
            ],
          ),
          trailing: const Icon(Icons.arrow_forward_ios, size: 14),
          onTap: () => setState(() {
            _selectedSource   = trip['source'] as String?;
            _selectedDest     = trip['destination'] as String?;
            _pickupCtrl.text  = parsed['pickup']    ?? '';
            _dropoffCtrl.text = parsed['dropoff']   ?? '';
            _firstMileMode    = parsed['firstMile']?.isEmpty == true ? null : parsed['firstMile'];
            _lastMileMode     = parsed['lastMile']?.isEmpty  == true ? null : parsed['lastMile'];
            _currentStep      = 5;
          }),
        ),
      ),
    );
  }

  // ─── Recent Search card ───────────────────────────────────────────────────
  Widget _recentCard(Map<String, dynamic> search, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(Icons.history_rounded, color: theme.colorScheme.primary, size: 20),
        ),
        title: Text(
          '${search['source']} → ${search['destination']}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        subtitle: Text(
          'Pickup: ${search['pickup']}\nDrop-off: ${search['dropoff']}',
          style: const TextStyle(fontSize: 11),
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.restore, size: 16),
        onTap: () {
          setState(() {
            _selectedSource   = search['source'];
            _selectedDest     = search['destination'];
            _pickupCtrl.text  = search['pickup'] ?? '';
            _dropoffCtrl.text = search['dropoff'] ?? '';
            _firstMileMode    = search['firstMile']?.isEmpty == true ? null : search['firstMile'];
            _lastMileMode     = search['lastMile']?.isEmpty == true ? null : search['lastMile'];
            _currentStep      = 5;
          });
        },
      ),
    );
  }
}

// ─── Progress chip widget ─────────────────────────────────────────────────────
class _ProgressChip extends StatelessWidget {
  final int current;
  final ThemeData theme;
  const _ProgressChip({required this.current, required this.theme});

  static const _titles = [
    'Pick-up Location', 'Boarding Station', 'First-Mile Transport',
    'Destination Station', 'Drop-off Location', 'Last-Mile Transport',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withOpacity(0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: [
        Icon(Icons.route, size: 16, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text('Step ${current + 1} of 6 — ${_titles[current]}',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: theme.colorScheme.primary)),
      ]),
    );
  }
}
