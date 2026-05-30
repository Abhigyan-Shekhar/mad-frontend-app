import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/location_service.dart';
import '../services/mapbox_service.dart';
import '../services/navigation_session_service.dart';
import '../services/supabase_service.dart';
import '../widgets/saferoute_appbar.dart';

class TabGuardianScreen extends StatefulWidget {
  const TabGuardianScreen({super.key});

  @override
  State<TabGuardianScreen> createState() => _TabGuardianScreenState();
}

class _TabGuardianScreenState extends State<TabGuardianScreen> {
  final _svc = SupabaseService.instance;
  final _mapCtrl = MapController();
  final _distance = const Distance();

  List<Map<String, dynamic>> _contacts = const [];
  List<Map<String, dynamic>> _trips = const [];
  List<Map<String, dynamic>> _routeHazards = const [];
  Map<String, dynamic>? _activeTrip;
  Map<String, dynamic>? _latestAnalysis;
  Map<String, dynamic>? _latestPing;
  LatLng? _currentPos;
  List<LatLng> _routePoints = const [];
  bool _loading = true;
  bool _tripLoading = false;
  RealtimeChannel? _hazardsChannel;
  StreamSubscription<List<Map<String, dynamic>>>? _pingSub;
  StreamSubscription<dynamic>? _positionSub;

  @override
  void initState() {
    super.initState();
    _load();
    _subscribeToHazards();
  }

