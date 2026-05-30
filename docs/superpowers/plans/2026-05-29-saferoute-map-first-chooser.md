# SafeRoute Map-First Chooser Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build an interactive multi-route map chooser that shows distinct route paths, route-specific safety scores, and lets the user start navigation with any selected route.

**Architecture:** Keep `MapboxService` as the route source and `SafetyDataService` as the scoring layer, while upgrading `TabPlanJourneyScreen` into a map-first route selection flow. The screen will maintain selected-route state, render all returned polylines, and persist only the selected route when a trip starts.

**Tech Stack:** Flutter, `flutter_map`, `latlong2`, Mapbox Directions API, Supabase, Flutter widget tests

---

### Task 1: Add route selection state tests

**Files:**
- Create: `saferoute/test/plan_journey_route_option_test.dart`
- Modify: `saferoute/lib/screens/tab_plan_journey_screen.dart`
- Test: `saferoute/test/plan_journey_route_option_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:saferoute/screens/tab_plan_journey_screen.dart';

void main() {
  test('defaults selected route to safest score', () {
    final routes = buildTestRouteOptions();
    final selected = defaultSelectedRouteId(routes);
    expect(selected, 'route-safe');
  });

  test('allows explicit route selection by id', () {
    final routes = buildTestRouteOptions();
    final selected = selectRouteId(routes, currentRouteId: 'route-safe', nextRouteId: 'route-fast');
    expect(selected, 'route-fast');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test --no-pub test/plan_journey_route_option_test.dart`
Expected: FAIL because helper methods do not exist yet

- [ ] **Step 3: Write minimal implementation**

```dart
String? defaultSelectedRouteId(List<RouteOptionData> routes) {
  if (routes.isEmpty) return null;
  return routes.first.route.id;
}

String? selectRouteId(
  List<RouteOptionData> routes, {
  required String? currentRouteId,
  required String nextRouteId,
}) {
  final exists = routes.any((route) => route.route.id == nextRouteId);
  return exists ? nextRouteId : currentRouteId;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test --no-pub test/plan_journey_route_option_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add saferoute/test/plan_journey_route_option_test.dart saferoute/lib/screens/tab_plan_journey_screen.dart
git commit -m "test: add route selection helpers"
```

### Task 2: Render the route map with all alternatives

**Files:**
- Modify: `saferoute/lib/screens/tab_plan_journey_screen.dart`
- Test: `saferoute/test/widget_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
testWidgets('renders route chooser map when routes are available', (tester) async {
  await tester.pumpWidget(buildPlanJourneyForTest(withRoutes: true));
  expect(find.byKey(const Key('route-chooser-map')), findsOneWidget);
  expect(find.byKey(const Key('selected-route-summary')), findsOneWidget);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test --no-pub test/widget_test.dart`
Expected: FAIL because the route chooser map keys are not present

- [ ] **Step 3: Write minimal implementation**

```dart
SizedBox(
  key: const Key('route-chooser-map'),
  height: 260,
  child: FlutterMap(...),
)

Container(
  key: const Key('selected-route-summary'),
  child: ...
)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test --no-pub test/widget_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add saferoute/lib/screens/tab_plan_journey_screen.dart saferoute/test/widget_test.dart
git commit -m "feat: render multi-route chooser map"
```

### Task 3: Add selectable route cards and selected-route emphasis

**Files:**
- Modify: `saferoute/lib/screens/tab_plan_journey_screen.dart`
- Test: `saferoute/test/widget_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
testWidgets('tapping a route card marks it selected', (tester) async {
  await tester.pumpWidget(buildPlanJourneyForTest(withRoutes: true));
  await tester.tap(find.text('Standard Path'));
  await tester.pumpAndSettle();
  expect(find.text('Selected route: Standard Path'), findsOneWidget);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test --no-pub test/widget_test.dart`
Expected: FAIL because selection state does not change yet

- [ ] **Step 3: Write minimal implementation**

```dart
void _selectRoute(String routeId) {
  setState(() {
    _selectedRouteId = selectRouteId(_routesData, currentRouteId: _selectedRouteId, nextRouteId: routeId);
  });
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test --no-pub test/widget_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add saferoute/lib/screens/tab_plan_journey_screen.dart saferoute/test/widget_test.dart
git commit -m "feat: add route selection cards"
```

### Task 4: Start trips from the selected route only

**Files:**
- Modify: `saferoute/lib/screens/tab_plan_journey_screen.dart`
- Modify: `saferoute/lib/services/safety_data_service.dart`
- Test: `saferoute/test/plan_journey_route_option_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
test('selected route payload is used for trip start', () {
  final route = buildTestRouteOptions().last;
  final payload = buildTripPayload(route);
  expect(payload.destinationName, route.destinationName);
  expect(payload.routeId, route.route.id);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test --no-pub test/plan_journey_route_option_test.dart`
Expected: FAIL because the payload helper does not exist yet

- [ ] **Step 3: Write minimal implementation**

```dart
TripStartPayload buildTripPayload(RouteOptionData route) {
  return TripStartPayload(
    routeId: route.route.id,
    destinationName: route.destinationName,
    start: route.route.points.first,
    end: route.route.points.last,
  );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test --no-pub test/plan_journey_route_option_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add saferoute/lib/screens/tab_plan_journey_screen.dart saferoute/lib/services/safety_data_service.dart saferoute/test/plan_journey_route_option_test.dart
git commit -m "feat: start trips from selected route"
```

### Task 5: Full verification and local refresh

**Files:**
- Modify: `saferoute/lib/screens/tab_plan_journey_screen.dart`
- Modify: `saferoute/test/plan_journey_route_option_test.dart`
- Modify: `saferoute/test/widget_test.dart`

- [ ] **Step 1: Run focused tests**

```bash
flutter test --no-pub test/plan_journey_route_option_test.dart test/widget_test.dart test/route_safety_engine_test.dart test/bbmp_service_test.dart test/supabase_service_test.dart
```

- [ ] **Step 2: Run targeted analysis**

```bash
flutter analyze lib/screens/tab_plan_journey_screen.dart lib/services/safety_data_service.dart test/plan_journey_route_option_test.dart
```

- [ ] **Step 3: Refresh the local Flutter web app**

```bash
# Send hot restart to the running flutter session
```

- [ ] **Step 4: Smoke-test the chooser**

Run manual check:
- enter a Bengaluru destination
- press `Find Best Routes`
- confirm map renders multiple visible paths
- confirm each route shows separate score/distance/time
- confirm tapping a different path changes the selected route

- [ ] **Step 5: Commit**

```bash
git add saferoute/lib/screens/tab_plan_journey_screen.dart saferoute/test/plan_journey_route_option_test.dart saferoute/test/widget_test.dart docs/superpowers/specs/2026-05-29-saferoute-map-first-chooser-design.md docs/superpowers/plans/2026-05-29-saferoute-map-first-chooser.md
git commit -m "feat: add map-first route chooser"
```
