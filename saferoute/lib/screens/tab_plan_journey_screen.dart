import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/location_service.dart';
import '../services/mapbox_service.dart';
import '../services/navigation_session_service.dart';
import '../services/safety_data_service.dart';
import '../services/supabase_service.dart';
import '../widgets/saferoute_appbar.dart';

class RouteOptionData {
  final NavigationRoute route;
  final String destinationName;
  final String label;
  final String subtitle;
  final String rank;
  final String coverage;
  final double score;
  final double baseScore;
  final double hazardPenalty;
  final List<String> highlights;
  final List<Map<String, dynamic>> nearbyHazards;
  final String? wardName;
  final String? streetSummary;
  final bool isRecommended;

  const RouteOptionData({
    required this.route,
    required this.destinationName,
    required this.label,
    required this.subtitle,
    required this.rank,
    required this.coverage,
    required this.score,
    required this.baseScore,
    required this.hazardPenalty,
    required this.highlights,
    required this.nearbyHazards,
    this.wardName,
    this.streetSummary,
    this.isRecommended = false,
  });
}

class TripStartPayload {
  final String routeId;
  final String destinationName;
  final LatLng start;
  final LatLng end;

  const TripStartPayload({
    required this.routeId,
    required this.destinationName,
    required this.start,
    required this.end,
  });
}

String? defaultSelectedRouteId(List<RouteOptionData> routes) {
  if (routes.isEmpty) return null;
  return routes.first.route.id;
}

String? selectRouteId(
  List<RouteOptionData> routes, {
  required String? currentRouteId,
  required String nextRouteId,
}) {
  final exists = routes.any((route) => route.route.id == nextRouteId);
  return exists ? nextRouteId : currentRouteId;
}

String? selectRouteIdFromMapHit(
  List<RouteOptionData> routes, {
  required String? currentRouteId,
  required List<String> hitRouteIds,
}) {
  for (final routeId in hitRouteIds) {
    final selected = selectRouteId(
      routes,
      currentRouteId: currentRouteId,
      nextRouteId: routeId,
    );
    if (selected != currentRouteId) return selected;
  }
  return currentRouteId;
}

TripStartPayload buildTripStartPayload(RouteOptionData route) {
  return TripStartPayload(
    routeId: route.route.id,
    destinationName: route.destinationName,
    start: route.route.points.first,
    end: route.route.points.last,
  );
}

List<NavigationStep> previewNavigationSteps(
  NavigationRoute route, {
  int limit = 4,
}) {
  if (limit <= 0) return const [];
  return route.steps.take(limit).toList(growable: false);
}

class TabPlanJourneyScreen extends StatefulWidget {
  final VoidCallback? onTripStarted;

  const TabPlanJourneyScreen({super.key, this.onTripStarted});

  @override
  State<TabPlanJourneyScreen> createState() => _TabPlanJourneyScreenState();
}

class _TabPlanJourneyScreenState extends State<TabPlanJourneyScreen> {
  final _fromCtrl = TextEditingController(text: 'Current Location');
  final _toCtrl = TextEditingController();
  final _mapCtrl = MapController();
  final LayerHitNotifier<String> _routeHitNotifier = ValueNotifier(null);
  final _navigationMapCtrl = MapController();

  bool _loading = false;
  bool _locating = true;
  List<RouteOptionData>? _routes;
  String? _selectedRouteId;
  LatLng? _startPoint;
  MapboxPlace? _destination;
  String? _error;
  StreamSubscription<dynamic>? _positionSub;
  bool _rerouteInFlight = false;

  @override
  void initState() {
    super.initState();
    _routeHitNotifier.addListener(_handleRouteMapHit);
    _loadCurrentLocation();
  }

