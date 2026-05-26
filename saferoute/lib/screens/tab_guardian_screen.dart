import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../widgets/saferoute_appbar.dart';

class TabGuardianScreen extends StatefulWidget {
  const TabGuardianScreen({super.key});

  @override
  State<TabGuardianScreen> createState() => _TabGuardianScreenState();
}

class _TabGuardianScreenState extends State<TabGuardianScreen> {
  final _svc = SupabaseService.instance;
  List<Map<String, dynamic>> _contacts = [];
  List<Map<String, dynamic>> _trips = [];
  Map<String, dynamic>? _activeTrip;
  LatLng _currentPos = const LatLng(12.9716, 77.5946);
  bool _loading = true;
  bool _tripLoading = false;
  RealtimeChannel? _realtimeChannel;
  final _mapCtrl = MapController();

  @override
  void initState() {
    super.initState();
    _load();
    _subscribeToHazards();
  }

  Future<void> _load() async {
    try {
      final contacts = await _svc.getEmergencyContacts();
      final trips = await _svc.getMyTrips();
      final active = trips.firstWhere(
        (t) => t['status'] == 'active',
        orElse: () => <String, dynamic>{},
      );
      if (mounted) {
        setState(() {
          _contacts = contacts;
          _trips = trips;
          _activeTrip = active.isEmpty ? null : active;
          _loading = false;
        });
        if (_activeTrip != null) _listenToActiveTrip(_activeTrip!['id']);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _subscribeToHazards() {
    _svc.listenForNewHazards((hazard) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('⚠️ New hazard: ${hazard['hazard_type'] ?? 'Unknown'}'),
        backgroundColor: const Color(0xFFD97706),
        duration: const Duration(seconds: 4),
      ));
    });
  }

  void _listenToActiveTrip(String tripId) {
    _svc.listenToTripPings(tripId).listen((pings) {
      if (pings.isEmpty || !mounted) return;
      final lat = (pings.first['lat'] as num?)?.toDouble();
      final lng = (pings.first['lng'] as num?)?.toDouble();
      if (lat != null && lng != null) {
        setState(() => _currentPos = LatLng(lat, lng));
        try { _mapCtrl.move(_currentPos, 14); } catch (_) {}
      }
    });
  }

