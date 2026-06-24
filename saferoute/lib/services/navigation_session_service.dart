import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import 'mapbox_service.dart';
import 'navigation_engine.dart';

class NavigationSessionSnapshot {
  final NavigationRoute route;
  final NavigationState state;
  final LatLng currentLocation;
  final DateTime startedAt;
  final String destinationName;
  final String? routeLabel;
  final double? safetyScore;
  final double? baseScore;
  final double? hazardPenalty;
  final List<Map<String, dynamic>> nearbyHazards;
  final bool isEmergencyActive;
  final bool isRerouting;
  final int rerouteCount;

  const NavigationSessionSnapshot({
    required this.route,
    required this.state,
    required this.currentLocation,
    required this.startedAt,
    required this.destinationName,
    this.routeLabel,
    this.safetyScore,
    this.baseScore,
    this.hazardPenalty,
    this.nearbyHazards = const [],
    this.isEmergencyActive = false,
    this.isRerouting = false,
    this.rerouteCount = 0,
  });
}

String formatElapsedJourneyTime(Duration duration) {
  final totalMinutes = duration.inMinutes;
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  final seconds = duration.inSeconds % 60;
  if (hours > 0) {
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
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

  void activateRoute(
    NavigationRoute route, {
    required LatLng initialLocation,
    required String destinationName,
    String? routeLabel,
    double? safetyScore,
    double? baseScore,
    double? hazardPenalty,
    List<Map<String, dynamic>> nearbyHazards = const [],
  }) {
    final state = NavigationEngine.evaluate(
      route: route,
      currentStepIndex: 0,
      currentLocation: initialLocation,
    );
    notifier.value = NavigationSessionSnapshot(
      route: route,
      state: state,
      currentLocation: initialLocation,
      startedAt: DateTime.now(),
      destinationName: destinationName,
      routeLabel: routeLabel,
      safetyScore: safetyScore,
      baseScore: baseScore,
      hazardPenalty: hazardPenalty,
      nearbyHazards: nearbyHazards,
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
      startedAt: snapshot.startedAt,
      destinationName: snapshot.destinationName,
      routeLabel: snapshot.routeLabel,
      safetyScore: snapshot.safetyScore,
      baseScore: snapshot.baseScore,
      hazardPenalty: snapshot.hazardPenalty,
      nearbyHazards: snapshot.nearbyHazards,
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
      startedAt: snapshot.startedAt,
      destinationName: snapshot.destinationName,
      routeLabel: snapshot.routeLabel,
      safetyScore: snapshot.safetyScore,
      baseScore: snapshot.baseScore,
      hazardPenalty: snapshot.hazardPenalty,
      nearbyHazards: snapshot.nearbyHazards,
      isEmergencyActive: snapshot.isEmergencyActive,
      isRerouting: true,
      rerouteCount: snapshot.rerouteCount,
    );
  }

  void applyReroute(
    NavigationRoute route, {
    required LatLng currentLocation,
    String? destinationName,
    String? routeLabel,
    double? safetyScore,
    double? baseScore,
    double? hazardPenalty,
    List<Map<String, dynamic>>? nearbyHazards,
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
      startedAt: snapshot?.startedAt ?? DateTime.now(),
      destinationName:
          destinationName ?? snapshot?.destinationName ?? 'Destination',
      routeLabel: routeLabel ?? snapshot?.routeLabel,
      safetyScore: safetyScore ?? snapshot?.safetyScore,
      baseScore: baseScore ?? snapshot?.baseScore,
      hazardPenalty: hazardPenalty ?? snapshot?.hazardPenalty,
      nearbyHazards: nearbyHazards ?? snapshot?.nearbyHazards ?? const [],
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
      startedAt: snapshot.startedAt,
      destinationName: snapshot.destinationName,
      routeLabel: snapshot.routeLabel,
      safetyScore: snapshot.safetyScore,
      baseScore: snapshot.baseScore,
      hazardPenalty: snapshot.hazardPenalty,
      nearbyHazards: snapshot.nearbyHazards,
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
      startedAt: snapshot.startedAt,
      destinationName: snapshot.destinationName,
      routeLabel: snapshot.routeLabel,
      safetyScore: snapshot.safetyScore,
      baseScore: snapshot.baseScore,
      hazardPenalty: snapshot.hazardPenalty,
      nearbyHazards: snapshot.nearbyHazards,
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
      startedAt: snapshot.startedAt,
      destinationName: snapshot.destinationName,
      routeLabel: snapshot.routeLabel,
      safetyScore: snapshot.safetyScore,
      baseScore: snapshot.baseScore,
      hazardPenalty: snapshot.hazardPenalty,
      nearbyHazards: snapshot.nearbyHazards,
      isEmergencyActive: false,
      isRerouting: snapshot.isRerouting,
      rerouteCount: snapshot.rerouteCount,
    );
  }

  void clear() {
    notifier.value = null;
  }
}