  @override
  void dispose() {
    _pingSub?.cancel();
    _positionSub?.cancel();
    _hazardsChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final contacts = await _svc.getEmergencyContacts();
      final trips = await _svc.getMyTrips();
      final active = await _svc.getActiveTrip();
      final latest = active == null
          ? null
          : await _svc.getLatestTripPing(active['id']);
      final latestAnalysis = await _svc.getLatestRouteAnalysis(
        tripId: active?['id']?.toString(),
      );
      final hazards = await _svc.getActiveHazards();

      var routePoints = <LatLng>[];
      LatLng? current;
      if (active != null) {
        final start = _tripStart(active);
        final end = _tripEnd(active);
        current = _pingPoint(latest) ?? start;
        routePoints = [start, end];
        try {
          final routes = await MapboxService.instance.directions(
            start: start,
            end: end,
          );
          if (routes.isNotEmpty) {
            routePoints = routes.first.points;
            NavigationSessionService.instance.activateRoute(
              routes.first,
              initialLocation: current,
            );
          }
        } catch (_) {
          // Use the direct start/end line when routing is unavailable.
        }
      } else {
        try {
          final position = await LocationService.currentPosition();
          current = LatLng(position.latitude, position.longitude);
        } catch (_) {
          current = const LatLng(12.9716, 77.5946);
        }
      }

      if (!mounted) return;
      setState(() {
        _contacts = contacts;
        _trips = trips;
        _activeTrip = active;
        _latestAnalysis = latestAnalysis;
        _latestPing = latest;
        _currentPos = current;
        _routePoints = routePoints;
        _routeHazards = active == null
            ? const []
            : _hazardsNearRoute(routePoints, hazards).take(5).toList();
        _loading = false;
      });

      if (active != null) {
        _listenToActiveTrip(active['id'].toString());
        _startDeviceTracking();
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  void _subscribeToHazards() {
    _hazardsChannel = _svc.listenForNewHazards((hazard) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('New hazard: ${hazard['hazard_type'] ?? 'Unknown'}'),
          backgroundColor: const Color(0xFFD97706),
          duration: const Duration(seconds: 4),
        ),
      );
      _load();
    });
  }

  void _listenToActiveTrip(String tripId) {
    _pingSub?.cancel();
    _pingSub = _svc.listenToTripPings(tripId).listen((pings) {
      if (pings.isEmpty || !mounted) return;
      final ping = pings.first;
      final point = _pingPoint(ping);
      if (point == null) return;
      setState(() {
        _latestPing = ping;
        _currentPos = point;
      });
      try {
        _mapCtrl.move(point, 14);
      } catch (_) {}
    });
  }

  void _startDeviceTracking() {
    _positionSub?.cancel();
    _positionSub = LocationService.positionStream().listen(
      (position) async {
        final tripId = _activeTrip?['id']?.toString();
        if (tripId == null) return;
        final speedKmh = (position.speed * 3.6).clamp(0, 300).toDouble();
        final point = LatLng(position.latitude, position.longitude);
        if (mounted) setState(() => _currentPos = point);
        NavigationSessionService.instance.updateWithLocation(point);
        await _svc.sendLocationPing(
          tripId: tripId,
          lat: point.latitude,
          lng: point.longitude,
          speed: speedKmh,
        );
      },
      onError: (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString()),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      },
    );
  }

  Future<void> _showStartTripDialog() async {
    final destinationCtrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(
          'Start SafeRoute Trip',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: destinationCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Destination',
            hintText: 'Enter destination',
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) {
            Navigator.pop(context);
            _startTrip(destinationCtrl.text);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E293B),
            ),
            onPressed: () {
              Navigator.pop(context);
              _startTrip(destinationCtrl.text);
            },
            child: const Text('Start', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    destinationCtrl.dispose();
  }

  Future<void> _startTrip(String destinationText) async {
    if (destinationText.trim().isEmpty) return;

    setState(() => _tripLoading = true);
    try {
      final position = await LocationService.currentPosition();
      final start = LatLng(position.latitude, position.longitude);
      final destination = await MapboxService.instance.geocode(
        destinationText,
        proximity: start,
      );
      final trip = await _svc.startTrip(
        startLat: start.latitude,
        startLng: start.longitude,
        endLat: destination.point.latitude,
        endLng: destination.point.longitude,
        destinationName: destination.label,
      );
      await _svc.sendLocationPing(
        tripId: trip['id'].toString(),
        lat: start.latitude,
        lng: start.longitude,
        speed: (position.speed * 3.6).clamp(0, 300).toDouble(),
      );
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Trip started. Guardians can now track this route.'),
          backgroundColor: Color(0xFF059669),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    } finally {
      if (mounted) setState(() => _tripLoading = false);
    }
  }

  Future<void> _endTrip() async {
    final trip = _activeTrip;
    if (trip == null) return;
    setState(() => _tripLoading = true);
    try {
      await _svc.endTrip(trip['id'].toString());
      NavigationSessionService.instance.clear();
      await _positionSub?.cancel();
      await _pingSub?.cancel();
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Trip ended.'),
          backgroundColor: Color(0xFF059669),
        ),
      );
    } finally {
      if (mounted) setState(() => _tripLoading = false);
    }
  }

  Future<void> _triggerSOS() async {
    final point = _currentPos;
    if (point == null) return;
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(
          'Trigger SOS?',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'This will create an emergency alert for your active trip.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            onPressed: () async {
              Navigator.pop(context);
              await _svc.triggerSOS(
                lat: point.latitude,
                lng: point.longitude,
                tripId: _activeTrip?['id']?.toString(),
              );
              NavigationSessionService.instance.markEmergencyActive();
              await _load();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('SOS sent.'),
                  backgroundColor: Color(0xFFEF4444),
                ),
              );
            },
            child: const Text(
              'Send SOS',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addContact() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(
          'Add Guardian',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'Guardian name',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone',
                hintText: '+91 9876543210',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E293B),
            ),
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final phone = phoneCtrl.text.trim();
              if (name.isEmpty || phone.isEmpty) return;
              Navigator.pop(context);
              await _svc.addEmergencyContact(
                name: name,
                phone: phone,
                isPrimary: _contacts.isEmpty,
              );
              await _load();
            },
            child: const Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    nameCtrl.dispose();
    phoneCtrl.dispose();
  }

  Future<void> _deleteContact(String id) async {
    await _svc.deleteEmergencyContact(id);
    await _load();
  }

  Future<void> _reportHazard() async {
    final point = _currentPos;
    if (point == null) return;
    final descriptionCtrl = TextEditingController();
    var selected = 'pothole';
    await showDialog<void>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text(
            'Report Hazard',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selected,
                items: const [
                  DropdownMenuItem(value: 'pothole', child: Text('Pothole')),
                  DropdownMenuItem(value: 'lighting', child: Text('Lighting')),
                  DropdownMenuItem(value: 'theft', child: Text('Theft risk')),
                  DropdownMenuItem(value: 'accident', child: Text('Accident')),
                  DropdownMenuItem(value: 'deadzone', child: Text('Deadzone')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => selected = value);
                  }
                },
                decoration: const InputDecoration(labelText: 'Type'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'What did you notice?',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E293B),
              ),
              onPressed: () async {
                Navigator.pop(context);
                await _svc.reportHazard(
                  hazardType: selected,
                  lat: point.latitude,
                  lng: point.longitude,
                  description: descriptionCtrl.text.trim(),
                );
                await _load();
              },
              child: const Text(
                'Report',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
    descriptionCtrl.dispose();
  }

  Future<void> _callPrimary() async {
    final contact = _primaryContact;
    if (contact == null) {
      _addContact();
      return;
    }
    final phone = contact['phone_number']?.toString();
    if (phone == null || phone.isEmpty) return;
    await launchUrl(Uri(scheme: 'tel', path: phone));
  }

  Future<void> _messagePrimary() async {
    final contact = _primaryContact;
    if (contact == null) {
      _addContact();
      return;
    }
    final phone = contact['phone_number']?.toString();
    if (phone == null || phone.isEmpty) return;
    final point = _currentPos;
    final body = point == null
        ? 'I am using SafeRoute.'
        : 'I am using SafeRoute. Current location: https://maps.google.com/?q=${point.latitude},${point.longitude}';
    await launchUrl(
      Uri(scheme: 'sms', path: phone, queryParameters: {'body': body}),
    );
  }

  Map<String, dynamic>? get _primaryContact {
    if (_contacts.isEmpty) return null;
    return _contacts.firstWhere(
      (contact) => contact['is_primary'] == true,
      orElse: () => _contacts.first,
    );
  }

  LatLng _tripStart(Map<String, dynamic> trip) => LatLng(
    (trip['start_lat'] as num).toDouble(),
    (trip['start_lng'] as num).toDouble(),
  );

  LatLng _tripEnd(Map<String, dynamic> trip) => LatLng(
    (trip['end_lat'] as num).toDouble(),
    (trip['end_lng'] as num).toDouble(),
  );

  LatLng? _pingPoint(Map<String, dynamic>? ping) {
    final lat = (ping?['lat'] as num?)?.toDouble();
    final lng = (ping?['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  List<Map<String, dynamic>> _hazardsNearRoute(
    List<LatLng> points,
    List<Map<String, dynamic>> hazards,
  ) {
    if (points.isEmpty) return const [];
    return hazards
        .where((hazard) {
          final lat = (hazard['lat'] as num?)?.toDouble();
          final lng = (hazard['lng'] as num?)?.toDouble();
          if (lat == null || lng == null) return false;
          final hazardPoint = LatLng(lat, lng);
          return points.any(
            (point) =>
                _distance.as(LengthUnit.Meter, point, hazardPoint) <= 500,
          );
        })
        .toList(growable: false);
  }

  String _tripTitle() {
    final trip = _activeTrip;
    if (trip == null) return 'No active trip';
    final destination = trip['destination_name']?.toString();
    return destination == null || destination.isEmpty
        ? 'Active SafeRoute Trip'
        : 'To $destination';
  }

  String _formatTime(dynamic value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    if (parsed == null) return '--';
    final local = parsed.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _takenDuration() {
    final created = DateTime.tryParse(
      _activeTrip?['created_at']?.toString() ?? '',
    );
    if (created == null) return '--';
    final minutes = DateTime.now().difference(created.toLocal()).inMinutes;
    return '${minutes.clamp(0, 999)}m';
  }

  double _speedKmh() {
    return ((_latestPing?['speed'] as num?)?.toDouble() ?? 0)
        .clamp(0, 300)
        .toDouble();
  }

  double? _distanceLeftKm() {
    final trip = _activeTrip;
    final current = _currentPos;
    if (trip == null || current == null) return null;
    return _distance.as(LengthUnit.Kilometer, current, _tripEnd(trip));
  }

  String _etaText() {
    final distanceLeft = _distanceLeftKm();
    final speed = _speedKmh();
    if (distanceLeft == null || speed < 3) return '--';
    final minutes = (distanceLeft / speed * 60).round();
    final eta = DateTime.now().add(Duration(minutes: minutes));
    return '${eta.hour.toString().padLeft(2, '0')}:${eta.minute.toString().padLeft(2, '0')}';
  }

  String _coverageText() {
    if (_routeHazards.any((hazard) => hazard['hazard_type'] == 'deadzone')) {
      return 'Zone Ahead';
    }
    if (_routeHazards.any((hazard) => hazard['hazard_type'] == 'lighting')) {
      return 'Lighting Alert';
    }
    return _activeTrip == null ? '--' : 'Good';
  }

  @override
  Widget build(BuildContext context) {
    final liveSnapshot = NavigationSessionService.instance.currentSnapshot;
    final currentInstruction =
        NavigationSessionService.instance.currentInstruction;
    final nextInstruction = NavigationSessionService.instance.nextInstruction;
    final emergencyActive = liveSnapshot?.isEmergencyActive ?? false;
    final tripActive = _activeTrip != null;
    final current = _currentPos ?? const LatLng(12.9716, 77.5946);
    final distanceLeft = _distanceLeftKm();

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: RefreshIndicator(
        onRefresh: _load,
        color: const Color(0xFF1E293B),
        child: CustomScrollView(
          slivers: [
            const SafeRouteAppBar(subtitle: 'Guardian Mode'),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'TRACKED TRIP',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFF6B7280),
                                      letterSpacing: 1.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _tripTitle(),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF111827),
                                    ),
                                  ),
                                  if (_latestAnalysis != null) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      'Safety score ${((_latestAnalysis!['score'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}/100'
                                      '${_latestAnalysis!['ward_name'] == null ? '' : ' · ${_latestAnalysis!['ward_name']}'}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF6B7280),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (tripActive)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFECFDF5),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(
                                              0xFF10B981,
                                            ).withOpacity(0.5),
                                            blurRadius: 6,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Text(
                                      'LIVE',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF059669),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: SizedBox(
                            height: 260,
                            child: FlutterMap(
                              mapController: _mapCtrl,
                              options: MapOptions(
                                initialCenter: current,
                                initialZoom: tripActive ? 13 : 12,
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate:
                                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                  userAgentPackageName: 'com.saferoute.app',
                                ),
                                if (_routePoints.length >= 2)
                                  PolylineLayer(
                                    polylines: [
                                      Polyline(
                                        points: _routePoints,
                                        color: const Color(0xFF3B82F6),
                                        strokeWidth: 4,
                                      ),
                                    ],
                                  ),
                                MarkerLayer(
                                  markers: [
                                    if (tripActive)
                                      Marker(
                                        point: _tripStart(_activeTrip!),
                                        width: 40,
                                        height: 40,
                                        child: const _MapPin(
                                          color: Color(0xFF3B82F6),
                                          icon: Icons.flag_rounded,
                                        ),
                                      ),
                                    if (tripActive)
                                      Marker(
                                        point: _tripEnd(_activeTrip!),
                                        width: 40,
                                        height: 40,
                                        child: const _MapPin(
                                          color: Color(0xFFEF4444),
                                          icon: Icons.location_on_rounded,
                                        ),
                                      ),
                                    if (tripActive)
                                      Marker(
                                        point: current,
                                        width: 48,
                                        height: 48,
                                        child: const _MapPin(
                                          color: Color(0xFF10B981),
                                          icon: Icons.navigation_rounded,
                                        ),
                                      ),
                                    ..._routeHazards.map((hazard) {
                                      final lat = (hazard['lat'] as num)
                                          .toDouble();
                                      final lng = (hazard['lng'] as num)
                                          .toDouble();
                                      return Marker(
                                        point: LatLng(lat, lng),
                                        width: 40,
                                        height: 40,
                                        child: const _MapPin(
                                          color: Color(0xFFF59E0B),
                                          icon: Icons.warning_amber_rounded,
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (tripActive && currentInstruction != null)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: emergencyActive
                                  ? const Color(0xFFFEF2F2)
                                  : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: emergencyActive
                                    ? const Color(0xFFFCA5A5)
                                    : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  emergencyActive
                                      ? 'Emergency Tracking Active'
                                      : 'Live Maneuvers',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: emergencyActive
                                        ? const Color(0xFFB91C1C)
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Now: $currentInstruction',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF111827),
                                  ),
                                ),
                                if (nextInstruction != null)
                                  Text(
                                    'Next: $nextInstruction',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF475569),
                                    ),
                                  ),
                                if (liveSnapshot != null) ...[
                                  const SizedBox(height: 10),
                                  LinearProgressIndicator(
                                    value: liveSnapshot.state.progressFraction,
                                    minHeight: 8,
                                    borderRadius: BorderRadius.circular(999),
                                    backgroundColor: const Color(0xFFE2E8F0),
                                    color: liveSnapshot.state.hasArrived
                                        ? const Color(0xFF059669)
                                        : const Color(0xFF2563EB),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        if (tripActive && currentInstruction != null)
                          const SizedBox(height: 16),
                        if (tripActive)
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFE5E7EB),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _TripStat(
                                  'Start',
                                  _formatTime(_activeTrip!['created_at']),
                                ),
                                _vDivider(),
                                _TripStat('Taken', _takenDuration()),
                                _vDivider(),
                                _TripStat(
                                  'Left',
                                  distanceLeft == null
                                      ? '--'
                                      : '${distanceLeft.toStringAsFixed(1)}km',
                                ),
                                _vDivider(),
                                _TripStat('ETA', _etaText()),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'TRIP STATUS',
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFF6B7280),
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          tripActive
                              ? 'Journey is Active'
                              : 'No Journey Started',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _StatusRow(
                          'Current Speed',
                          '${_speedKmh().toStringAsFixed(0)} km/h',
                        ),
                        const SizedBox(height: 8),
                        _StatusRow(
                          'Distance Left',
                          distanceLeft == null
                              ? '--'
                              : '${distanceLeft.toStringAsFixed(1)} km',
                        ),
                        const SizedBox(height: 8),
                        _StatusRowColored(
                          'Route Status',
                          tripActive ? 'Tracking' : '--',
                          const Color(0xFFEFF6FF),
                          const Color(0xFFBFDBFE),
                          const Color(0xFF2563EB),
                        ),
                        const SizedBox(height: 8),
                        _StatusRowColored(
                          'Coverage',
                          _coverageText(),
                          const Color(0xFFFFFBEB),
                          const Color(0xFFFCD34D),
                          const Color(0xFFD97706),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _callPrimary,
                                icon: const Icon(Icons.phone, size: 18),
                                label: const Text(
                                  'Call',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1E293B),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _messagePrimary,
                                icon: const Icon(
                                  Icons.message_outlined,
                                  size: 18,
                                ),
                                label: const Text(
                                  'Message',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF374151),
                                  side: const BorderSide(
                                    color: Color(0xFFD1D5DB),
                                    width: 2,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Live Alerts',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF111827),
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF7ED),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${_routeHazards.length} Active',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFEA580C),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        if (_loading)
                          const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF1E293B),
                            ),
                          )
                        else if (_routeHazards.isEmpty)
                          const _EmptyPanel(text: 'No active route alerts.')
                        else
                          ..._routeHazards.map(
                            (hazard) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _HazardAlert(hazard: hazard),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Guardians',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF111827),
                              ),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: _addContact,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(
                                      Icons.add,
                                      size: 16,
                                      color: Color(0xFF1E293B),
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Add',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF1E293B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        if (_loading)
                          const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        if (!_loading && _contacts.isEmpty)
                          const _EmptyPanel(
                            text:
                                'No guardians added yet.\nTap + Add to add one.',
                          ),
                        ..._contacts.map(
                          (contact) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF9FAFB),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFE5E7EB),
                                ),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: const Color(0xFF1E293B),
                                    child: Text(
                                      _initial(
                                        contact['contact_name']?.toString(),
                                      ),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          contact['contact_name']?.toString() ??
                                              '',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF111827),
                                          ),
                                        ),
                                        Text(
                                          contact['phone_number']?.toString() ??
                                              '',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF6B7280),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () => _deleteContact(
                                      contact['id'].toString(),
                                    ),
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Color(0xFFEF4444),
                                      size: 20,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'QUICK ACTIONS',
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFF6B7280),
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: _tripLoading
                                ? null
                                : (tripActive
                                      ? _endTrip
                                      : _showStartTripDialog),
                            icon: Icon(
                              tripActive
                                  ? Icons.stop_rounded
                                  : Icons.play_arrow_rounded,
                              size: 22,
                            ),
                            label: Text(
                              tripActive
                                  ? 'End SafeRoute Trip'
                                  : 'Start SafeRoute Trip',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: tripActive
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFF1E293B),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: OutlinedButton.icon(
                            onPressed: _triggerSOS,
                            icon: const Icon(
                              Icons.sos_rounded,
                              size: 22,
                              color: Color(0xFFEF4444),
                            ),
                            label: const Text(
                              'Emergency SOS',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFEF4444),
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                color: Color(0xFFFCA5A5),
                                width: 2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: OutlinedButton.icon(
                            onPressed: _reportHazard,
                            icon: const Icon(
                              Icons.warning_amber_rounded,
                              size: 22,
                              color: Color(0xFFD97706),
                            ),
                            label: const Text(
                              'Report Route Hazard',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFD97706),
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                color: Color(0xFFFCD34D),
                                width: 2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_trips.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      '${_trips.length} recent trip(s) loaded from Supabase',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF9CA3AF),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _initial(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? '?' : trimmed[0].toUpperCase();
  }
}