  Future<void> _startTrip() async {
    setState(() => _tripLoading = true);
    try {
      final id = await _svc.startTrip(
        from: 'Current Location',
        to: 'Destination',
        startLat: _currentPos.latitude,
        startLng: _currentPos.longitude,
        safetyScore: 78,
      );
      final trips = await _svc.getMyTrips();
      final active = trips.firstWhere((t) => t['id'] == id, orElse: () => <String, dynamic>{});
      if (mounted) {
        setState(() { _activeTrip = active.isEmpty ? null : active; _trips = trips; _tripLoading = false; });
        _listenToActiveTrip(id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Trip started! Guardians notified.'), backgroundColor: Color(0xFF059669)));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _tripLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sign in to start a trip. $e'), backgroundColor: const Color(0xFFEF4444)));
      }
    }
  }

  Future<void> _endTrip() async {
    if (_activeTrip == null) return;
    setState(() => _tripLoading = true);
    try {
      await _svc.endTrip(_activeTrip!['id']);
      final trips = await _svc.getMyTrips();
      if (mounted) setState(() { _activeTrip = null; _trips = trips; _tripLoading = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trip ended. Guardians notified.'), backgroundColor: Color(0xFF059669)));
    } catch (e) {
      if (mounted) setState(() => _tripLoading = false);
    }
  }

  Future<void> _triggerSOS() async {
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('Trigger SOS?', style: TextStyle(fontWeight: FontWeight.w700)),
      content: const Text('This will alert your emergency contacts immediately.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
          onPressed: () async {
            Navigator.pop(context);
            await _svc.triggerSOS(lat: _currentPos.latitude, lng: _currentPos.longitude, tripId: _activeTrip?['id']);
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('🆘 SOS sent to all contacts!'), backgroundColor: Color(0xFFEF4444)));
          },
          child: const Text('Send SOS', style: TextStyle(color: Colors.white)),
        ),
      ],
    ));
  }

  Future<void> _addContact() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('Add Guardian', style: TextStyle(fontWeight: FontWeight.w700)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name', hintText: 'Mom')),
        const SizedBox(height: 12),
        TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone', hintText: '+91 9876543210')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B)),
          onPressed: () async {
            Navigator.pop(context);
            await _svc.addEmergencyContact(name: nameCtrl.text, phone: phoneCtrl.text);
            _load();
          },
          child: const Text('Add', style: TextStyle(color: Colors.white)),
        ),
      ],
    ));
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool tripActive = _activeTrip != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: CustomScrollView(
        slivers: [
          const SafeRouteAppBar(subtitle: 'Guardian Mode'),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
            sliver: SliverList(delegate: SliverChildListDelegate([

              // ── Live Tracking card ────────────────────────────
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 4))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('TRACKED TRIP', style: TextStyle(fontSize: 10, color: Color(0xFF6B7280), letterSpacing: 1.5, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(
                          tripActive ? '${_activeTrip!['from_label']} → ${_activeTrip!['to_label']}' : 'No active trip',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
                        ),
                      ])),
                      if (tripActive) Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(10)),
                        child: Row(children: [
                          Container(width: 8, height: 8, decoration: BoxDecoration(color: const Color(0xFF10B981), shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: const Color(0xFF10B981).withOpacity(0.5), blurRadius: 6)])),
                          const SizedBox(width: 6),
                          const Text('LIVE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF059669))),
                        ]),
                      ),
                    ]),
                    const SizedBox(height: 16),

                    // Live map
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        height: 260,
                        child: FlutterMap(
                          mapController: _mapCtrl,
                          options: MapOptions(initialCenter: _currentPos, initialZoom: 13),
                          children: [
                            TileLayer(
                              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.saferoute.app',
                            ),
                            if (tripActive) MarkerLayer(markers: [
                              Marker(
                                point: _currentPos,
                                width: 48, height: 48,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 3),
                                    boxShadow: [BoxShadow(color: const Color(0xFF10B981).withOpacity(0.5), blurRadius: 12)],
                                  ),
                                  child: const Icon(Icons.navigation_rounded, color: Colors.white, size: 22),
                                ),
                              ),
                            ]),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Trip stats row (matching guardian-mode.html grid)
                    if (tripActive) Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE5E7EB))),
                      child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                        _TripStat('Status', _activeTrip!['status']?.toString().toUpperCase() ?? 'ACTIVE'),
                        _vDivider(),
                        _TripStat('Speed', '22 km/h'),
                        _vDivider(),
                        _TripStat('Route', 'On Track'),
                        _vDivider(),
                        _TripStat('Coverage', 'Good'),
                      ]),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Trip Status card ──────────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE5E7EB)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12)]),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('TRIP STATUS', style: TextStyle(fontSize: 10, color: Color(0xFF6B7280), letterSpacing: 1.5, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text(tripActive ? 'Journey is Active' : 'No Journey Started',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
                    const SizedBox(height: 16),
                    _StatusRow('Current Speed', '22 km/h'),
                    const SizedBox(height: 8),
                    _StatusRow('Distance Left', '2.8 km'),
                    const SizedBox(height: 8),
                    _StatusRowColored('Route Status', 'On Track', const Color(0xFFEFF6FF), const Color(0xFFBFDBFE), const Color(0xFF2563EB)),
                    const SizedBox(height: 8),
                    _StatusRowColored('Coverage', '⚠️ Zone Ahead', const Color(0xFFFFFBEB), const Color(0xFFFCD34D), const Color(0xFFD97706)),
                    const SizedBox(height: 20),

                    // Call / Message buttons matching HTML
                    Row(children: [
                      Expanded(child: ElevatedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.phone, size: 18),
                        label: const Text('Call', style: TextStyle(fontWeight: FontWeight.w700)),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B), foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.message_outlined, size: 18),
                        label: const Text('Message', style: TextStyle(fontWeight: FontWeight.w700)),
                        style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF374151),
                            side: const BorderSide(color: Color(0xFFD1D5DB), width: 2),
                            padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      )),
                    ]),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Live Alerts ───────────────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE5E7EB)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12)]),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Text('Live Alerts', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
                      const Spacer(),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: const Color(0xFFFFF7ED), borderRadius: BorderRadius.circular(8)),
                        child: const Text('2 Active', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFEA580C))),
                      ),
                    ]),
                    const SizedBox(height: 14),
                    _LiveAlert(bg: const Color(0xFFFFF1F2), border: const Color(0xFFFCA5A5), icon: Icons.navigation_rounded,
                      iconColor: const Color(0xFFDC2626), iconBg: const Color(0xFFFEE2E2),
                      title: 'Accident Ahead', body: 'Crash near Richmond Circle. ETA updated to 8:42 PM.'),
                    const SizedBox(height: 10),
                    _LiveAlert(bg: const Color(0xFFEFF6FF), border: const Color(0xFFBFDBFE), icon: Icons.location_on_rounded,
                      iconColor: const Color(0xFF2563EB), iconBg: const Color(0xFFDBEAFE),
                      title: 'Alternate Route', body: 'Adds 3 min but avoids blocked section.'),
                    const SizedBox(height: 10),
                    _LiveAlert(bg: const Color(0xFFFFFBEB), border: const Color(0xFFFCD34D), icon: Icons.sensors_rounded,
                      iconColor: const Color(0xFFB45309), iconBg: const Color(0xFFFEF3C7),
                      title: 'Coverage Loss', body: '30-mile no-service zone. Alerts may be delayed.'),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Emergency contacts ────────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE5E7EB)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12)]),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Text('Guardians', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
                      const Spacer(),
                      GestureDetector(
                        onTap: _addContact,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
                          child: const Row(children: [
                            Icon(Icons.add, size: 16, color: Color(0xFF1E293B)),
                            SizedBox(width: 4),
                            Text('Add', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                          ]),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 14),
                    if (_loading) const Center(child: CircularProgressIndicator(color: Color(0xFF1E293B))),
                    if (!_loading && _contacts.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE5E7EB))),
                        child: const Center(child: Text('No guardians added yet.\nTap + Add to add one.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF6B7280), fontSize: 13))),
                      ),
                    ..._contacts.map((c) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE5E7EB))),
                        child: Row(children: [
                          CircleAvatar(radius: 20, backgroundColor: const Color(0xFF1E293B), child: Text(c['name']?[0] ?? '?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(c['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF111827))),
                            Text(c['phone'] ?? '', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                          ])),
                          const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 22),
                        ]),
                      ),
                    )),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Quick Actions ─────────────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE5E7EB)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12)]),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('QUICK ACTIONS', style: TextStyle(fontSize: 10, color: Color(0xFF6B7280), letterSpacing: 1.5, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 14),
                    // Start/End trip button
                    SizedBox(
                      width: double.infinity, height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _tripLoading ? null : (tripActive ? _endTrip : _startTrip),
                        icon: Icon(tripActive ? Icons.stop_rounded : Icons.play_arrow_rounded, size: 22),
                        label: Text(tripActive ? 'End SafeRoute Trip' : 'Start SafeRoute Trip',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: tripActive ? const Color(0xFFEF4444) : const Color(0xFF1E293B),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // SOS button
                    SizedBox(
                      width: double.infinity, height: 52,
                      child: OutlinedButton.icon(
                        onPressed: _triggerSOS,
                        icon: const Icon(Icons.sos_rounded, size: 22, color: Color(0xFFEF4444)),
                        label: const Text('Emergency SOS', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFFEF4444))),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFFCA5A5), width: 2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            ])),
          ),
        ],
      ),
    );
  }
}

