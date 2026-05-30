# SafeRoute Mobile Backend Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver a Supabase-backed Flutter MVP that uses Mapbox for routing and OpenCity/BBMP data for safety-aware trip planning and guardian tracking.

**Architecture:** Expand the SQL schema for safety intelligence, add typed Flutter service logic for route analysis and Supabase persistence, and wire the mobile screens to render richer route scoring, guardian status, and Bengaluru safety context. Keep the app functional when some enrichment data is unavailable.

**Tech Stack:** Flutter, Supabase, PostgreSQL, Supabase Realtime, Mapbox Directions/Geocoding APIs, OpenCity BBMP datasets

---

### Task 1: Add route-safety regression tests

**Files:**
- Create: `saferoute/test/route_safety_engine_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:saferoute/services/route_safety_engine.dart';

void main() {
  test('prefers safer route when hazard penalty is lower', () {
    final routeA = SafetyRouteInput(
      routeId: 'a',
      points: const [LatLng(12.0, 77.0), LatLng(12.01, 77.01)],
      baseScore: 80,
      hazards: const [
        RouteHazard(type: 'lighting', point: LatLng(12.0, 77.0)),
      ],
    );
    final routeB = SafetyRouteInput(
      routeId: 'b',
      points: const [LatLng(12.0, 77.0), LatLng(12.01, 77.02)],
      baseScore: 80,
      hazards: const [
        RouteHazard(type: 'theft', point: LatLng(12.0, 77.0)),
      ],
    );

    final ranked = RouteSafetyEngine.rank([routeA, routeB]);

    expect(ranked.first.routeId, 'a');
    expect(ranked.first.score, greaterThan(ranked.last.score));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test saferoute/test/route_safety_engine_test.dart`
Expected: FAIL because `route_safety_engine.dart` does not exist yet.

- [ ] **Step 3: Write minimal implementation**

Create `saferoute/lib/services/route_safety_engine.dart` with:

```dart
import 'package:latlong2/latlong.dart';

class RouteHazard {
  final String type;
  final LatLng point;

  const RouteHazard({required this.type, required this.point});
}

class SafetyRouteInput {
  final String routeId;
  final List<LatLng> points;
  final double baseScore;
  final List<RouteHazard> hazards;

  const SafetyRouteInput({
    required this.routeId,
    required this.points,
    required this.baseScore,
    required this.hazards,
  });
}

class RankedRoute {
  final String routeId;
  final double score;

  const RankedRoute({required this.routeId, required this.score});
}

class RouteSafetyEngine {
  static List<RankedRoute> rank(List<SafetyRouteInput> routes) {
    double penalty(String type) {
      switch (type) {
        case 'theft':
          return 14;
        case 'accident':
          return 12;
        case 'deadzone':
          return 10;
        case 'lighting':
          return 8;
        case 'pothole':
          return 6;
        default:
          return 5;
      }
    }

    final ranked = routes
        .map(
          (route) => RankedRoute(
            routeId: route.routeId,
            score: (route.baseScore -
                    route.hazards.fold<double>(
                      0,
                      (sum, hazard) => sum + penalty(hazard.type),
                    ))
                .clamp(0, 100)
                .toDouble(),
          ),
        )
        .toList();
    ranked.sort((a, b) => b.score.compareTo(a.score));
    return ranked;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test saferoute/test/route_safety_engine_test.dart`
Expected: PASS

### Task 2: Expand the Supabase schema for safety intelligence

**Files:**
- Modify: `supabase/schema.sql`

- [ ] **Step 1: Add ward, street, and route analysis tables with RLS-ready ownership**
- [ ] **Step 2: Add helper SQL functions/views for route analysis snapshots**
- [ ] **Step 3: Keep existing trip, hazard, and SOS behavior intact**

### Task 3: Add typed safety-analysis services in Flutter

**Files:**
- Create: `saferoute/lib/services/route_safety_engine.dart`
- Create: `saferoute/lib/services/safety_data_service.dart`
- Modify: `saferoute/lib/services/bbmp_service.dart`
- Modify: `saferoute/lib/services/supabase_service.dart`

- [ ] **Step 1: Introduce reusable route scoring helpers**
- [ ] **Step 2: Normalize BBMP grievance aggregation and fallback scoring**
- [ ] **Step 3: Add Supabase reads/writes for route analyses, ward scores, and street segments**

### Task 4: Wire the plan journey and safety screens to the richer data model

**Files:**
- Modify: `saferoute/lib/screens/tab_plan_journey_screen.dart`
- Modify: `saferoute/lib/screens/tab_safety_score_screen.dart`

- [ ] **Step 1: Use the route safety engine instead of duplicated scoring logic**
- [ ] **Step 2: Persist route analysis snapshots**
- [ ] **Step 3: Show route reasoning, ward context, and fallback states cleanly**

### Task 5: Improve guardian and home dashboard flows

**Files:**
- Modify: `saferoute/lib/screens/tab_guardian_screen.dart`
- Modify: `saferoute/lib/screens/tab_home_screen.dart`

- [ ] **Step 1: Surface active trip state, route analysis summary, and guardian readiness**
- [ ] **Step 2: Show Bengaluru ward/street safety context on the mobile dashboard**
- [ ] **Step 3: Keep the experience resilient when no active trip exists**

### Task 6: Verification

**Files:**
- Test: `saferoute/test/widget_test.dart`
- Test: `saferoute/test/route_safety_engine_test.dart`

- [ ] **Step 1: Run `flutter test`**
- [ ] **Step 2: Run `flutter analyze`**
- [ ] **Step 3: Summarize any remaining gaps honestly**
