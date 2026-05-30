# SafeRoute Navigation, Guardian, and SOS Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a shared live trip engine that upgrades SafeRoute into a real navigation flow with guardian visibility and reliable SOS state handling.

**Architecture:** Introduce a dedicated navigation engine service that owns current route progress, step advancement, off-route detection, reroute decisions, and arrival detection. Then connect plan, guardian, and safety screens to that shared state while persisting the minimum active-trip data needed in Supabase.

**Tech Stack:** Flutter, `flutter_map`, `latlong2`, Mapbox Directions API, Supabase, Flutter unit/widget tests

---

### Task 1: Build the pure navigation engine core

**Files:**
- Create: `saferoute/lib/services/navigation_engine.dart`
- Create: `saferoute/test/navigation_engine_test.dart`
- Modify: `saferoute/lib/services/mapbox_service.dart`

- [ ] **Step 1: Write the failing test**

```dart
test('advances to the next step when the current step endpoint is reached', () {
  final route = NavigationRoute(
    id: 'r1',
    durationMinutes: 12,
    distanceKm: 3.4,
    points: const [LatLng(12.9716, 77.5946), LatLng(12.9726, 77.5956)],
    steps: const [
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

  final state = NavigationEngine.evaluate(
    route: route,
    currentStepIndex: 0,
    currentLocation: const LatLng(12.9726, 77.5956),
  );

  expect(state.currentStepIndex, 1);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test --no-pub test/navigation_engine_test.dart`
Expected: FAIL because `NavigationEngine` does not exist yet

- [ ] **Step 3: Write minimal implementation**

```dart
class NavigationState {
  final int currentStepIndex;
  final bool isOffRoute;
  final bool hasArrived;

  const NavigationState({
    required this.currentStepIndex,
    this.isOffRoute = false,
    this.hasArrived = false,
  });
}

class NavigationEngine {
  static NavigationState evaluate({
    required NavigationRoute route,
    required int currentStepIndex,
    required LatLng currentLocation,
  }) {
    final nextIndex =
        currentStepIndex < route.steps.length - 1 ? currentStepIndex + 1 : currentStepIndex;
    return NavigationState(currentStepIndex: nextIndex);
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test --no-pub test/navigation_engine_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add saferoute/lib/services/navigation_engine.dart saferoute/test/navigation_engine_test.dart saferoute/lib/services/mapbox_service.dart
git commit -m "feat: add navigation engine core"
```

### Task 2: Add progress, off-route detection, and arrival rules

**Files:**
- Modify: `saferoute/lib/services/navigation_engine.dart`
- Modify: `saferoute/test/navigation_engine_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
test('marks route as off-route when the user is far from all route points', () {
  final route = buildTestRoute();

  final state = NavigationEngine.evaluate(
    route: route,
    currentStepIndex: 0,
    currentLocation: const LatLng(13.1000, 77.9000),
  );

  expect(state.isOffRoute, isTrue);
});

test('marks trip as arrived when user is within arrival threshold of destination', () {
  final route = buildTestRoute();

  final state = NavigationEngine.evaluate(
    route: route,
    currentStepIndex: 1,
    currentLocation: route.points.last,
  );

  expect(state.hasArrived, isTrue);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test --no-pub test/navigation_engine_test.dart`
Expected: FAIL because off-route and arrival logic are not implemented

- [ ] **Step 3: Write minimal implementation**

```dart
final closestDistance = _distanceToRoute(route.points, currentLocation);
final destinationDistance = _distance.as(
  LengthUnit.Meter,
  currentLocation,
  route.points.last,
);

return NavigationState(
  currentStepIndex: resolvedStepIndex,
  isOffRoute: closestDistance > 90,
  hasArrived: destinationDistance <= 35,
);
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test --no-pub test/navigation_engine_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add saferoute/lib/services/navigation_engine.dart saferoute/test/navigation_engine_test.dart
git commit -m "feat: add navigation progress and off-route detection"
```

### Task 3: Wire live navigation state into the route flow

**Files:**
- Create: `saferoute/lib/services/navigation_session_service.dart`
- Modify: `saferoute/lib/screens/tab_plan_journey_screen.dart`
- Modify: `saferoute/lib/screens/home_screen.dart`
- Test: `saferoute/test/plan_journey_route_option_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
test('selected route preview exposes current and next maneuver text', () {
  final route = buildRouteWithSteps();
  final state = NavigationEngine.evaluate(
    route: route.route,
    currentStepIndex: 0,
    currentLocation: route.route.points.first,
  );

  expect(currentInstruction(state, route.route), 'Head north');
  expect(nextInstruction(state, route.route), 'Turn right');
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test --no-pub test/plan_journey_route_option_test.dart test/navigation_engine_test.dart`
Expected: FAIL because maneuver helpers are not exposed yet

