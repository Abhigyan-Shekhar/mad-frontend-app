import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:saferoute/screens/tab_plan_journey_screen.dart';
import 'package:saferoute/services/mapbox_service.dart';

RouteOptionData _route({
  required String id,
  required String label,
  required double score,
  required int hazards,
  List<NavigationStep> steps = const [],
}) {
  return RouteOptionData(
    route: NavigationRoute(
      id: id,
      durationMinutes: 18,
      distanceKm: 6.2,
      points: const [LatLng(12.9716, 77.5946), LatLng(12.9750, 77.6050)],
      steps: steps,
    ),
    destinationName: 'MG Road',
    label: label,
    subtitle: 'Test route',
    rank: '#1',
    coverage: 'High',
    score: score,
    baseScore: score + 5,
    hazardPenalty: 5,
    highlights: const ['Well lit'],
    nearbyHazards: List.generate(
      hazards,
      (index) => {'hazard_type': 'lighting', 'lat': 12.97, 'lng': 77.59},
    ),
  );
}

void main() {
  test('defaults selected route to safest route id', () {
    final routes = [
      _route(
        id: 'route-safe',
        label: 'Well-lit Streets',
        score: 91,
        hazards: 1,
      ),
      _route(
        id: 'route-balanced',
        label: 'Standard Path',
        score: 72,
        hazards: 2,
      ),
      _route(id: 'route-fast', label: 'Direct Route', score: 54, hazards: 4),
    ];

    final selected = defaultSelectedRouteId(routes);

    expect(selected, 'route-safe');
  });

  test('allows explicit route selection by id when route exists', () {
    final routes = [
      _route(
        id: 'route-safe',
        label: 'Well-lit Streets',
        score: 91,
        hazards: 1,
      ),
      _route(
        id: 'route-balanced',
        label: 'Standard Path',
        score: 72,
        hazards: 2,
      ),
    ];

    final selected = selectRouteId(
      routes,
      currentRouteId: 'route-safe',
      nextRouteId: 'route-balanced',
    );

    expect(selected, 'route-balanced');
  });

  test('prefers the first valid polyline hit when selecting from the map', () {
    final routes = [
      _route(
        id: 'route-safe',
        label: 'Well-lit Streets',
        score: 91,
        hazards: 1,
      ),
      _route(
        id: 'route-balanced',
        label: 'Standard Path',
        score: 72,
        hazards: 2,
      ),
      _route(id: 'route-fast', label: 'Direct Route', score: 54, hazards: 4),
    ];

    final selected = selectRouteIdFromMapHit(
      routes,
      currentRouteId: 'route-safe',
      hitRouteIds: const ['route-fast', 'route-balanced'],
    );

    expect(selected, 'route-fast');
  });

  test('builds trip payload from the selected route only', () {
    final selectedRoute = _route(
      id: 'route-fast',
      label: 'Direct Route',
      score: 54,
      hazards: 4,
    );

    final payload = buildTripStartPayload(selectedRoute);

    expect(payload.routeId, 'route-fast');
    expect(payload.destinationName, 'MG Road');
    expect(payload.start.latitude, 12.9716);
    expect(payload.end.longitude, 77.6050);
  });

  test('limits selected-route preview steps to the requested count', () {
    final route = _route(
      id: 'route-safe',
      label: 'Well-lit Streets',
      score: 91,
      hazards: 1,
      steps: const [
        NavigationStep(instruction: 'Head north on 6th Cross Road'),
        NavigationStep(instruction: 'Turn right toward Brigade Road'),
        NavigationStep(instruction: 'Continue onto MG Road'),
        NavigationStep(instruction: 'Keep left at the junction'),
        NavigationStep(instruction: 'Arrive at destination'),
      ],
    );

    final preview = previewNavigationSteps(route.route, limit: 4);

    expect(preview, hasLength(4));
    expect(preview.first.instruction, 'Head north on 6th Cross Road');
    expect(preview.last.instruction, 'Keep left at the junction');
  });
}
