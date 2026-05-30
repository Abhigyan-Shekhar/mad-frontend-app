# SafeRoute Mobile Backend Design

## Goal

Build a presentable Flutter mobile app backed by Supabase that supports authentication, trip planning, safety-aware route ranking, live guardian tracking, SOS, and Bengaluru-specific safety intelligence using Mapbox plus OpenCity/BBMP data.

## Architecture

- Flutter is the primary client application.
- Supabase provides auth, PostgreSQL storage, realtime updates, and row-level security.
- Mapbox provides geocoding, directions, and route geometry for navigation.
- OpenCity street-map and BBMP grievance datasets provide safety enrichment and route scoring inputs.

## Core Product Areas

### 1. Identity And Profile

- Users sign up and sign in with Supabase Auth.
- A profile row is created automatically for each auth user.
- Users can manage emergency contacts tied to their own account.

### 2. Trip Planning And Safety Ranking

- The app geocodes the destination with Mapbox.
- The app fetches alternative directions from Mapbox.
- Each candidate route is scored using:
  - Mapbox route geometry
  - Nearby live hazards stored in Supabase
  - Cached BBMP grievance risk by ward/street area
  - Safety penalties for hazard categories such as theft, lighting, dead zones, and potholes
- The app surfaces the safest route first while still showing alternates.

### 3. Guardian Mode And Realtime Tracking

- Starting a trip creates a trip record and the initial location ping.
- While a trip is active, device location is streamed into Supabase `location_pings`.
- Realtime subscriptions update guardian mode and live trip state in the app.
- SOS creates an emergency record and flips the trip state to `sos_triggered`.

### 4. Bengaluru Safety Intelligence

- OpenCity/BBMP data is treated as a safety intelligence layer, not the routing engine.
- The database stores normalized safety signals for wards and route segments.
- The app uses those signals to show:
  - route safety score
  - ward risk summary
  - hazard counts and recommendations
  - a more informative mobile dashboard

## Data Design

The existing schema is expanded to support:

- `profiles`
- `emergency_contacts`
- `trips`
- `location_pings`
- `hazards`
- `sos_alerts`
- `ward_safety_scores`
- `street_segments`
- `route_analyses`

`ward_safety_scores` stores derived complaint metrics from the BBMP grievance dataset. `street_segments` stores imported OpenCity street map metadata used to label and enrich routes. `route_analyses` stores per-trip or per-route safety scoring snapshots so mobile screens can render consistent summaries.

## Error Handling

- Missing environment keys should fail fast with a clear configuration screen.
- Network-dependent operations should show retryable UI states.
- If Mapbox routing fails, the app should still be able to show direct-trip fallback data and hazard summaries.
- If BBMP/OpenCity enrichment is unavailable, the app should fall back to hazard-only scoring instead of blocking the trip flow.

## Testing Strategy

- Add focused Dart tests for route scoring and safety aggregation behavior.
- Keep widget coverage for the configuration error flow.
- Run `flutter test` and `flutter analyze` after implementation.

## Security

- Mobile code uses only `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `MAPBOX_PUBLIC_KEY`.
- Service-role credentials must not be embedded in the Flutter app.
- Database access remains guarded by RLS.

## Delivery Scope

This build targets a coherent MVP that is presentable on mobile and complete enough to demo:

- auth
- route planning
- live guardian mode
- SOS
- emergency contacts
- route safety scoring
- BBMP/OpenCity-backed safety summaries
