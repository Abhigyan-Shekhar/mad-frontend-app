import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import 'mapbox_service.dart';
import 'navigation_engine.dart';

class NavigationSessionSnapshot {
  final NavigationRoute route;
  final NavigationState state;
  final LatLng currentLocation;
  final bool isEmergencyActive;
  final bool isRerouting;
  final int rerouteCount;

  const NavigationSessionSnapshot({
    required this.route,
    required this.state,
    required this.currentLocation,
    this.isEmergencyActive = false,
    this.isRerouting = false,
    this.rerouteCount = 0,
  });
}

class NavigationSessionService {
  static NavigationSessionService? _instance;
  static NavigationSessionService get instance =>
      _instance ??= NavigationSessionService();

  final ValueNotifier<NavigationSessionSnapshot?> notifier = ValueNotifier(
    null,
  );

  NavigationSessionSnapshot? get currentSnapshot => notifier.value;
  NavigationState? get currentState => notifier.value?.state;
  NavigationRoute? get activeRoute => notifier.value?.route;
  bool get shouldRequestReroute {
    final snapshot = notifier.value;
    if (snapshot == null) return false;
    return snapshot.state.isOffRoute &&
        !snapshot.state.hasArrived &&
        !snapshot.isRerouting;
  }

  String? get currentInstruction {
    final snapshot = notifier.value;
    if (snapshot == null || snapshot.route.steps.isEmpty) return null;
    final index = snapshot.state.currentStepIndex.clamp(
      0,
      snapshot.route.steps.length - 1,
    );
    return snapshot.route.steps[index].instruction;
  }

  String? get nextInstruction {
    final snapshot = notifier.value;
    if (snapshot == null) return null;
    final nextIndex = snapshot.state.currentStepIndex + 1;
    if (nextIndex >= snapshot.route.steps.length) return null;
    return snapshot.route.steps[nextIndex].instruction;
  }

  void activateRoute(NavigationRoute route, {required LatLng initialLocation}) {
    final state = NavigationEngine.evaluate(
      route: route,
      currentStepIndex: 0,
      currentLocation: initialLocation,
    );
    notifier.value = NavigationSessionSnapshot(
      route: route,
      state: state,
      currentLocation: initialLocation,
    );
  }

  void updateWithLocation(LatLng currentLocation) {
    final snapshot = notifier.value;
    if (snapshot == null) return;
    final state = NavigationEngine.evaluate(
      route: snapshot.route,
      currentStepIndex: snapshot.state.currentStepIndex,
      currentLocation: currentLocation,
    );
    notifier.value = NavigationSessionSnapshot(
      route: snapshot.route,
      state: state,
      currentLocation: currentLocation,
      isEmergencyActive: snapshot.isEmergencyActive,
      isRerouting: snapshot.isRerouting,
      rerouteCount: snapshot.rerouteCount,
    );
  }

  void markRerouting() {
    final snapshot = notifier.value;
    if (snapshot == null) return;
    notifier.value = NavigationSessionSnapshot(
      route: snapshot.route,
      state: snapshot.state,
      currentLocation: snapshot.currentLocation,
      isEmergencyActive: snapshot.isEmergencyActive,
      isRerouting: true,
      rerouteCount: snapshot.rerouteCount,
    );
  }

  void applyReroute(
    NavigationRoute route, {
    required LatLng currentLocation,
  }) {
    final snapshot = notifier.value;
    final nextRerouteCount = (snapshot?.rerouteCount ?? 0) + 1;
    final state = NavigationEngine.evaluate(
      route: route,
      currentStepIndex: 0,
      currentLocation: currentLocation,
    );
    notifier.value = NavigationSessionSnapshot(
      route: route,
      state: state,
      currentLocation: currentLocation,
      isEmergencyActive: snapshot?.isEmergencyActive ?? false,
      isRerouting: false,
      rerouteCount: nextRerouteCount,
    );
  }

  void cancelRerouting() {
    final snapshot = notifier.value;
    if (snapshot == null) return;
    notifier.value = NavigationSessionSnapshot(
      route: snapshot.route,
      state: snapshot.state,
      currentLocation: snapshot.currentLocation,
      isEmergencyActive: snapshot.isEmergencyActive,
      isRerouting: false,
      rerouteCount: snapshot.rerouteCount,
    );
  }

  void markEmergencyActive() {
    final snapshot = notifier.value;
    if (snapshot == null) return;
    notifier.value = NavigationSessionSnapshot(
      route: snapshot.route,
      state: snapshot.state,
      currentLocation: snapshot.currentLocation,
      isEmergencyActive: true,
      isRerouting: snapshot.isRerouting,
      rerouteCount: snapshot.rerouteCount,
    );
  }

  void resolveEmergency() {
    final snapshot = notifier.value;
    if (snapshot == null) return;
    notifier.value = NavigationSessionSnapshot(
      route: snapshot.route,
      state: snapshot.state,
      currentLocation: snapshot.currentLocation,
      isEmergencyActive: false,
      isRerouting: snapshot.isRerouting,
      rerouteCount: snapshot.rerouteCount,
    );
  }

  void clear() {
    notifier.value = null;
  }
}
