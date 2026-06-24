import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';

import '../services/bbmp_service.dart';
import '../services/mapbox_service.dart';
import '../services/navigation_session_service.dart';
import '../services/supabase_service.dart';
import '../widgets/saferoute_appbar.dart';

class TabSafetyScoreScreen extends StatefulWidget {
  final VoidCallback? onViewRoute;
  const TabSafetyScoreScreen({super.key, this.onViewRoute});

  @override
  State<TabSafetyScoreScreen> createState() => _TabSafetyScoreScreenState();
}

class _TabSafetyScoreScreenState extends State<TabSafetyScoreScreen>
    with SingleTickerProviderStateMixin {
  final _distance = const Distance();
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _activeTrip;
  Map<String, dynamic>? _latestAnalysis;
  List<Map<String, dynamic>> _routeHazards = const [];
  List<LatLng> _routePoints = const [];
  double _score = 0;
  late AnimationController _progressCtrl;
  late Animation<double> _progressAnim;

  @override
  void initState() {
    super.initState();
    _progressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _progressAnim = CurvedAnimation(
      parent: _progressCtrl,
      curve: Curves.easeOut,
    );
    _loadScore();
  }

  @override
  void dispose() {
    _progressCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadScore() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final trip = await SupabaseService.instance.getActiveTrip();
      final liveSnapshot = NavigationSessionService.instance.currentSnapshot;
      if (trip == null) {
        final latestAnalysis = await SupabaseService.instance
            .getLatestRouteAnalysis();
        if (liveSnapshot != null) {
          final hazards = await SupabaseService.instance.getActiveHazards();
          final nearRoute = _hazardsNearRoute(
            liveSnapshot.route.points,
            hazards,
          );
          final score =
              liveSnapshot.safetyScore ??
              await _fallbackLiveSessionScore(liveSnapshot, nearRoute);
          if (!mounted) return;
          setState(() {
            _activeTrip = null;
            _latestAnalysis = latestAnalysis;
            _routeHazards = nearRoute;
            _routePoints = liveSnapshot.route.points;
            _score = score;
            _loading = false;
          });
          _progressCtrl.forward(from: 0);
          return;
        }
        if (!mounted) return;
        setState(() {
          _activeTrip = null;
          _latestAnalysis = latestAnalysis;
          _routeHazards = const [];
          _routePoints = const [];
          _score = (latestAnalysis?['score'] as num?)?.toDouble() ?? 0;
          _loading = false;
        });
        _progressCtrl.forward(from: 0);
        return;
      }

      final start = LatLng(
        (trip['start_lat'] as num).toDouble(),
        (trip['start_lng'] as num).toDouble(),
      );
      final end = LatLng(
        (trip['end_lat'] as num).toDouble(),
        (trip['end_lng'] as num).toDouble(),
      );

      var points = <LatLng>[start, end];
      try {
        final routes = await MapboxService.instance.directions(
          start: start,
          end: end,
        );
        if (routes.isNotEmpty) points = routes.first.points;
      } catch (_) {
        // A direct start/end line still lets safety scoring continue.
      }

      final latestAnalysis = await SupabaseService.instance
          .getLatestRouteAnalysis(tripId: trip['id']?.toString());
      final hazards = await SupabaseService.instance.getActiveHazards();
      final nearRoute = _hazardsNearRoute(points, hazards);
      final score =
          (latestAnalysis?['score'] as num?)?.toDouble() ??
          await _fallbackScore(trip, nearRoute);

      if (!mounted) return;
      setState(() {
        _activeTrip = trip;
        _latestAnalysis = latestAnalysis;
        _routeHazards = nearRoute;
        _routePoints = points;
        _score = score;
        _loading = false;
      });
      _progressCtrl.forward(from: 0);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
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
                _distance.as(LengthUnit.Meter, point, hazardPoint) <= 350,
          );
        })
        .toList(growable: false);
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

  int _hazardCount(String type) {
    return _routeHazards
        .where((hazard) => hazard['hazard_type']?.toString() == type)
        .length;
  }

  String _statusText() {
    final liveSnapshot = NavigationSessionService.instance.currentSnapshot;
    if (_loading) return 'Loading route safety data...';
    if (_activeTrip == null && liveSnapshot != null) {
      if (_score >= 75)
        return 'Safer live route conditions toward ${liveSnapshot.destinationName}';
      if (_score >= 50) {
        return 'Moderate live route risk detected toward ${liveSnapshot.destinationName}';
      }
      return 'High live route risk detected toward ${liveSnapshot.destinationName}';
    }
    if (_activeTrip == null && _latestAnalysis == null) {
      return 'Start navigation to calculate route safety.';
    }
    if (_activeTrip == null) {
      return 'Latest recorded route score from your most recent SafeRoute analysis.';
    }
    final destination = _activeTrip!['destination_name']?.toString() ?? 'route';
    if (_score >= 75) return 'Safer route conditions toward $destination';
    if (_score >= 50) return 'Moderate risk detected toward $destination';
    return 'High-risk route conditions detected toward $destination';
  }

  String _forecastText() {
    final liveSnapshot = NavigationSessionService.instance.currentSnapshot;
    if (_activeTrip == null && liveSnapshot != null) {
      if (_routeHazards.isEmpty) {
        return 'Guest navigation is active with no nearby community hazards currently reported.';
      }
      final grouped = <String, int>{};
      for (final hazard in _routeHazards) {
        final type = hazard['hazard_type']?.toString() ?? 'hazard';
        grouped[type] = (grouped[type] ?? 0) + 1;
      }
      return grouped.entries
          .map((entry) => '${entry.value} ${entry.key} alert(s)')
          .join(', ');
    }
    if (_activeTrip == null && _latestAnalysis != null) {
      final hazardTypes =
          (_latestAnalysis!['hazard_types'] as List<dynamic>? ?? const [])
              .map((entry) => entry.toString())
              .toList(growable: false);
      if (hazardTypes.isEmpty) {
        return 'Most recent saved route had no hazard categories recorded.';
      }
      return 'Latest saved route hazards: ${hazardTypes.join(', ')}.';
    }
    if (_activeTrip == null)
      return 'No active route is currently being tracked.';
    if (_routeHazards.isEmpty) {
      return 'No active community hazards are currently reported along this route.';
    }
    final grouped = <String, int>{};
    for (final hazard in _routeHazards) {
      final type = hazard['hazard_type']?.toString() ?? 'hazard';
      grouped[type] = (grouped[type] ?? 0) + 1;
    }
    return grouped.entries
        .map((entry) => '${entry.value} ${entry.key} alert(s)')
        .join(', ');
  }

  String _recommendationText() {
    final liveSnapshot = NavigationSessionService.instance.currentSnapshot;
    if (_activeTrip == null && liveSnapshot != null) {
      if (_score >= 75)
        return 'Guest navigation is active. Keep guardian tracking open while you travel.';
      if (_score >= 50) {
        return 'Stay on the selected route and keep guardian tracking open for safer travel.';
      }
      return 'Consider switching routes before moving, or share your trip with a guardian after sign-in.';
    }
    if (_activeTrip == null && _latestAnalysis != null) {
      return 'Plan another trip to refresh live analysis, or review your saved route context.';
    }
    if (_activeTrip == null)
      return 'Plan a route first, then review live risk.';
    if (_score >= 75) return 'Continue with guardian tracking enabled.';
    if (_score >= 50) {
      return 'Use guardian tracking and stay on the recommended route.';
    }
    return 'Pick another route or share your live trip before moving.';
  }

  Future<void> _shareRoute() async {
    final trip = _activeTrip;
    final destination =
        trip?['destination_name']?.toString() ??
        _latestAnalysis?['destination_name']?.toString() ??
        'destination';
    await Share.share(
      'SafeRoute trip to $destination. Safety score: ${_score.toStringAsFixed(0)}/100.',
      subject: 'SafeRoute Trip',
    );
  }

  Future<double> _fallbackScore(
    Map<String, dynamic> trip,
    List<Map<String, dynamic>> nearRoute,
  ) async {
    final destinationName =
        trip['destination_name']?.toString() ?? 'Active Route';
    final baseScore = await BbmpService.instance.routeSafetyScoreCached(
      destinationName,
      destinationName,
    );
    final penalty = nearRoute.fold<double>(
      0,
      (sum, hazard) => sum + _hazardPenalty(hazard['hazard_type']),
    );
    return (baseScore - penalty).clamp(0, 100).toDouble();
  }

  Future<double> _fallbackLiveSessionScore(
    NavigationSessionSnapshot snapshot,
    List<Map<String, dynamic>> nearRoute,
  ) async {
    final destinationName = snapshot.destinationName;
    final baseScore =
        snapshot.baseScore ??
        await BbmpService.instance.routeSafetyScoreCached(
          destinationName,
          destinationName,
        );
    final penalty = nearRoute.fold<double>(
      snapshot.hazardPenalty ?? 0,
      (sum, hazard) => sum + _hazardPenalty(hazard['hazard_type']),
    );
    return (baseScore - penalty).clamp(0, 100).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final liveSnapshot = NavigationSessionService.instance.currentSnapshot;
    final potholes = _hazardCount('pothole');
    final lighting = _hazardCount('lighting');
    final theft = _hazardCount('theft');
    final scoreColor = _score >= 70
        ? const Color(0xFF10B981)
        : _score >= 50
        ? const Color(0xFFF59E0B)
        : const Color(0xFFEF4444);
    final area =
        _activeTrip?['destination_name']?.toString() ??
        liveSnapshot?.destinationName ??
        _latestAnalysis?['destination_name']?.toString() ??
        'No Route';
    final wardContext = _latestAnalysis?['ward_name']?.toString();
    final streetSummary = _latestAnalysis?['street_summary']?.toString();

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: RefreshIndicator(
        onRefresh: _loadScore,
        color: const Color(0xFF1E293B),
        child: CustomScrollView(
          slivers: [
            const SafeRouteAppBar(subtitle: 'Safety Score'),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (_error != null) ...[
                    _AlertCard(
                      bgColor: const Color(0xFFFEF2F2),
                      borderColor: const Color(0xFFFCA5A5),
                      iconBg: const Color(0xFFFEE2E2),
                      iconColor: const Color(0xFFEF4444),
                      icon: Icons.error_outline_rounded,
                      title: 'Safety Data Error',
                      body: _error!,
                    ),
                    const SizedBox(height: 16),
                  ],
                  Container(
                    padding: const EdgeInsets.all(28),
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
                      children: [
                        const Text(
                          'ROUTE SAFETY SCORE',
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFF6B7280),
                            letterSpacing: 2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: 140,
                          height: 140,
                          child: AnimatedBuilder(
                            animation: _progressAnim,
                            builder: (_, __) => Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox(
                                  width: 140,
                                  height: 140,
                                  child: CircularProgressIndicator(
                                    value: _progressAnim.value * (_score / 100),
                                    strokeWidth: 10,
                                    backgroundColor: const Color(0xFFE5E7EB),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      scoreColor,
                                    ),
                                    strokeCap: StrokeCap.round,
                                  ),
                                ),
                                _loading
                                    ? const SizedBox(
                                        width: 28,
                                        height: 28,
                                        child: CircularProgressIndicator(
                                          color: Color(0xFF1E293B),
                                          strokeWidth: 3,
                                        ),
                                      )
                                    : Text(
                                        _score.toStringAsFixed(0),
                                        style: TextStyle(
                                          fontSize: 48,
                                          fontWeight: FontWeight.w800,
                                          color: scoreColor,
                                        ),
                                      ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _statusText(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF374151),
                            fontWeight: FontWeight.w500,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _MetaItem(label: 'Updated', value: 'Live'),
                              _vDivider(),
                              _MetaItem(
                                label: 'Area',
                                value: area.length > 12
                                    ? '${area.substring(0, 12)}...'
                                    : area,
                              ),
                              _vDivider(),
                              _MetaItem(label: 'Scope', value: 'Route'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'COVERAGE STATUS',
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFF6B7280),
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Route Indexed',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF374151),
                                ),
                              ),
                            ),
                            Text(
                              '${_score.toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: scoreColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        AnimatedBuilder(
                          animation: _progressAnim,
                          builder: (_, __) => ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: _progressAnim.value * (_score / 100),
                              minHeight: 10,
                              backgroundColor: const Color(0xFFE5E7EB),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                scoreColor,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _MetricCard(
                          icon: Icons.warning_amber_rounded,
                          iconBg: const Color(0xFFFFF7ED),
                          iconColor: const Color(0xFFEA580C),
                          label: 'Potholes',
                          value: potholes.toString(),
                          progress: (potholes / 10).clamp(0, 1).toDouble(),
                          barColor: const Color(0xFFF97316),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MetricCard(
                          icon: Icons.bolt_rounded,
                          iconBg: const Color(0xFFFFFBEB),
                          iconColor: const Color(0xFFD97706),
                          label: 'Lights',
                          value: lighting.toString(),
                          progress: (lighting / 10).clamp(0, 1).toDouble(),
                          barColor: const Color(0xFFF59E0B),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MetricCard(
                          icon: Icons.shield_rounded,
                          iconBg: const Color(0xFFFFF1F2),
                          iconColor: const Color(0xFFE11D48),
                          label: 'Theft',
                          value: theft.toString(),
                          progress: (theft / 10).clamp(0, 1).toDouble(),
                          barColor: const Color(0xFFEF4444),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _AlertCard(
                    bgColor: const Color(0xFFFFFBEB),
                    borderColor: const Color(0xFFFCD34D),
                    iconBg: const Color(0xFFFEF3C7),
                    iconColor: const Color(0xFFB45309),
                    icon: Icons.warning_amber_rounded,
                    title: 'Route Forecast',
                    body: _forecastText(),
                  ),
                  const SizedBox(height: 12),
                  _AlertCard(
                    bgColor: const Color(0xFFEFF6FF),
                    borderColor: const Color(0xFFBFDBFE),
                    iconBg: const Color(0xFFDBEAFE),
                    iconColor: const Color(0xFF2563EB),
                    icon: Icons.info_outline_rounded,
                    title: 'Recommendation',
                    body: _recommendationText(),
                  ),
                  if (wardContext != null || streetSummary != null) ...[
                    const SizedBox(height: 12),
                    _AlertCard(
                      bgColor: const Color(0xFFF0FDF4),
                      borderColor: const Color(0xFFBBF7D0),
                      iconBg: const Color(0xFFDCFCE7),
                      iconColor: const Color(0xFF15803D),
                      icon: Icons.map_rounded,
                      title: 'Bengaluru Context',
                      body:
                          '${wardContext ?? 'Ward context unavailable'}${streetSummary == null || streetSummary.isEmpty ? '' : ' · Streets: $streetSummary'}',
                    ),
                  ],
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
                          'Route Visualization',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          height: 160,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: CustomPaint(
                            painter: _RoutePainter(
                              color: const Color(0xFF10B981),
                              points: _routePoints,
                            ),
                            child: const SizedBox.expand(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 46,
                                child: ElevatedButton(
                                  onPressed: _activeTrip == null
                                      ? null
                                      : widget.onViewRoute,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1E293B),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text(
                                    'View Route',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: SizedBox(
                                height: 46,
                                child: OutlinedButton(
                                  onPressed: _activeTrip == null
                                      ? null
                                      : _shareRoute,
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(
                                      color: Color(0xFFD1D5DB),
                                      width: 2,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text(
                                    'Share',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF374151),
                                    ),
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
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'LIVE ROUTE DATA',
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFF6B7280),
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _StatsRow(
                          'Potholes Reported',
                          potholes.toString(),
                          const Color(0xFF2563EB),
                        ),
                        const SizedBox(height: 10),
                        _StatsRow(
                          'Lighting Issues',
                          lighting.toString(),
                          const Color(0xFF111827),
                        ),
                        const SizedBox(height: 10),
                        _StatsRow(
                          'Theft Incidents',
                          theft.toString(),
                          const Color(0xFF111827),
                        ),
                      ],
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _vDivider() =>
    Container(height: 30, width: 1, color: const Color(0xFFE5E7EB));

Widget _StatsRow(String label, String value, Color valueColor) => Row(
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
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: valueColor,
      ),
    ),
  ],
);

class _MetaItem extends StatelessWidget {
  final String label;
  final String value;
  const _MetaItem({required this.label, required this.value});

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
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Color(0xFF111827),
        ),
      ),
    ],
  );
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final Color barColor;
  final String label;
  final String value;
  final double progress;

  const _MetricCard({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.progress,
    required this.barColor,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFE5E7EB)),
      boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6),
      ],
    ),
    child: Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Color(0xFF6B7280),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: const Color(0xFFE5E7EB),
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
          ),
        ),
      ],
    ),
  );
}