Widget _vDivider() =>
    Container(height: 30, width: 1, color: const Color(0xFFE5E7EB));

class _MapPin extends StatelessWidget {
  final Color color;
  final IconData icon;

  const _MapPin({required this.color, required this.icon});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 3),
      boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 10)],
    ),
    child: Icon(icon, color: Colors.white, size: 20),
  );
}

class _TripStat extends StatelessWidget {
  final String label;
  final String value;
  const _TripStat(this.label, this.value);

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          color: Color(0xFF6B7280),
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 3),
      Text(
        value,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFF111827),
        ),
      ),
    ],
  );
}

class _StatusRow extends StatelessWidget {
  final String label;
  final String value;
  const _StatusRow(this.label, this.value);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: const Color(0xFFF9FAFB),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFE5E7EB)),
    ),
    child: Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF374151),
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF111827),
          ),
        ),
      ],
    ),
  );
}

class _StatusRowColored extends StatelessWidget {
  final String label;
  final String value;
  final Color bg;
  final Color border;
  final Color textColor;

  const _StatusRowColored(
    this.label,
    this.value,
    this.bg,
    this.border,
    this.textColor,
  );

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: border),
    ),
    child: Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF374151),
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
      ],
    ),
  );
}

class _HazardAlert extends StatelessWidget {
  final Map<String, dynamic> hazard;
  const _HazardAlert({required this.hazard});

  @override
  Widget build(BuildContext context) {
    final type = hazard['hazard_type']?.toString() ?? 'hazard';
    final description = hazard['description']?.toString();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFCD34D), width: 2),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFB45309),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type.isEmpty
                      ? 'Hazard'
                      : '${type[0].toUpperCase()}${type.substring(1)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description == null || description.isEmpty
                      ? 'Reported near this route.'
                      : description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF374151),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  final String text;
  const _EmptyPanel({required this.text});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFF9FAFB),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE5E7EB)),
    ),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Color(0xFF6B7280),
        fontSize: 13,
        height: 1.4,
      ),
    ),
  );
}
