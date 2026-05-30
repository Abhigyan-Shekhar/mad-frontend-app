# SafeRoute Map-First Chooser Design

**Goal**

Upgrade the journey planner so users can see multiple map routes, compare their safety scores, and choose any route before starting navigation.

**Problem**

The current Flutter route flow fetches alternative Mapbox routes and scores them, but the UI still behaves like a simple route card list. Users cannot clearly see the different paths on a live map, compare them visually, or confidently choose one route for their trip.

**Approved Direction**

Use a map-first chooser:

- Show up to three Mapbox route alternatives on one interactive map.
- Render each route with its own color and safety rank.
- Let the user select a route from either the map or the route cards.
- Show distinct safety score, ETA, distance, hazard summary, and location context for each route.
- Start the trip using the explicitly selected route.

**Architecture**

The feature stays inside the existing Flutter app and extends the current route planning pipeline:

- `MapboxService` remains the source of route alternatives and route geometry.
- `SafetyDataService` remains responsible for route scoring and route-specific hazard matching.
- `TabPlanJourneyScreen` becomes the main orchestration point for map rendering, route selection state, and trip start.

No backend contract changes are required for the core chooser. Existing Supabase persistence is reused for saving the chosen route analysis snapshot when a trip starts.

**UI Structure**

The plan screen will render in this order:

1. Existing origin/destination inputs
2. `Find Best Routes` action
3. Interactive route map
4. Selected route summary
5. Route option cards

The route map should:

- Fit all returned routes in view
- Show origin and destination markers
- Show all route polylines at once
- Emphasize the selected route with stronger stroke weight and opacity
- Fade non-selected routes but keep them visible

The route option cards should:

- Show safety rank and route label
- Show score, duration, and distance
- Show hazard count and route context
- Clearly indicate which route is selected
- Allow tap-to-select

**Selection Model**

- The safest ranked route is selected by default after results load.
- Selecting a route updates:
  - highlighted polyline on the map
  - selected detail summary
  - active `Start Navigation` action target
- Starting a trip uses the selected route geometry and analysis only.

**Scoring Model**

Each route keeps its own:

- route geometry
- duration
- distance
- matched nearby hazards
- safety score
- explanation/highlights
- ward and street context

The screen must not collapse multiple route options into a single shared score.

**Fallback Behavior**

- If Supabase safety cache tables are missing, route planning still works.
- If BBMP/OpenCity data is unavailable, route scoring falls back to neutral/default safety scoring.
- If Mapbox returns only one route, the chooser still renders a single selectable route cleanly.
- If a route has no geometry, it is not selectable.

**Testing**

Add tests for:

- selected route defaults to the safest route
- selecting another route updates the chosen route state
- route summaries keep separate score and hazard metadata

**Success Criteria**

- Users can see different map directions on the plan screen.
- Users can compare safety scores across different route paths.
- Users can choose any route before starting navigation.
- Starting navigation persists the chosen route, not just the top-ranked route.