class _AlertCard extends StatelessWidget {
  final Color bgColor;
  final Color borderColor;
  final Color iconBg;
  final Color iconColor;
  final IconData icon;
  final String title;
  final String body;

  const _AlertCard({
    required this.bgColor,
    required this.borderColor,
    required this.iconBg,
    required this.iconColor,
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: borderColor, width: 2),
    ),
    child: Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                body,
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

class _RoutePainter extends CustomPainter {
  final Color color;
  final List<LatLng> points;
  const _RoutePainter({required this.color, required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final minLat = points
        .map((p) => p.latitude)
        .reduce((a, b) => a < b ? a : b);
    final maxLat = points
        .map((p) => p.latitude)
        .reduce((a, b) => a > b ? a : b);
    final minLng = points
        .map((p) => p.longitude)
        .reduce((a, b) => a < b ? a : b);
    final maxLng = points
        .map((p) => p.longitude)
        .reduce((a, b) => a > b ? a : b);

    final latSpan = (maxLat - minLat).abs() < 0.00001
        ? 0.00001
        : maxLat - minLat;
    final lngSpan = (maxLng - minLng).abs() < 0.00001
        ? 0.00001
        : maxLng - minLng;
    const padding = 18.0;

    Offset project(LatLng point) {
      final x =
          padding +
          ((point.longitude - minLng) / lngSpan) * (size.width - padding * 2);
      final y =
          padding +
          ((maxLat - point.latitude) / latSpan) * (size.height - padding * 2);
      return Offset(x, y);
    }

    final path = ui.Path()
      ..moveTo(project(points.first).dx, project(points.first).dy);
    for (final point in points.skip(1)) {
      final offset = project(point);
      path.lineTo(offset.dx, offset.dy);
    }

    final glowPaint = Paint()
      ..color = color.withOpacity(0.3)
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, paint);

    for (final point in [points.first, points.last]) {
      final offset = project(point);
      canvas.drawCircle(offset, 6, Paint()..color = color);
      canvas.drawCircle(
        offset,
        6,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RoutePainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.color != color;
  }
}