  @override
  void dispose() {
    _routeHitNotifier
      ..removeListener(_handleRouteMapHit)
      ..dispose();
    _positionSub?.cancel();
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
        // Reverse geocoding enriches the UI but isn't required for routing.
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
      _selectedRouteId = null;
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
      final bundles = await SafetyDataService.instance.rankRoutes(
        routes: navRoutes.take(3).toList(growable: false),
        originLabel: _fromCtrl.text,
        destinationLabel: destination.label,
        activeHazards: activeHazards,
      );

      final options = bundles
          .asMap()
          .entries
          .map(
            (entry) =>
                _buildRouteOption(entry.key, entry.value, destination.label),
          )
          .toList(growable: false);

      if (!mounted) return;
      setState(() {
        _startPoint = start;
        _destination = destination;
        _routes = options;
        _selectedRouteId = defaultSelectedRouteId(options);
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

  RouteOptionData? get _selectedRoute {
    final routes = _routes;
    if (routes == null || routes.isEmpty) return null;
    final selectedId = _selectedRouteId;
    if (selectedId == null) return routes.first;
    for (final route in routes) {
      if (route.route.id == selectedId) return route;
    }
    return routes.first;
  }

  void _selectRoute(String routeId) {
    final routes = _routes;
    if (routes == null) return;
    setState(() {
      _selectedRouteId = selectRouteId(
        routes,
        currentRouteId: _selectedRouteId,
        nextRouteId: routeId,
      );
    });
  }

  void _handleRouteMapHit() {
    final hitResult = _routeHitNotifier.value;
    final routes = _routes;
    if (hitResult == null || routes == null || hitResult.hitValues.isEmpty) {
      return;
    }
    final selected = selectRouteIdFromMapHit(
      routes,
      currentRouteId: _selectedRouteId,
      hitRouteIds: hitResult.hitValues,
    );
    if (selected == null || selected == _selectedRouteId) return;
    setState(() {
      _selectedRouteId = selected;
    });
  }

  Future<void> _startNavigation(RouteOptionData route) async {
    if (route.route.points.length < 2) {
      setState(() => _error = 'Selected route is missing map geometry.');
      return;
    }

    setState(() => _loading = true);
    try {
      final payload = buildTripStartPayload(route);
      final current = await LocationService.currentPosition();
      final currentPoint = LatLng(current.latitude, current.longitude);
      NavigationSessionService.instance.activateRoute(
        route.route,
        initialLocation: currentPoint,
      );
      final trip = await SupabaseService.instance.startTrip(
        startLat: payload.start.latitude,
        startLng: payload.start.longitude,
        endLat: payload.end.latitude,
        endLng: payload.end.longitude,
        destinationName: payload.destinationName,
      );
      await SafetyDataService.instance.saveAnalysisSnapshot(
        routeId: route.route.id,
        destinationName: route.destinationName,
        tripId: trip['id'].toString(),
        score: route.score,
        baseScore: route.baseScore,
        hazardPenalty: route.hazardPenalty,
        coverage: route.coverage,
        highlights: route.highlights,
        hazards: route.nearbyHazards,
        wardName: route.wardName,
        streetSummary: route.streetSummary,
      );
      await SupabaseService.instance.sendLocationPing(
        tripId: trip['id'].toString(),
        lat: currentPoint.latitude,
        lng: currentPoint.longitude,
        speed: (current.speed * 3.6).clamp(0, 300).toDouble(),
      );
      _startLiveNavigationTracking();
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Trip started on ${route.label}. Guardian mode is now live.',
          ),
          backgroundColor: const Color(0xFF059669),
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

  void _startLiveNavigationTracking() {
    _positionSub?.cancel();
    _positionSub = LocationService.positionStream().listen((position) {
      final point = LatLng(position.latitude, position.longitude);
      NavigationSessionService.instance.updateWithLocation(point);
      if (NavigationSessionService.instance.shouldRequestReroute) {
        unawaited(_attemptLiveReroute(point));
      }
      try {
        _navigationMapCtrl.move(point, 15);
      } catch (_) {}
    });
  }

  Future<void> _attemptLiveReroute(LatLng currentLocation) async {
    if (_rerouteInFlight) return;
    final liveSession = NavigationSessionService.instance;
    final snapshot = liveSession.currentSnapshot;
    if (snapshot == null || !liveSession.shouldRequestReroute) return;

    _rerouteInFlight = true;
    liveSession.markRerouting();

    try {
      final rerouteCandidates = await MapboxService.instance.directions(
        start: currentLocation,
        end: snapshot.route.points.last,
      );
      final activeHazards = await SupabaseService.instance.getActiveHazards();
      final destinationName = _destination?.label.isNotEmpty == true
          ? _destination!.label
          : (_toCtrl.text.trim().isEmpty ? 'Destination' : _toCtrl.text.trim());
      final rankedBundles = await SafetyDataService.instance.rankRoutes(
        routes: rerouteCandidates.take(3).toList(growable: false),
        originLabel: _fromCtrl.text,
        destinationLabel: destinationName,
        activeHazards: activeHazards,
      );
      if (rankedBundles.isEmpty) {
        throw StateError('Mapbox did not return a usable reroute.');
      }

      final reroutedOptions = rankedBundles
          .asMap()
          .entries
          .map(
            (entry) =>
                _buildRouteOption(entry.key, entry.value, destinationName),
          )
          .toList(growable: false);
      final reroutedSelection = reroutedOptions.first;

      liveSession.applyReroute(
        reroutedSelection.route,
        currentLocation: currentLocation,
      );
      if (!mounted) return;
      setState(() {
        _startPoint = currentLocation;
        _routes = reroutedOptions;
        _selectedRouteId = reroutedSelection.route.id;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Route updated from your current location.'),
          backgroundColor: Color(0xFF1D4ED8),
        ),
      );
    } catch (error) {
      liveSession.cancelRerouting();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reroute failed: $error'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    } finally {
      _rerouteInFlight = false;
    }
  }

  Future<void> _endLiveTrip() async {
    final trip = await SupabaseService.instance.getActiveTrip();
    if (trip == null) {
      NavigationSessionService.instance.clear();
      return;
    }
    await SupabaseService.instance.endTrip(trip['id'].toString());
    _positionSub?.cancel();
    NavigationSessionService.instance.clear();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Trip ended. Live navigation has stopped.'),
        backgroundColor: Color(0xFF1E293B),
      ),
    );
    setState(() {});
  }

  RouteOptionData _buildRouteOption(
    int index,
    RouteSafetyBundle bundle,
    String destinationName,
  ) {
    final analysis = bundle.ranking;
    final isRecommended = index == 0;
    return RouteOptionData(
      route: bundle.navigationRoute,
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
      rank: isRecommended ? '#1 SAFEST' : '#${index + 1}',
      coverage: analysis.coverage,
      score: analysis.score,
      baseScore: (analysis.score + analysis.penalty).clamp(0, 100).toDouble(),
      hazardPenalty: analysis.penalty,
      highlights: analysis.reasons,
      nearbyHazards: bundle.nearbyHazards,
      wardName: analysis.wardContext,
      streetSummary: analysis.streetContext,
      isRecommended: isRecommended,
    );
  }

  Color _routeColorFor(RouteOptionData route) {
    if (route.score >= 78) return const Color(0xFF10B981);
    if (route.score >= 60) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  Color _coverageColorFor(RouteOptionData route) {
    if (route.score >= 78) return const Color(0xFF059669);
    if (route.score >= 55) return const Color(0xFF2563EB);
    return const Color(0xFFEF4444);
  }

  CameraFit? _cameraFitFor(List<RouteOptionData> routes) {
    final points = <LatLng>[];
    for (final route in routes) {
      points.addAll(route.route.points);
    }
    if (points.isEmpty) return null;
    return CameraFit.bounds(
      bounds: LatLngBounds.fromPoints(points),
      padding: const EdgeInsets.all(36),
      maxZoom: 15,
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedRoute = _selectedRoute;
    final liveSession = NavigationSessionService.instance.notifier;
    final isNavigationActive = liveSession.value != null;
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: CustomScrollView(
        slivers: [
          const SafeRouteAppBar(subtitle: 'Plan Journey'),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                ValueListenableBuilder<NavigationSessionSnapshot?>(
                  valueListenable: liveSession,
                  builder: (context, snapshot, _) {
                    if (snapshot == null) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _LiveNavigationPanel(
                        mapController: _navigationMapCtrl,
                        snapshot: snapshot,
                        onEndTrip: _endLiveTrip,
                      ),
                    );
                  },
                ),
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
                  _RouteChooserMap(
                    key: const Key('route-chooser-map'),
                    mapController: _mapCtrl,
                    routes: _routes!,
                    selectedRouteId: _selectedRouteId,
                    startPoint: _startPoint,
                    destinationPoint: _destination?.point,
                    cameraFit: _cameraFitFor(_routes!),
                    routeColorFor: _routeColorFor,
                    onSelectRoute: _selectRoute,
                    routeHitNotifier: _routeHitNotifier,
                  ),
                  const SizedBox(height: 16),
                  _SelectedRouteSummary(
                    key: const Key('selected-route-summary'),
                    route: selectedRoute,
                    routeColor: selectedRoute == null
                        ? const Color(0xFF10B981)
                        : _routeColorFor(selectedRoute),
                    coverageColor: selectedRoute == null
                        ? const Color(0xFF059669)
                        : _coverageColorFor(selectedRoute),
                    onStartNavigation: selectedRoute == null
                        ? null
                        : isNavigationActive
                        ? null
                        : () => _startNavigation(selectedRoute),
                  ),
                  const SizedBox(height: 16),
                  ..._routes!.map(
                    (route) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _RouteCard(
                        route: route,
                        isSelected: route.route.id == _selectedRouteId,
                        routeColor: _routeColorFor(route),
                        coverageColor: _coverageColorFor(route),
                        onSelect: () => _selectRoute(route.route.id),
                      ),
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

class _RouteChooserMap extends StatelessWidget {
  final MapController mapController;
  final List<RouteOptionData> routes;
  final String? selectedRouteId;
  final LatLng? startPoint;
  final LatLng? destinationPoint;
  final CameraFit? cameraFit;
  final ValueChanged<String> onSelectRoute;
  final Color Function(RouteOptionData route) routeColorFor;
  final LayerHitNotifier<String> routeHitNotifier;

  const _RouteChooserMap({
    super.key,
    required this.mapController,
    required this.routes,
    required this.selectedRouteId,
    required this.startPoint,
    required this.destinationPoint,
    required this.cameraFit,
    required this.onSelectRoute,
    required this.routeColorFor,
    required this.routeHitNotifier,
  });

  @override
  Widget build(BuildContext context) {
    final fallbackCenter =
        startPoint ??
        destinationPoint ??
        (routes.isNotEmpty && routes.first.route.points.isNotEmpty
            ? routes.first.route.points.first
            : const LatLng(12.9716, 77.5946));

    return Container(
      height: 260,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: FlutterMap(
          mapController: mapController,
          options: MapOptions(
            initialCenter: fallbackCenter,
            initialZoom: 12.5,
            initialCameraFit: cameraFit,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.saferoute.app',
            ),
            PolylineLayer<String>(
              hitNotifier: routeHitNotifier,
              minimumHitbox: 16,
              polylines: routes
                  .map((route) {
                    final isSelected = route.route.id == selectedRouteId;
                    return Polyline<String>(
                      points: route.route.points,
                      color: routeColorFor(
                        route,
                      ).withValues(alpha: isSelected ? 0.95 : 0.35),
                      strokeWidth: isSelected ? 6 : 4,
                      hitValue: route.route.id,
                    );
                  })
                  .toList(growable: false),
            ),
            MarkerLayer(
              markers: [
                if (startPoint != null)
                  Marker(
                    point: startPoint!,
                    width: 40,
                    height: 40,
                    child: const _MapPin(
                      color: Color(0xFF2563EB),
                      icon: Icons.trip_origin_rounded,
                    ),
                  ),
                if (destinationPoint != null)
                  Marker(
                    point: destinationPoint!,
                    width: 44,
                    height: 44,
                    child: const _MapPin(
                      color: Color(0xFFEF4444),
                      icon: Icons.location_on_rounded,
                    ),
                  ),
              ],
            ),
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: routes
                    .map((route) {
                      final isSelected = route.route.id == selectedRouteId;
                      final color = routeColorFor(route);
                      return GestureDetector(
                        onTap: () => onSelectRoute(route.route.id),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? color
                                  : const Color(0xFFE5E7EB),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${route.label} ${route.score.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF111827),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    })
                    .toList(growable: false),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveNavigationPanel extends StatelessWidget {
  final MapController mapController;
  final NavigationSessionSnapshot snapshot;
  final Future<void> Function() onEndTrip;

  const _LiveNavigationPanel({
    required this.mapController,
    required this.snapshot,
    required this.onEndTrip,
  });

  @override
  Widget build(BuildContext context) {
    final route = snapshot.route;
    final currentLocation = snapshot.currentLocation;
    final currentInstruction = route.steps.isEmpty
        ? 'Continue on the route'
        : route.steps[snapshot.state.currentStepIndex].instruction;
    final nextIndex = snapshot.state.currentStepIndex + 1;
    final nextInstruction = nextIndex < route.steps.length
        ? route.steps[nextIndex].instruction
        : null;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: snapshot.state.hasArrived
                      ? const Color(0xFF14532D)
                      : snapshot.isEmergencyActive
                      ? const Color(0xFF991B1B)
                      : snapshot.isRerouting
                      ? const Color(0xFF4338CA)
                      : snapshot.state.isOffRoute
                      ? const Color(0xFF7C2D12)
                      : const Color(0xFF1D4ED8),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  snapshot.state.hasArrived
                      ? 'ARRIVED'
                      : snapshot.isEmergencyActive
                      ? 'SOS ACTIVE'
                      : snapshot.isRerouting
                      ? 'REROUTING'
                      : snapshot.state.isOffRoute
                      ? 'OFF ROUTE'
                      : 'LIVE NAVIGATION',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: onEndTrip,
                child: const Text(
                  'End Trip',
                  style: TextStyle(
                    color: Color(0xFFFCA5A5),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            snapshot.isRerouting
                ? 'Finding a safer route from your current location...'
                : currentInstruction,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          if (!snapshot.isRerouting && nextInstruction != null) ...[
            const SizedBox(height: 6),
            Text(
              'Next: $nextInstruction',
              style: const TextStyle(fontSize: 13, color: Color(0xFFCBD5E1)),
            ),
          ],
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              height: 240,
              child: FlutterMap(
                mapController: mapController,
                options: MapOptions(
                  initialCenter: currentLocation,
                  initialZoom: 15,
                  initialCameraFit: CameraFit.bounds(
                    bounds: LatLngBounds.fromPoints(route.points),
                    padding: const EdgeInsets.all(32),
                    maxZoom: 16,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.saferoute.app',
                  ),
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: route.points,
                        color: snapshot.isEmergencyActive
                            ? const Color(0xFFEF4444)
                            : snapshot.state.isOffRoute
                            ? const Color(0xFFF97316)
                            : const Color(0xFF38BDF8),
                        strokeWidth: 6,
                      ),
                    ],
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: currentLocation,
                        width: 46,
                        height: 46,
                        child: const _MapPin(
                          color: Color(0xFF10B981),
                          icon: Icons.navigation_rounded,
                        ),
                      ),
                      Marker(
                        point: route.points.last,
                        width: 42,
                        height: 42,
                        child: const _MapPin(
                          color: Color(0xFFEF4444),
                          icon: Icons.flag_rounded,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          LinearProgressIndicator(
            value: snapshot.state.progressFraction,
            minHeight: 10,
            borderRadius: BorderRadius.circular(999),
            backgroundColor: const Color(0xFF334155),
            color: snapshot.state.hasArrived
                ? const Color(0xFF22C55E)
                : snapshot.isEmergencyActive
                ? const Color(0xFFEF4444)
                : snapshot.isRerouting
                ? const Color(0xFF818CF8)
                : snapshot.state.isOffRoute
                ? const Color(0xFFF97316)
                : const Color(0xFF38BDF8),
          ),
        ],
      ),
    );
  }
}

class _SelectedRouteSummary extends StatelessWidget {
  final RouteOptionData? route;
  final Color routeColor;
  final Color coverageColor;
  final VoidCallback? onStartNavigation;

  const _SelectedRouteSummary({
    super.key,
    required this.route,
    required this.routeColor,
    required this.coverageColor,
    required this.onStartNavigation,
  });

  @override
  Widget build(BuildContext context) {
    final route = this.route;
    if (route == null) return const SizedBox.shrink();
    final previewSteps = previewNavigationSteps(route.route);
    final liveSnapshot = NavigationSessionService.instance.currentSnapshot;
    final isActiveRoute = liveSnapshot?.route.id == route.route.id;
    final currentInstruction = isActiveRoute
        ? NavigationSessionService.instance.currentInstruction
        : null;
    final nextInstruction = isActiveRoute
        ? NavigationSessionService.instance.nextInstruction
        : null;
    final liveProgress = isActiveRoute
        ? liveSnapshot?.state.progressFraction
        : null;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: routeColor, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: routeColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.alt_route_rounded, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Selected Route',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6B7280),
                        letterSpacing: 0.6,
                      ),
                    ),
                    Text(
                      route.label,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: routeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${route.score.toStringAsFixed(0)}/100',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: routeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _SummaryStat(
                  label: 'ETA',
                  value: '${route.route.durationMinutes.round()} min',
                ),
              ),
              Expanded(
                child: _SummaryStat(
                  label: 'Distance',
                  value: '${route.route.distanceKm.toStringAsFixed(1)} km',
                ),
              ),
              Expanded(
                child: _SummaryStat(
                  label: 'Hazards',
                  value: route.nearbyHazards.length.toString(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Coverage: ${route.coverage} · Base ${route.baseScore.toStringAsFixed(0)} · Penalty ${route.hazardPenalty.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: coverageColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            route.highlights.join(' • '),
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF374151),
              height: 1.5,
            ),
          ),
          if (isActiveRoute && currentInstruction != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: liveSnapshot?.isRerouting == true
                    ? const Color(0xFFEEF2FF)
                    : const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: liveSnapshot?.isRerouting == true
                      ? const Color(0xFFC7D2FE)
                      : const Color(0xFFBBF7D0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    liveSnapshot?.isRerouting == true
                        ? 'Live Navigation · Rerouting'
                        : 'Live Navigation',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: liveSnapshot?.isRerouting == true
                          ? const Color(0xFF4338CA)
                          : const Color(0xFF15803D),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    liveSnapshot?.isRerouting == true
                        ? 'Now: Recalculating the safest path from where you are.'
                        : 'Now: $currentInstruction',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                  ),
                  if (liveSnapshot?.isRerouting != true && nextInstruction != null)
                    Text(
                      'Next: $nextInstruction',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF166534),
                      ),
                    ),
                  if (liveProgress != null) ...[
                    const SizedBox(height: 10),
                    LinearProgressIndicator(
                      value: liveProgress,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(999),
                      backgroundColor: const Color(0xFFDCFCE7),
                      color: routeColor,
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Next Steps',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 10),
                if (previewSteps.isEmpty)
                  const Text(
                    'Detailed turn-by-turn guidance will appear here when route steps are available.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF475569),
                      height: 1.5,
                    ),
                  )
                else
                  ...previewSteps.asMap().entries.map(
                    (entry) => Padding(
                      padding: EdgeInsets.only(
                        bottom: entry.key == previewSteps.length - 1 ? 0 : 10,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: routeColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${entry.key + 1}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: routeColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.value.instruction,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF111827),
                                    height: 1.4,
                                  ),
                                ),
                                if (entry.value.distanceMeters > 0 ||
                                    entry.value.durationMinutes > 0)
                                  Text(
                                    '${(entry.value.distanceMeters / 1000).toStringAsFixed(entry.value.distanceMeters >= 1000 ? 1 : 2)} km · ${entry.value.durationMinutes.ceil()} min',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
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
                        onPressed: onStartNavigation,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E293B),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                onStartNavigation == null
                    ? 'Navigation Active on ${route.label}'
                    : 'Start Navigation with ${route.label}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryStat({required this.label, required this.value});

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
        ),
      ),
      const SizedBox(height: 4),
      Text(
        value,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Color(0xFF111827),
        ),
      ),
    ],
  );
}

class _RouteCard extends StatelessWidget {
  final RouteOptionData route;
  final bool isSelected;
  final Color routeColor;
  final Color coverageColor;
  final VoidCallback onSelect;

  const _RouteCard({
    required this.route,
    required this.isSelected,
    required this.routeColor,
    required this.coverageColor,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onSelect,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? routeColor : const Color(0xFFE5E7EB),
              width: isSelected || route.isRecommended ? 3 : 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (route.isRecommended || isSelected)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? routeColor.withValues(alpha: 0.95)
                        : const Color(0xFF059669).withValues(alpha: 0.95),
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
                        isSelected ? 'SELECTED ROUTE' : 'RECOMMENDED',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
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
                        Expanded(
                          child: Text(
                            route.label,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111827),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? routeColor.withValues(alpha: 0.12)
                                : const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            route.rank,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? routeColor
                                  : const Color(0xFF374151),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      route.subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: routeColor.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: routeColor.withValues(alpha: 0.2),
                        ),
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
                                    color: coverageColor,
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
                                    color: coverageColor,
                                  ),
                                ),
                                Text(
                                  route.coverage,
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w700,
                                    color: coverageColor,
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
                              'Safety Score: ${route.score.toStringAsFixed(0)}/100 · ${route.route.distanceKm.toStringAsFixed(1)} km · ${route.nearbyHazards.length} hazard(s)',
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
                    if (route.wardName != null ||
                        route.streetSummary != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Text(
                          'BBMP context: ${route.wardName ?? 'Bengaluru ward'}'
                          '${route.streetSummary == null ? '' : ' · Streets: ${route.streetSummary}'}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1D4ED8),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: onSelect,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isSelected
                              ? const Color(0xFF111827)
                              : routeColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          isSelected
                              ? 'Selected route: ${route.label}'
                              : 'Choose ${route.label}',
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
        ),
      ),
    );
  }
}

class _MapPin extends StatelessWidget {
  final Color color;
  final IconData icon;

  const _MapPin({required this.color, required this.icon});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      boxShadow: [
        BoxShadow(
          color: color.withValues(alpha: 0.3),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Icon(icon, color: Colors.white, size: 20),
  );
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
          color: Colors.black.withValues(alpha: 0.05),
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
        const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            msg,
            style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13),
          ),
        ),
      ],
    ),
  );
}
