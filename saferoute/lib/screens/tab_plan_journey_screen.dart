import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../services/bbmp_service.dart';
import '../services/location_service.dart';
import '../services/mapbox_service.dart';
import '../services/supabase_service.dart';
import '../widgets/saferoute_appbar.dart';

class TabPlanJourneyScreen extends StatefulWidget {
  final VoidCallback? onTripStarted;
  const TabPlanJourneyScreen({super.key, this.onTripStarted});

  @override
  State<TabPlanJourneyScreen> createState() => _TabPlanJourneyScreenState();
}

class _TabPlanJourneyScreenState extends State<TabPlanJourneyScreen> {
  final _fromCtrl = TextEditingController(text: 'Current Location');
  final _toCtrl = TextEditingController();
  final _distance = const Distance();

  bool _loading = false;
  bool _locating = true;
  List<_RouteOption>? _routes;
  LatLng? _startPoint;
  MapboxPlace? _destination;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCurrentLocation();
  }

  @override
  void dispose() {
    _fromCtrl.dispose();
    _toCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentLocation() async {
    try {
      final position = await LocationService.currentPosition();
      final point = LatLng(position.latitude, position.longitude);
      String label = 'Current Location';
      try {
        label = await MapboxService.instance.reverseGeocode(point) ?? label;
      } catch (_) {
        // Reverse geocode is optional; coordinates are enough for routing.
      }
      if (!mounted) return;
      setState(() {
        _startPoint = point;
        _fromCtrl.text = label;
        _locating = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _locating = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _findRoutes() async {
    if (_toCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Please enter a destination');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _routes = null;
    });

    try {
      var start = _startPoint;
      if (start == null) {
        final position = await LocationService.currentPosition();
        start = LatLng(position.latitude, position.longitude);
      }
      final destination = await MapboxService.instance.geocode(
        _toCtrl.text,
        proximity: start,
      );
      final navRoutes = await MapboxService.instance.directions(
        start: start,
        end: destination.point,
      );
      final activeHazards = await SupabaseService.instance.getActiveHazards();
      final baseSafety = await BbmpService.instance.routeSafetyScore(
        _fromCtrl.text,
        destination.label,
      );

      final drafts = navRoutes.take(3).map((route) {
        final nearbyHazards = _hazardsNearRoute(route.points, activeHazards);
        final penalty = nearbyHazards.fold<double>(
          0,
          (sum, hazard) => sum + _hazardPenalty(hazard['hazard_type']),
        );
        final score = (baseSafety - penalty).clamp(0, 100).toDouble();
        return _RouteDraft(
          route: route,
          score: score,
          nearbyHazards: nearbyHazards,
        );
      }).toList();

      drafts.sort((a, b) => b.score.compareTo(a.score));
      final options = drafts.asMap().entries.map((entry) {
        return _buildRouteOption(entry.key, entry.value, destination.label);
      }).toList(growable: false);

      if (!mounted) return;
      setState(() {
        _startPoint = start;
        _destination = destination;
        _routes = options;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load routes: $error';
        _loading = false;
      });
    }
  }

  Future<void> _startNavigation(_RouteOption route) async {
    if (route.route.points.length < 2) {
      setState(() => _error = 'Selected route is missing map geometry.');
      return;
    }

    setState(() => _loading = true);
    try {
      final current = await LocationService.currentPosition();
      final currentPoint = LatLng(current.latitude, current.longitude);
      final trip = await SupabaseService.instance.startTrip(
        startLat: route.route.points.first.latitude,
        startLng: route.route.points.first.longitude,
        endLat: route.route.points.last.latitude,
        endLng: route.route.points.last.longitude,
        destinationName: route.destinationName,
      );
      await SupabaseService.instance.sendLocationPing(
        tripId: trip['id'].toString(),
        lat: currentPoint.latitude,
        lng: currentPoint.longitude,
        speed: (current.speed * 3.6).clamp(0, 300).toDouble(),
      );
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Trip started. Guardian mode is now live.'),
          backgroundColor: Color(0xFF059669),
        ),
      );
      widget.onTripStarted?.call();
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

  List<Map<String, dynamic>> _hazardsNearRoute(
    List<LatLng> points,
    List<Map<String, dynamic>> hazards,
  ) {
    if (points.isEmpty) return const [];
    return hazards.where((hazard) {
      final lat = (hazard['lat'] as num?)?.toDouble();
      final lng = (hazard['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) return false;
      final hazardPoint = LatLng(lat, lng);
      return points.any(
        (point) =>
            _distance.as(LengthUnit.Meter, point, hazardPoint) <= 350,
      );
    }).toList(growable: false);
  }

  double _hazardPenalty(dynamic hazardType) {
    return switch (hazardType?.toString()) {
      'theft' => 14,
      'accident' => 12,
      'deadzone' => 10,
      'lighting' => 8,
      'pothole' => 6,
      _ => 5,
    };
  }

  _RouteOption _buildRouteOption(
    int index,
    _RouteDraft draft,
    String destinationName,
  ) {
    final bool recommended = index == 0;
    final Color routeColor = recommended
        ? const Color(0xFF10B981)
        : index == 1
            ? const Color(0xFFF59E0B)
            : const Color(0xFFEF4444);
    final Color buttonColor = recommended
        ? const Color(0xFF059669)
        : index == 1
            ? const Color(0xFF2563EB)
            : const Color(0xFF374151);

    final coverage = draft.score >= 78
        ? 'Full'
        : draft.score >= 55
            ? 'Partial'
            : 'Risk';

    return _RouteOption(
      route: draft.route,
      destinationName: destinationName,
      label: switch (index) {
        0 => 'Well-lit Streets',
        1 => 'Standard Path',
        _ => 'Direct Route',
      },
      subtitle: switch (index) {
        0 => 'Maximum safety priority',
        1 => 'Balanced route',
        _ => 'Fastest available option',
      },
      badge: recommended ? 'RECOMMENDED' : null,
      badgeColor: const Color(0xFF059669),
      rank: recommended ? '#1 SAFEST' : '#${index + 1}',
      coverage: coverage,
      score: draft.score,
      nearbyHazards: draft.nearbyHazards,
      highlights: _statusLines(draft.nearbyHazards),
      borderColor:
          recommended ? const Color(0xFF10B981) : const Color(0xFFE5E7EB),
      coverageColor: draft.score >= 78
          ? const Color(0xFF059669)
          : draft.score >= 55
              ? const Color(0xFF2563EB)
              : const Color(0xFFEF4444),
      routeColor: routeColor,
      btnColor: buttonColor,
      btnText: recommended ? 'Choose This Route' : 'Select Route',
    );
  }

  List<String> _statusLines(List<Map<String, dynamic>> hazards) {
    if (hazards.isEmpty) {
      return const [
        'No active hazards reported on route',
        'No signal dead zones reported',
        'Emergency tracking ready',
      ];
    }

    final grouped = <String, int>{};
    for (final hazard in hazards) {
      final type = hazard['hazard_type']?.toString() ?? 'hazard';
      grouped[type] = (grouped[type] ?? 0) + 1;
    }

    return grouped.entries
        .map((entry) => '${entry.value} ${_humanHazard(entry.key)} alert(s)')
        .toList(growable: false);
  }

  String _humanHazard(String type) {
    return switch (type) {
      'pothole' => 'pothole',
      'lighting' => 'lighting',
      'theft' => 'theft-risk',
      'accident' => 'accident',
      'deadzone' => 'deadzone',
      _ => type,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: CustomScrollView(
        slivers: [
          const SafeRouteAppBar(subtitle: 'Plan Journey'),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _Card(
                  child: Column(
                    children: [
                      _LocationField(
                        label: 'FROM',
                        controller: _fromCtrl,
                        icon: Icons.my_location_rounded,
                        enabled: false,
                        hint: _locating ? 'Detecting location...' : null,
                      ),
                      const SizedBox(height: 16),
                      _LocationField(
                        label: 'TO',
                        controller: _toCtrl,
                        icon: Icons.location_on_rounded,
                        hint: 'Enter destination',
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFFD1FAE5),
                              ),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.shield_rounded,
                                  size: 16,
                                  color: Color(0xFF059669),
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'SOS Detection ON',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF374151),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          OutlinedButton(
                            onPressed: null,
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                color: Color(0xFFE5E7EB),
                                width: 2,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              'Filters',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF9CA3AF),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _loading || _locating ? null : _findRoutes,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E293B),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _loading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Text(
                                  'Find Best Routes',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  _ErrorBanner(_error!),
                ],
                if (_routes != null) ...[
                  const SizedBox(height: 20),
                  ..._routes!.map(
                    (route) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _RouteCard(
                        route: route,
                        onTap: () => _startNavigation(route),
                      ),
                    ),
                  ),
                  if (_routes!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF6EE7B7),
                          width: 2,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF059669),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.check_circle_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${_routes!.first.label} Recommended',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF111827),
                                      ),
                                    ),
                                    Text(
                                      '${_routes!.first.route.distanceKm.toStringAsFixed(1)} km with ${_routes!.first.coverage.toLowerCase()} coverage.',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF374151),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: () => _startNavigation(_routes!.first),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1E293B),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Start Navigation',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_destination != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Destination resolved by Mapbox: ${_destination!.label}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF9CA3AF),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteDraft {
  final NavigationRoute route;
  final double score;
  final List<Map<String, dynamic>> nearbyHazards;

  const _RouteDraft({
    required this.route,
    required this.score,
    required this.nearbyHazards,
  });
}

class _RouteOption {
  final NavigationRoute route;
  final String destinationName;
  final String label;
  final String subtitle;
  final String rank;
  final String btnText;
  final String coverage;
  final String? badge;
  final Color badgeColor;
  final Color borderColor;
  final Color coverageColor;
  final Color routeColor;
  final Color btnColor;
  final double score;
  final List<String> highlights;
  final List<Map<String, dynamic>> nearbyHazards;

  const _RouteOption({
    required this.route,
    required this.destinationName,
    required this.label,
    required this.subtitle,
    required this.badge,
    required this.badgeColor,
    required this.rank,
    required this.coverage,
    required this.score,
    required this.highlights,
    required this.nearbyHazards,
    required this.borderColor,
    required this.coverageColor,
    required this.routeColor,
    required this.btnColor,
    required this.btnText,
  });
}

class _LocationField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;
  final bool enabled;
  final String? hint;

  const _LocationField({
    required this.label,
    required this.controller,
    required this.icon,
    this.enabled = true,
    this.hint,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6B7280),
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE5E7EB), width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(icon, color: const Color(0xFF475569), size: 20),
                ),
                Expanded(
                  child: TextField(
                    controller: controller,
                    enabled: enabled,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF111827),
                    ),
                    decoration: InputDecoration(
                      hintText: hint,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
}

class _RouteCard extends StatelessWidget {
  final _RouteOption route;
  final VoidCallback onTap;

  const _RouteCard({required this.route, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: route.borderColor,
          width: route.badge == 'RECOMMENDED' ? 3 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (route.badge != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: route.badgeColor.withOpacity(0.95),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(17),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    route.badge!,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      route.rank,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      route.label,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const Spacer(),
                    if (route.badge == null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          route.rank,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF374151),
                          ),
                        ),
                      ),
                  ],
                ),
                Text(
                  route.subtitle,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: route.routeColor.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: route.routeColor.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Duration',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: route.coverageColor,
                              ),
                            ),
                            Text(
                              '${route.route.durationMinutes.round()} min',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF111827),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Coverage',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: route.coverageColor,
                              ),
                            ),
                            Text(
                              route.coverage,
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: route.coverageColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: route.highlights
                        .map(
                          (line) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              '✓ $line',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF374151),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.analytics_rounded,
                        size: 16,
                        color: Color(0xFF6B7280),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Safety Score: ${route.score.toStringAsFixed(0)}/100 · ${route.route.distanceKm.toStringAsFixed(1)} km',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: onTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: route.btnColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      route.btnText,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
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

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: child,
      );
}

class _ErrorBanner extends StatelessWidget {
  final String msg;
  const _ErrorBanner(this.msg);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFFCA5A5)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.error_outline,
              color: Color(0xFFEF4444),
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(
                  color: Color(0xFFB91C1C),
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      );
}
