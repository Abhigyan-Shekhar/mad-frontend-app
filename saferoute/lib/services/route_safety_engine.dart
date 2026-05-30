import 'package:latlong2/latlong.dart';

class RouteHazard {
  final String type;
  final LatLng point;
  final String? description;

  const RouteHazard({
    required this.type,
    required this.point,
    this.description,
  });
}

class SafetyRouteInput {
  final String routeId;
  final List<LatLng> points;
  final double baseScore;
  final double distanceKm;
  final double durationMinutes;
  final List<RouteHazard> hazards;
  final String? wardContext;
  final String? streetContext;

  const SafetyRouteInput({
    required this.routeId,
    required this.points,
    required this.baseScore,
    this.distanceKm = 0,
    this.durationMinutes = 0,
    required this.hazards,
    this.wardContext,
    this.streetContext,
  });
}

class RankedRoute {
  final String routeId;
  final double score;
  final double penalty;
  final String coverage;
  final List<String> reasons;
  final String? wardContext;
  final String? streetContext;

  const RankedRoute({
    required this.routeId,
    required this.score,
    required this.penalty,
    required this.coverage,
    required this.reasons,
    this.wardContext,
    this.streetContext,
  });
}

class RouteSafetyEngine {
  static List<RankedRoute> rank(List<SafetyRouteInput> routes) {
    final shortestDistance = routes.isEmpty
        ? 0.0
        : routes
              .map((route) => route.distanceKm > 0 ? route.distanceKm : _distanceKm(route.points))
              .reduce((a, b) => a < b ? a : b);
    final shortestDuration = routes.isEmpty
        ? 0.0
        : routes
              .map((route) => route.durationMinutes)
              .reduce((a, b) => a < b ? a : b);
    final ranked = routes
        .map((route) {
          final hazardPenaltyScore = route.hazards.fold<double>(
            0,
            (sum, hazard) => sum + hazardPenalty(hazard.type),
          );
          final routeExposurePenalty = exposurePenalty(
            distanceKm: route.distanceKm > 0
                ? route.distanceKm
                : _distanceKm(route.points),
            durationMinutes: route.durationMinutes,
            shortestDistanceKm: shortestDistance,
            shortestDurationMinutes: shortestDuration,
          );
          final penalty = (hazardPenaltyScore + routeExposurePenalty).toDouble();
          final score = (route.baseScore - penalty).clamp(0, 100).toDouble();
          return RankedRoute(
            routeId: route.routeId,
            score: score,
            penalty: penalty,
            coverage: coverageForScore(score),
            reasons: buildHighlights(route.hazards),
            wardContext: route.wardContext,
            streetContext: route.streetContext,
          );
        })
        .toList(growable: false);

    final sorted = [...ranked];
    sorted.sort((a, b) => b.score.compareTo(a.score));
    return sorted;
  }

  static double exposurePenalty({
    required double distanceKm,
    required double durationMinutes,
    required double shortestDistanceKm,
    required double shortestDurationMinutes,
  }) {
    var penalty = 0.0;
    if (shortestDistanceKm > 0 && distanceKm > shortestDistanceKm) {
      penalty += ((distanceKm - shortestDistanceKm) * 1.1).clamp(0, 6);
    }
    if (shortestDurationMinutes > 0 &&
        durationMinutes > shortestDurationMinutes) {
      penalty +=
          (((durationMinutes - shortestDurationMinutes) / 4) * 0.8).clamp(0, 4);
    }
    return penalty;
  }

  static double hazardPenalty(String type) {
    switch (type) {
      case 'theft':
        return 14;
      case 'accident':
        return 12;
      case 'deadzone':
        return 10;
      case 'lighting':
        return 8;
      case 'pothole':
        return 6;
      default:
        return 5;
    }
  }

  static String coverageForScore(double score) {
    if (score >= 78) return 'Full';
    if (score >= 55) return 'Partial';
    return 'Risk';
  }

  static List<String> buildHighlights(List<RouteHazard> hazards) {
    if (hazards.isEmpty) {
      return const [
        'No active community hazards reported on this route',
        'Guardian tracking recommended for extra safety',
      ];
    }

    final grouped = <String, int>{};
    for (final hazard in hazards) {
      grouped[hazard.type] = (grouped[hazard.type] ?? 0) + 1;
    }

    final lines = grouped.entries
        .map((entry) => '${entry.value} ${humanHazard(entry.key)} alert(s)')
        .toList(growable: false);

    if (!grouped.containsKey('deadzone')) {
      return [...lines, 'Mobile coverage appears safer than deadzone routes'];
    }
    return lines;
  }

  static String humanHazard(String type) {
    switch (type) {
      case 'pothole':
        return 'pothole';
      case 'lighting':
        return 'lighting';
      case 'theft':
        return 'theft-risk';
      case 'accident':
        return 'accident';
      case 'deadzone':
        return 'deadzone';
      default:
        return type;
    }
  }

  static double _distanceKm(List<LatLng> points) {
    if (points.length < 2) return 0;
    const distance = Distance();
    var totalMeters = 0.0;
    for (var i = 1; i < points.length; i++) {
      totalMeters += distance.as(LengthUnit.Meter, points[i - 1], points[i]);
    }
    return totalMeters / 1000;
  }
}
