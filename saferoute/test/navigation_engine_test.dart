import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:saferoute/services/mapbox_service.dart';
import 'package:saferoute/services/navigation_engine.dart';

NavigationRoute _route() {
  return const NavigationRoute(
    id: 'r1',
    durationMinutes: 12,
    distanceKm: 0.3,
    points: [
      LatLng(12.9716, 77.5946),
      LatLng(12.9721, 77.5951),
      LatLng(12.9726, 77.5956),
    ],
    steps: [
      NavigationStep(
        instruction: 'Head north',
        distanceMeters: 100,
        durationMinutes: 1,
      ),
      NavigationStep(
        instruction: 'Turn right',
        distanceMeters: 200,
        durationMinutes: 2,
      ),
    ],
  );
}

void main() {
  test(
    'advances to the next step when the current step endpoint is reached',
    () {
      final state = NavigationEngine.evaluate(
        route: _route(),
        currentStepIndex: 0,
        currentLocation: const LatLng(12.9726, 77.5956),
      );

      expect(state.currentStepIndex, 1);
    },
  );

  test(
    'marks route as off-route when the user is far from all route points',
    () {
      final state = NavigationEngine.evaluate(
        route: _route(),
        currentStepIndex: 0,
        currentLocation: const LatLng(13.1000, 77.9000),
      );

      expect(state.isOffRoute, isTrue);
    },
  );

  test('marks trip as arrived when user is within arrival threshold', () {
    final route = _route();
    final state = NavigationEngine.evaluate(
      route: route,
      currentStepIndex: 1,
      currentLocation: route.points.last,
    );

    expect(state.hasArrived, isTrue);
  });
}