Widget _vDivider() => Container(height: 30, width: 1, color: const Color(0xFFE5E7EB));

class _TripStat extends StatelessWidget {
  final String label, value;
  const _TripStat(this.label, this.value);
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280), fontWeight: FontWeight.w600)),
    const SizedBox(height: 3),
    Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
  ]);
}

class _StatusRow extends StatelessWidget {
  final String label, value;
  const _StatusRow(this.label, this.value);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE5E7EB))),
    child: Row(children: [
      Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF374151), fontWeight: FontWeight.w500)),
      const Spacer(),
      Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
    ]),
  );
}

class _StatusRowColored extends StatelessWidget {
  final String label, value;
  final Color bg, border, textColor;
  const _StatusRowColored(this.label, this.value, this.bg, this.border, this.textColor);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: border)),
    child: Row(children: [
      Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF374151), fontWeight: FontWeight.w500)),
      const Spacer(),
      Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textColor)),
    ]),
  );
}

class _LiveAlert extends StatelessWidget {
  final Color bg, border, iconColor, iconBg;
  final IconData icon;
  final String title, body;
  const _LiveAlert({required this.bg, required this.border, required this.icon, required this.iconColor, required this.iconBg, required this.title, required this.body});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: border, width: 2)),
    child: Row(children: [
      Container(width: 40, height: 40, decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: iconColor, size: 20)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
        const SizedBox(height: 3),
        Text(body, style: const TextStyle(fontSize: 12, color: Color(0xFF374151), height: 1.4)),
      ])),
    ]),
  );
}
