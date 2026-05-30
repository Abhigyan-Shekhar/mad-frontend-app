import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:saferoute/services/route_safety_engine.dart';

void main() {
  test('prefers safer route when hazard penalty is lower', () {
    const routeA = SafetyRouteInput(
      routeId: 'a',
      points: [LatLng(12.0, 77.0), LatLng(12.01, 77.01)],
      baseScore: 80,
      distanceKm: 1.6,
      durationMinutes: 6,
      hazards: [
        RouteHazard(type: 'lighting', point: LatLng(12.0, 77.0)),
      ],
    );
    const routeB = SafetyRouteInput(
      routeId: 'b',
      points: [LatLng(12.0, 77.0), LatLng(12.01, 77.02)],
      baseScore: 80,
      distanceKm: 1.8,
      durationMinutes: 7,
      hazards: [
        RouteHazard(type: 'theft', point: LatLng(12.0, 77.0)),
      ],
    );

    final ranked = RouteSafetyEngine.rank([routeA, routeB]);

    expect(ranked.first.routeId, 'a');
    expect(ranked.first.score, greaterThan(ranked.last.score));
  });

  test('breaks ties using route exposure when hazards are the same', () {
    const shorterRoute = SafetyRouteInput(
      routeId: 'shorter',
      points: [LatLng(12.0, 77.0), LatLng(12.01, 77.01)],
      baseScore: 70,
      distanceKm: 3.2,
      durationMinutes: 11,
      hazards: [],
    );
    const longerRoute = SafetyRouteInput(
      routeId: 'longer',
      points: [LatLng(12.0, 77.0), LatLng(12.03, 77.04)],
      baseScore: 70,
      distanceKm: 6.8,
      durationMinutes: 21,
      hazards: [],
    );

    final ranked = RouteSafetyEngine.rank([shorterRoute, longerRoute]);

    expect(ranked.first.routeId, 'shorter');
    expect(ranked.first.score, greaterThan(ranked.last.score));
  });
}
