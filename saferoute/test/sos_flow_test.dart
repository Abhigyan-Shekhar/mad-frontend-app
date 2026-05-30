import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:saferoute/services/mapbox_service.dart';
import 'package:saferoute/services/navigation_session_service.dart';
import 'package:saferoute/services/supabase_service.dart';

NavigationRoute _route() {
  return const NavigationRoute(
    id: 'route-sos',
    durationMinutes: 8,
    distanceKm: 2.1,
    points: [LatLng(12.9716, 77.5946), LatLng(12.9726, 77.5956)],
    steps: [NavigationStep(instruction: 'Head north')],
  );
}

void main() {
  test('deriveTripStatusAfterSos promotes active trips to sos_triggered', () {
    expect(deriveTripStatusAfterSos(currentStatus: 'active'), 'sos_triggered');
    expect(deriveTripStatusAfterSos(currentStatus: 'completed'), 'completed');
  });

  test('navigation session marks emergency active and clears it', () {
    final service = NavigationSessionService();
    service.activateRoute(_route(), initialLocation: _route().points.first);

    service.markEmergencyActive();
    expect(service.currentSnapshot?.isEmergencyActive, isTrue);

    service.resolveEmergency();
    expect(service.currentSnapshot?.isEmergencyActive, isFalse);
  });
}
