import 'package:latlong2/latlong.dart';

import 'bbmp_service.dart';
import 'mapbox_service.dart';
import 'route_safety_engine.dart';
import 'supabase_service.dart';

class RouteSafetyBundle {
  final NavigationRoute navigationRoute;
  final RankedRoute ranking;
  final List<Map<String, dynamic>> nearbyHazards;

  const RouteSafetyBundle({
    required this.navigationRoute,
    required this.ranking,
    required this.nearbyHazards,
  });
}

class SafetyDataService {
  static SafetyDataService? _instance;
  static SafetyDataService get instance => _instance ??= SafetyDataService._();
  SafetyDataService._();

  final _bbmp = BbmpService.instance;
  final _supabase = SupabaseService.instance;

  Future<List<RouteSafetyBundle>> rankRoutes({
    required List<NavigationRoute> routes,
    required String originLabel,
    required String destinationLabel,
    required List<Map<String, dynamic>> activeHazards,
  }) async {
    final baseScore = await _bbmp.routeSafetyScore(originLabel, destinationLabel);
    final wardSummary = await _bbmp.describeRouteArea(originLabel, destinationLabel);
    final streetSummary = await _supabase.getStreetSegments(
      wardName: wardSummary?.wardName,
      limit: 3,
    );

    final inputs = <SafetyRouteInput>[];
    final nearbyHazardsByRoute = <String, List<Map<String, dynamic>>>{};

    for (final route in routes) {
      final nearby = _hazardsNearRoute(route.points, activeHazards);
      nearbyHazardsByRoute[route.id] = nearby;
      inputs.add(
        SafetyRouteInput(
          routeId: route.id,
          points: route.points,
          baseScore: baseScore,
          distanceKm: route.distanceKm,
          durationMinutes: route.durationMinutes,
          hazards: nearby
              .map(
                (hazard) => RouteHazard(
                  type: hazard['hazard_type']?.toString() ?? 'unknown',
                  point: LatLng(
                    (hazard['lat'] as num?)?.toDouble() ?? 0,
                    (hazard['lng'] as num?)?.toDouble() ?? 0,
                  ),
                  description: hazard['description']?.toString(),
                ),
              )
              .toList(growable: false),
          wardContext: wardSummary?.wardName,
          streetContext: streetSummary.isEmpty
              ? null
              : streetSummary
                  .map((segment) => segment['street_name']?.toString())
                  .whereType<String>()
                  .where((name) => name.trim().isNotEmpty)
                  .take(2)
                  .join(', '),
        ),
      );
    }

    final ranked = RouteSafetyEngine.rank(inputs);
    final routeById = {for (final route in routes) route.id: route};

    return ranked
        .map(
          (analysis) => RouteSafetyBundle(
            navigationRoute: routeById[analysis.routeId]!,
            ranking: analysis,
            nearbyHazards: nearbyHazardsByRoute[analysis.routeId] ?? const [],
          ),
        )
        .toList(growable: false);
  }

  Future<void> saveAnalysisSnapshot({
    required String routeId,
    required String destinationName,
    String? tripId,
    required double score,
    required double baseScore,
    required double hazardPenalty,
    required String coverage,
    required List<String> highlights,
    required List<Map<String, dynamic>> hazards,
    String? wardName,
    String? streetSummary,
  }) {
    return _supabase.saveRouteAnalysis(
      routeId: routeId,
      destinationName: destinationName,
      tripId: tripId,
      score: score,
      baseScore: baseScore,
      hazardPenalty: hazardPenalty,
      coverage: coverage,
      highlights: highlights,
      hazardTypes: hazards
          .map((hazard) => hazard['hazard_type']?.toString() ?? 'unknown')
          .toList(growable: false),
      wardName: wardName,
      streetSummary: streetSummary,
    );
  }

  List<Map<String, dynamic>> _hazardsNearRoute(
    List<LatLng> points,
    List<Map<String, dynamic>> hazards,
  ) {
    if (points.isEmpty) return const [];
    const distance = Distance();
    return hazards.where((hazard) {
      final lat = (hazard['lat'] as num?)?.toDouble();
      final lng = (hazard['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) return false;
      final hazardPoint = LatLng(lat, lng);
      return points.any(
        (point) => distance.as(LengthUnit.Meter, point, hazardPoint) <= 350,
      );
    }).toList(growable: false);
  }
}
