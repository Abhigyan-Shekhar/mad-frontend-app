import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:saferoute/services/mapbox_service.dart';
import 'package:saferoute/services/navigation_session_service.dart';

NavigationRoute _route() {
  return const NavigationRoute(
    id: 'route-1',
    durationMinutes: 12,
    distanceKm: 0.3,
    points: [
      LatLng(12.9716, 77.5946),
      LatLng(12.9721, 77.5951),
      LatLng(12.9726, 77.5956),
    ],
    steps: [
      NavigationStep(
        instruction: 'Head north on 6th Cross Road',
        distanceMeters: 100,
        durationMinutes: 1,
      ),
      NavigationStep(
        instruction: 'Turn right toward Brigade Road',
        distanceMeters: 200,
        durationMinutes: 2,
      ),
    ],
  );
}

void main() {
  test('exposes current and next instruction from active navigation state', () {
    final service = NavigationSessionService();
    final route = _route();

    service.activateRoute(route, initialLocation: route.points.first);

    expect(service.currentInstruction, 'Head north on 6th Cross Road');
    expect(service.nextInstruction, 'Turn right toward Brigade Road');
  });

  test(
    'updates progress and marks arrival when location reaches destination',
    () {
      final service = NavigationSessionService();
      final route = _route();

      service.activateRoute(route, initialLocation: route.points.first);
      service.updateWithLocation(route.points.last);

      expect(service.currentState?.hasArrived, isTrue);
      expect(service.currentState?.progressFraction, 1);
    },
  );

  test('clear removes the active live navigation session', () {
    final service = NavigationSessionService();
    final route = _route();

    service.activateRoute(route, initialLocation: route.points.first);
    service.clear();

    expect(service.currentSnapshot, isNull);
    expect(service.currentInstruction, isNull);
    expect(service.nextInstruction, isNull);
  });

  test('can enter rerouting mode and replace the active route', () {
    final service = NavigationSessionService();
    final route = _route();
    const currentLocation = LatLng(12.9732, 77.5962);
    const reroutedRoute = NavigationRoute(
      id: 'route-2',
      durationMinutes: 9,
      distanceKm: 0.25,
      points: [
        currentLocation,
        LatLng(12.9737, 77.5967),
        LatLng(12.9742, 77.5972),
      ],
      steps: [
        NavigationStep(
          instruction: 'Turn left onto Residency Road',
          distanceMeters: 120,
          durationMinutes: 1,
        ),
        NavigationStep(
          instruction: 'Continue toward the destination',
          distanceMeters: 140,
          durationMinutes: 2,
        ),
      ],
    );

    service.activateRoute(route, initialLocation: route.points.first);
    service.markRerouting();

    expect(service.currentSnapshot?.isRerouting, isTrue);
    expect(service.shouldRequestReroute, isFalse);

    service.applyReroute(
      reroutedRoute,
      currentLocation: currentLocation,
    );

    expect(service.activeRoute?.id, 'route-2');
    expect(service.currentSnapshot?.isRerouting, isFalse);
    expect(service.currentSnapshot?.rerouteCount, 1);
    expect(
      service.currentInstruction,
      'Turn left onto Residency Road',
    );
    expect(service.currentState?.isOffRoute, isFalse);
  });
}
