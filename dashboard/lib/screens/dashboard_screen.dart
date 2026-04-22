import 'package:flutter/material.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;
import 'package:firebase_database/firebase_database.dart';
import 'package:shared/models/alert.dart';
import 'package:shared/models/incident.dart';
import '../services/triage_service.dart';
import '../widgets/incident_card.dart';
import '../widgets/venue_map.dart';
import 'analytics_screen.dart';

// -----------------------------------------------------------------------------
// DashboardScreen — CrisisNet Staff Command View
// Listens to BOTH /alerts/ (raw SOS from guest app) and /incidents/ (triaged by AI)
// so staff see every emergency the instant it is submitted.
// -----------------------------------------------------------------------------
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const String _venueId = 'mockVenue123';

  String _searchQuery = '';
  String _sortBy = 'severity';
  EmergencyType? _filterType;
  List<Incident> _incidents = [];
  List<Alert> _rawAlerts = [];

  // ── Alert / tab-badge state ─────────────────────────────────────
  int _unreadCritical = 0;
  bool _initialized = false; // suppress alerts on first load
  final Set<String> _seenIncidentIds = {};

  @override
  void initState() {
    super.initState();
    _requestNotificationPermission();
    _subscribeToIncidents();
    _subscribeToAlerts();
    // Reset tab badge when window regains focus
    html.window.onFocus.listen((_) {
      if (!mounted) return;
      setState(() => _unreadCritical = 0);
      html.document.title = 'CrisisNet';
    });
  }

  void _requestNotificationPermission() {
    try {
      if (html.Notification.permission != 'granted') {
        html.Notification.requestPermission();
      }
    } catch (_) {}
  }

  // ─── Firebase Listeners ────────────────────────────────────────────────────

  /// Listens to classified Incident documents (Module 3 output).
  void _subscribeToIncidents() {
    FirebaseDatabase.instance
        .ref('venues/$_venueId/incidents')
        .onValue
        .listen((event) {
      if (!mounted) return;
      if (event.snapshot.value == null) {
        setState(() => _incidents = []);
        _initialized = true;
        return;
      }
      final data = event.snapshot.value;
      if (data is! Map) return;

      final List<Incident> updated = [];
      data.forEach((key, value) {
        if (value is Map) {
          try {
            final incident = Incident.fromMap(Map<dynamic, dynamic>.from(value));
            updated.add(incident);

            // Alert staff to genuinely NEW critical incidents
            if (_initialized &&
                !_seenIncidentIds.contains(incident.id) &&
                incident.severity >= 4) {
              _playAlertTone();
              setState(() => _unreadCritical++);
              html.document.title = '($_unreadCritical NEW) CrisisNet';
            }
            _seenIncidentIds.add(incident.id);
          } catch (_) {}
        }
      });
      updated.sort((a, b) => b.severity.compareTo(a.severity));
      setState(() => _incidents = updated);
      _initialized = true;
    });
  }

  /// Plays a short 880 Hz sine-wave ping via the Web Audio API (dart:js interop).
  void _playAlertTone() {
    try {
      final ctx = js.JsObject(js.context['AudioContext'] as js.JsFunction);
      final osc = ctx.callMethod('createOscillator') as js.JsObject;
      final gain = ctx.callMethod('createGain') as js.JsObject;
      osc.callMethod('connect', [gain]);
      gain.callMethod('connect', [ctx['destination']]);
      osc['type'] = 'sine';
      final now = ctx['currentTime'] as num;
      (osc['frequency'] as js.JsObject).callMethod('setValueAtTime', [880, now]);
      final gainParam = gain['gain'] as js.JsObject;
      gainParam.callMethod('setValueAtTime', [0.3, now]);
      gainParam.callMethod('exponentialRampToValueAtTime', [0.001, now + 0.45]);
      osc.callMethod('start', []);
      osc.callMethod('stop', [now + 0.45]);
    } catch (_) {}
  }

  /// Listens to raw Alert objects written by the Guest App on SOS.
  /// Only shows alerts NOT already promoted to an incident.
  void _subscribeToAlerts() {
    FirebaseDatabase.instance
        .ref('venues/$_venueId/alerts')
        .onValue
        .listen((event) {
      if (!mounted) return;
      if (event.snapshot.value == null) {
        setState(() => _rawAlerts = []);
        return;
      }
      final data = event.snapshot.value;
      if (data is! Map) return;

      final List<Alert> updated = [];
      data.forEach((key, value) {
        if (value is Map) {
          try {
            final alert = Alert.fromMap(Map<dynamic, dynamic>.from(value));
            
            // Serverless workaround: Dashboard acts as the triage backend
            if (alert.status == AlertStatus.pending) {
              TriageService.processAlert(alert);
            }

            // Only surface pending alerts — triaged ones appear as Incidents.
            if (alert.status == AlertStatus.pending) {
              updated.add(alert);
            }
          } catch (_) {}
        }
      });
      // Newest first
      updated.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      setState(() => _rawAlerts = updated);
    });
  }

  // ─── Actions ───────────────────────────────────────────────────────────────

  void _clearDatabase() async {
    await FirebaseDatabase.instance.ref('venues/$_venueId/alerts').remove();
    await FirebaseDatabase.instance.ref('venues/$_venueId/incidents').remove();
    if (mounted) setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Firebase Database Cleared!'), backgroundColor: Colors.green));
  }

  void _assignStaff(String incidentId, String staffName) async {
    final int index = _incidents.indexWhere((i) => i.id == incidentId);
    if (index == -1) return;
    final incident = _incidents[index];
    incident.timeline.add(IncidentUpdate(
      timestamp: DateTime.now().millisecondsSinceEpoch,
      updateText: 'Assigned to $staffName',
    ));
    await FirebaseDatabase.instance
        .ref('venues/$_venueId/incidents/$incidentId')
        .update(incident.toMap());

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$staffName has been dispatched.'),
        backgroundColor: Colors.green[700],
      ),
    );
  }

  void _escalateIncident(String incidentId) async {
    final int index = _incidents.indexWhere((i) => i.id == incidentId);
    if (index == -1) return;
    final incident = _incidents[index];
    incident.status = IncidentStatus.escalated;
    incident.severity = 5;
    incident.timeline.add(IncidentUpdate(
      timestamp: DateTime.now().millisecondsSinceEpoch,
      updateText: 'Escalated to Emergency Services',
    ));
    await FirebaseDatabase.instance
        .ref('venues/$_venueId/incidents/$incidentId')
        .update(incident.toMap());

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Incident escalated! Emergency Services Protocol Triggered.'),
        backgroundColor: Colors.red[900],
      ),
    );
  }

  void _resolveIncident(String incidentId) async {
    final index = _incidents.indexWhere((i) => i.id == incidentId);
    if (index == -1) return;
    
    setState(() {
      _incidents[index].status = IncidentStatus.resolved;
      _incidents[index].resolvedAt = DateTime.now().millisecondsSinceEpoch;
      _incidents[index].timeline.add(IncidentUpdate(
        timestamp: DateTime.now().millisecondsSinceEpoch,
        updateText: 'Incident marked as Resolved by Admin.',
      ));
    });

    try {
      await FirebaseDatabase.instance
          .ref('venues/$_venueId/incidents/$incidentId')
          .update(_incidents[index].toMap());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Incident resolved.')),
        );
      }
    } catch (e) {
      debugPrint('Failed to resolve incident: $e');
    }
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    var filteredIncidents = _incidents.where((i) {
      final text = _searchQuery.toLowerCase();
      final textMatch = i.type.name.toLowerCase().contains(text) || i.affectedZone.toLowerCase().contains(text);
      final typeMatch = _filterType == null || i.type == _filterType;
      return textMatch && typeMatch;
    }).toList();

    var filteredAlerts = _rawAlerts.where((a) {
      final text = _searchQuery.toLowerCase();
      final typeName = (a.type ?? EmergencyType.other).name.toLowerCase();
      final textMatch = typeName.contains(text) ||
          a.roomNumber.toLowerCase().contains(text) ||
          a.description.toLowerCase().contains(text);
      final typeMatch = _filterType == null || a.type == _filterType;
      return textMatch && typeMatch;
    }).toList();

    var activeIncidents = filteredIncidents.where((i) => i.status != IncidentStatus.resolved).toList();
    var resolvedIncidents = filteredIncidents.where((i) => i.status == IncidentStatus.resolved).toList();

    if (_sortBy == 'severity') {
      activeIncidents.sort((a, b) => b.severity.compareTo(a.severity));
      resolvedIncidents.sort((a, b) => b.severity.compareTo(a.severity));
      filteredAlerts.sort((a, b) => (b.severity ?? 3).compareTo(a.severity ?? 3));
    } else {
      activeIncidents.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      resolvedIncidents.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      filteredAlerts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    }

    final int totalCount = activeIncidents.length + _rawAlerts.length;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.admin_panel_settings, color: Colors.white),
            const SizedBox(width: 12),
            const Text(
              'CrisisNet Command Dashboard',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            Chip(
              backgroundColor: totalCount > 0 ? Colors.red[900] : Colors.grey[800],
              label: Text(
                '$totalCount Active ${totalCount == 1 ? 'Alert' : 'Alerts'}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 16),
            IconButton(
              icon: const Icon(Icons.analytics, color: Colors.blueAccent),
              tooltip: 'View Performance Analytics',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
              tooltip: 'Clear Database',
              onPressed: _clearDatabase,
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              offset: const Offset(0, 45),
              color: Colors.grey[900],
              icon: const CircleAvatar(
                backgroundColor: Colors.grey,
                child: Icon(Icons.person, color: Colors.white),
              ),
              onSelected: (value) {
                if (value == 'logout') {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Logging out...')),
                  );
                } else if (value == 'settings') {
                  showDialog(
                    context: context,
                    builder: (context) => const StaffProfileDialog(initialTab: 1),
                  );
                } else if (value == 'profile') {
                  showDialog(
                    context: context,
                    builder: (context) => const StaffProfileDialog(initialTab: 0),
                  );
                }
              },
              itemBuilder: (BuildContext context) => [
                const PopupMenuItem(
                  value: 'profile',
                  child: Row(children: [Icon(Icons.badge, color: Colors.white), SizedBox(width: 8), Text('Admin Profile', style: TextStyle(color: Colors.white))]),
                ),
                const PopupMenuItem(
                  value: 'settings',
                  child: Row(children: [Icon(Icons.settings, color: Colors.white), SizedBox(width: 8), Text('System Settings', style: TextStyle(color: Colors.white))]),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'logout',
                  child: Row(children: [Icon(Icons.logout, color: Colors.redAccent), SizedBox(width: 8), Text('Sign Out', style: TextStyle(color: Colors.redAccent))]),
                ),
              ],
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E1E2C),
        elevation: 1,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: Colors.white12, height: 1.0),
        ),
      ),
      body: Row(
        children: [
          // ── Left Sidebar: Incident + Alert List ──────────────────────────
          Container(
            width: 400,
            decoration: const BoxDecoration(
              color: Color(0xFF1E1E2C),
              border: Border(right: BorderSide(color: Colors.white12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: 'Search by type, room, keyword...',
                      hintStyle: const TextStyle(color: Colors.white54),
                      prefixIcon: const Icon(Icons.search, color: Colors.white54),
                      filled: true,
                      fillColor: Colors.grey[900],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                
                // Add Filter Row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<EmergencyType?>(
                            dropdownColor: Colors.grey[900],
                            value: _filterType,
                            hint: const Text('All Categories', style: TextStyle(color: Colors.white70, fontSize: 13)),
                            isExpanded: true,
                            items: [
                              const DropdownMenuItem(value: null, child: Text('All Categories', style: TextStyle(color: Colors.white, fontSize: 13))),
                              ...EmergencyType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.name.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 13))))
                            ],
                            onChanged: (val) => setState(() => _filterType = val),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            dropdownColor: Colors.grey[900],
                            value: _sortBy,
                            isExpanded: true,
                            items: const [
                              DropdownMenuItem(value: 'severity', child: Text('Sort: Severity', style: TextStyle(color: Colors.white, fontSize: 13))),
                              DropdownMenuItem(value: 'recent', child: Text('Sort: Recent', style: TextStyle(color: Colors.white, fontSize: 13))),
                            ],
                            onChanged: (val) => setState(() => _sortBy = val!),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      // ── Triaged Incidents section ───────────────────────────--
                      if (activeIncidents.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                          child: Text(
                            'AI-TRIAGED INCIDENTS',
                            style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: 11),
                          ),
                        ),
                        ...activeIncidents.map((incident) => IncidentCard(
                          incidentData: incident,
                          onAssign: () => _showAssignDialog(context, incident.id),
                          onEscalate: () => _escalateIncident(incident.id),
                          onResolve: () => _resolveIncident(incident.id),
                        )),
                      ],

                      // ── Resolved Incidents section ──────────────────────────
                      if (resolvedIncidents.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 24, 16, 4),
                          child: Text(
                            'RESOLVED',
                            style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: 11),
                          ),
                        ),
                        ...resolvedIncidents.map((incident) => Opacity(
                          opacity: 0.6,
                          child: IncidentCard(
                            incidentData: incident,
                            onAssign: () {},
                            onEscalate: () {},
                            onResolve: () {}, // Already resolved
                          ),
                        )),
                      ],

                      // ── Raw SOS Alerts section (pending triage) ─────────────
                      if (filteredAlerts.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                          child: Text(
                            'INCOMING SOS — PENDING TRIAGE',
                            style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: 11),
                          ),
                        ),
                        ...filteredAlerts.map((alert) => _buildAlertCard(alert)),
                      ],

                      // ── Empty state ─────────────────────────────────────────
                      if (activeIncidents.isEmpty && resolvedIncidents.isEmpty && filteredAlerts.isEmpty)
                        SizedBox(
                          height: 400,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.shield_outlined, size: 64, color: Colors.white12),
                                const SizedBox(height: 16),
                                const Text(
                                  'All Clear',
                                  style: TextStyle(color: Colors.white38, fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'No active alerts at this venue.',
                                  style: TextStyle(color: Colors.white24, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Main Panel: Venue Map ──────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: VenueMap(incidents: filteredIncidents),
            ),
          ),
        ],
      ),
    );
  }

  /// Card for raw guest SOS alerts (not yet triaged into incidents by Gemini).
  Widget _buildAlertCard(Alert alert) {
    final DateTime time = DateTime.fromMillisecondsSinceEpoch(alert.timestamp);
    final String timeStr = '${time.hour}:${time.minute.toString().padLeft(2, '0')}';

    Color typeColor;
    IconData typeIcon;
    switch (alert.type ?? EmergencyType.other) {
      case EmergencyType.fire:
        typeColor = Colors.orange;
        typeIcon = Icons.local_fire_department;
        break;
      case EmergencyType.medical:
        typeColor = Colors.redAccent;
        typeIcon = Icons.medical_services;
        break;
      case EmergencyType.security:
        typeColor = Colors.lightBlueAccent;
        typeIcon = Icons.security;
        break;
      case EmergencyType.infrastructure:
        typeColor = Colors.brown;
        typeIcon = Icons.construction;
        break;
      case EmergencyType.other:
      default:
        typeColor = Colors.grey;
        typeIcon = Icons.warning;
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.orangeAccent.withValues(alpha: 0.1),
            blurRadius: 8,
            spreadRadius: 1,
          )
        ]
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(typeIcon, color: typeColor, size: 18),
                const SizedBox(width: 8),
                Text(
                  'SOS: ${(alert.type ?? EmergencyType.other).name.toUpperCase()}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
                  ),
                  child: const Text(
                    'PENDING TRIAGE',
                    style: TextStyle(color: Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                )
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on, size: 13, color: Colors.white54),
                const SizedBox(width: 4),
                Text(
                  'Room ${alert.roomNumber} · Floor ${alert.floor}',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const Spacer(),
                const Icon(Icons.access_time, size: 13, color: Colors.white54),
                const SizedBox(width: 4),
                Text(timeStr, style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
            if (alert.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '"${alert.description}"',
                style: const TextStyle(color: Colors.white54, fontSize: 13, fontStyle: FontStyle.italic),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Alert ID: ${alert.id.substring(0, 8)}...',
              style: const TextStyle(color: Colors.white24, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  void _showAssignDialog(BuildContext context, String incidentId) {
    final List<String> staffList = [
      'Security Team A',
      'Medical Response 1',
      'Floor Manager',
      'Maintenance Crew',
    ];

    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text('Assign Staff', style: TextStyle(color: Colors.white)),
          content: SizedBox(
            width: 300,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: staffList.length,
              itemBuilder: (context, i) {
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person, size: 16)),
                  title: Text(staffList[i], style: const TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _assignStaff(incidentId, staffList[i]);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
          ],
        );
      },
    );
  }
}

