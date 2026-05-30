import 'package:latlong2/latlong.dart';

import 'mapbox_service.dart';

class NavigationState {
  final int currentStepIndex;
  final bool isOffRoute;
  final bool hasArrived;
  final double progressFraction;

  const NavigationState({
    required this.currentStepIndex,
    required this.isOffRoute,
    required this.hasArrived,
    required this.progressFraction,
  });
}

class NavigationEngine {
  static const Distance _distance = Distance();
  static const double _offRouteThresholdMeters = 90;
  static const double _arrivalThresholdMeters = 35;
  static const double _stepAdvanceThresholdMeters = 45;

  static NavigationState evaluate({
    required NavigationRoute route,
    required int currentStepIndex,
    required LatLng currentLocation,
  }) {
    final resolvedStepIndex = _resolveCurrentStepIndex(
      route: route,
      currentStepIndex: currentStepIndex,
      currentLocation: currentLocation,
    );
    final destinationDistance = route.points.isEmpty
        ? double.infinity
        : _distance.as(LengthUnit.Meter, currentLocation, route.points.last);
    final closestRouteDistance = _closestRouteDistance(
      route.points,
      currentLocation,
    );
    final progressFraction = route.steps.isEmpty
        ? (route.points.isEmpty ? 0.0 : 1.0)
        : ((resolvedStepIndex +
                      (destinationDistance <= _arrivalThresholdMeters
                          ? 1
                          : 0)) /
                  route.steps.length)
              .clamp(0.0, 1.0)
              .toDouble();

    return NavigationState(
      currentStepIndex: resolvedStepIndex,
      isOffRoute: closestRouteDistance > _offRouteThresholdMeters,
      hasArrived: destinationDistance <= _arrivalThresholdMeters,
      progressFraction: progressFraction,
    );
  }

  static int _resolveCurrentStepIndex({
    required NavigationRoute route,
    required int currentStepIndex,
    required LatLng currentLocation,
  }) {
    if (route.steps.isEmpty || route.points.isEmpty) return 0;
    final safeIndex = currentStepIndex.clamp(0, route.steps.length - 1);
    final nearestPointIndex = _nearestPointIndex(route.points, currentLocation);
    final maxPointIndex = route.points.length - 1;
    if (maxPointIndex <= 0) return safeIndex;

    final projectedStepIndex =
        ((nearestPointIndex / maxPointIndex) * route.steps.length)
            .floor()
            .clamp(0, route.steps.length - 1);

    if (projectedStepIndex > safeIndex) return projectedStepIndex;

    final stepTargetIndex = (safeIndex + 1).clamp(0, route.points.length - 1);
    final distanceToTarget = _distance.as(
      LengthUnit.Meter,
      currentLocation,
      route.points[stepTargetIndex],
    );
    if (distanceToTarget <= _stepAdvanceThresholdMeters &&
        safeIndex < route.steps.length - 1) {
      return safeIndex + 1;
    }
    return safeIndex;
  }

  static double _closestRouteDistance(
    List<LatLng> routePoints,
    LatLng currentLocation,
  ) {
    if (routePoints.isEmpty) return double.infinity;
    var minDistance = double.infinity;
    for (final point in routePoints) {
      final distance = _distance.as(LengthUnit.Meter, currentLocation, point);
      if (distance < minDistance) {
        minDistance = distance;
      }
    }
    return minDistance;
  }

  static int _nearestPointIndex(
    List<LatLng> routePoints,
    LatLng currentLocation,
  ) {
    var nearestIndex = 0;
    var minDistance = double.infinity;
    for (var i = 0; i < routePoints.length; i++) {
      final distance = _distance.as(
        LengthUnit.Meter,
        currentLocation,
        routePoints[i],
      );
      if (distance < minDistance) {
        minDistance = distance;
        nearestIndex = i;
      }
    }
    return nearestIndex;
  }
}