- [ ] **Step 3: Write minimal implementation**

```dart
String? currentInstruction(NavigationState state, NavigationRoute route) =>
    route.steps.isEmpty ? null : route.steps[state.currentStepIndex].instruction;

String? nextInstruction(NavigationState state, NavigationRoute route) {
  final next = state.currentStepIndex + 1;
  return next < route.steps.length ? route.steps[next].instruction : null;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test --no-pub test/plan_journey_route_option_test.dart test/navigation_engine_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add saferoute/lib/services/navigation_session_service.dart saferoute/lib/screens/tab_plan_journey_screen.dart saferoute/lib/screens/home_screen.dart saferoute/test/plan_journey_route_option_test.dart
git commit -m "feat: wire live navigation state into route flow"
```

### Task 4: Upgrade guardian mode to shared live trip state

**Files:**
- Modify: `saferoute/lib/screens/tab_guardian_screen.dart`
- Modify: `saferoute/lib/services/navigation_session_service.dart`
- Test: `saferoute/test/widget_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
testWidgets('guardian screen shows live trip status from shared navigation state', (tester) async {
  await tester.pumpWidget(buildGuardianForTest(withLiveTrip: true));
  expect(find.textContaining('LIVE'), findsOneWidget);
  expect(find.textContaining('ETA'), findsWidgets);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test --no-pub test/widget_test.dart`
Expected: FAIL because guardian screen does not consume shared live trip state yet

- [ ] **Step 3: Write minimal implementation**

```dart
final liveState = NavigationSessionService.instance.currentState;
final currentInstruction = liveState?.currentInstruction;
final progress = liveState?.progressFraction ?? 0;
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test --no-pub test/widget_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add saferoute/lib/screens/tab_guardian_screen.dart saferoute/lib/services/navigation_session_service.dart saferoute/test/widget_test.dart
git commit -m "feat: connect guardian mode to shared trip engine"
```

### Task 5: Harden SOS state transitions

**Files:**
- Modify: `saferoute/lib/services/supabase_service.dart`
- Modify: `saferoute/lib/screens/tab_guardian_screen.dart`
- Create: `saferoute/test/sos_flow_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
test('sos transitions active trip to sos_triggered state', () async {
  final nextStatus = deriveTripStatusAfterSos(currentStatus: 'active');
  expect(nextStatus, 'sos_triggered');
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test --no-pub test/sos_flow_test.dart`
Expected: FAIL because SOS trip-state helper does not exist yet

- [ ] **Step 3: Write minimal implementation**

```dart
String deriveTripStatusAfterSos({required String currentStatus}) {
  return currentStatus == 'completed' ? 'completed' : 'sos_triggered';
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test --no-pub test/sos_flow_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add saferoute/lib/services/supabase_service.dart saferoute/lib/screens/tab_guardian_screen.dart saferoute/test/sos_flow_test.dart
git commit -m "feat: harden sos trip state flow"
```

### Task 6: Final verification and local refresh

**Files:**
- Modify: `saferoute/lib/services/navigation_engine.dart`
- Modify: `saferoute/lib/services/navigation_session_service.dart`
- Modify: `saferoute/lib/screens/tab_plan_journey_screen.dart`
- Modify: `saferoute/lib/screens/tab_guardian_screen.dart`

- [ ] **Step 1: Run focused tests**

```bash
flutter test --no-pub test/navigation_engine_test.dart test/mapbox_service_test.dart test/plan_journey_route_option_test.dart test/sos_flow_test.dart test/bbmp_service_test.dart test/supabase_service_test.dart test/route_safety_engine_test.dart test/widget_test.dart
```

- [ ] **Step 2: Run targeted analysis**

```bash
flutter analyze lib/services/navigation_engine.dart lib/services/navigation_session_service.dart lib/services/mapbox_service.dart lib/screens/tab_plan_journey_screen.dart lib/screens/tab_guardian_screen.dart test/navigation_engine_test.dart test/mapbox_service_test.dart test/sos_flow_test.dart
```

- [ ] **Step 3: Refresh the local Flutter web app**

```bash
# Send hot restart to the running flutter session
```

- [ ] **Step 4: Manual smoke flow**

Run manual check:
- choose a route
- start trip
- verify current/next maneuver are visible
- verify guardian map follows the same trip
- trigger SOS
- verify emergency state is reflected

- [ ] **Step 5: Commit**

```bash
git add saferoute docs/superpowers/specs/2026-05-30-saferoute-navigation-guardian-sos-design.md docs/superpowers/plans/2026-05-30-saferoute-navigation-guardian-sos.md
git commit -m "feat: add live navigation core and guardian sos flow"
```