class StaffProfileDialog extends StatefulWidget {
  final int initialTab;
  const StaffProfileDialog({super.key, this.initialTab = 0});

  @override
  State<StaffProfileDialog> createState() => _StaffProfileDialogState();
}

class _StaffProfileDialogState extends State<StaffProfileDialog> {
  late int _selectedTab;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E1E2C),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 600,
        height: 400,
        child: Row(
          children: [
            // Sidebar
            Container(
              width: 150,
              decoration: BoxDecoration(
                color: Colors.black26,
                border: Border(right: BorderSide(color: Colors.white12)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  const CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.blueAccent,
                    child: Icon(Icons.person, size: 30, color: Colors.white),
                  ),
                  const SizedBox(height: 10),
                  const Text('Admin', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  const Text('Command Center', style: TextStyle(color: Colors.white54, fontSize: 11)),
                  const SizedBox(height: 20),
                  ListTile(
                    selected: _selectedTab == 0,
                    selectedTileColor: Colors.blueAccent.withValues(alpha: 0.2),
                    leading: Icon(Icons.badge, color: _selectedTab == 0 ? Colors.blueAccent : Colors.white54),
                    title: Text('Profile', style: TextStyle(color: _selectedTab == 0 ? Colors.white : Colors.white54)),
                    onTap: () => setState(() => _selectedTab = 0),
                  ),
                  ListTile(
                    selected: _selectedTab == 1,
                    selectedTileColor: Colors.blueAccent.withValues(alpha: 0.2),
                    leading: Icon(Icons.settings, color: _selectedTab == 1 ? Colors.blueAccent : Colors.white54),
                    title: Text('Settings', style: TextStyle(color: _selectedTab == 1 ? Colors.white : Colors.white54)),
                    onTap: () => setState(() => _selectedTab = 1),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: _selectedTab == 0 ? _buildProfile() : _buildSettings(),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildProfile() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Staff Profile', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        const Divider(color: Colors.white12),
        const SizedBox(height: 16),
        _infoRow('Name', 'Admin User'),
        _infoRow('Role', 'System Administrator'),
        _infoRow('ID', 'EMP-001'),
        _infoRow('Department', 'Command Center'),
        _infoRow('Clearance', 'Level 5 (Max)'),
      ],
    );
  }

  Widget _buildSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('System Settings', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        const Divider(color: Colors.white12),
        const SizedBox(height: 16),
        SwitchListTile(
          title: const Text('Sound Alarms', style: TextStyle(color: Colors.white)),
          subtitle: const Text('Play audible warning on new active SOS', style: TextStyle(color: Colors.white54)),
          value: true,
          onChanged: (val) {},
          activeColor: Colors.blueAccent,
        ),
        SwitchListTile(
          title: const Text('Auto-Assign Nearest', style: TextStyle(color: Colors.white)),
          subtitle: const Text('Automatically dispatch closest medical team', style: TextStyle(color: Colors.white54)),
          value: false,
          onChanged: (val) {},
          activeColor: Colors.blueAccent,
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text(label, style: const TextStyle(color: Colors.white54))),
          Expanded(child: Text(value, style: const TextStyle(color: Colors.white))),
        ],
      ),
    );
  }
}
