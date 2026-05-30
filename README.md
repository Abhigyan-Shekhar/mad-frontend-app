# SafeRoute 🛡️

**Smart Safety Navigation for Bengaluru** — A cross-platform mobile app (Flutter) that helps users navigate safely using real-time community hazards, BBMP civic data, Mapbox routing, and live guardian tracking.

---

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Mobile App (Flutter)](#mobile-app-flutter)
  - [Tech Stack](#tech-stack)
  - [Project Structure](#project-structure)
  - [Screens](#screens)
  - [Services Layer](#services-layer)
  - [State Management](#state-management)
- [Backend (Supabase)](#backend-supabase)
  - [Database Schema](#database-schema)
  - [Realtime Features](#realtime-features)
  - [Row-Level Security](#row-level-security)
- [Web Prototype (HTML/JS)](#web-prototype-htmljs)
- [External APIs](#external-apis)
- [Environment Variables](#environment-variables)
- [Getting Started](#getting-started)
- [Running Tests](#running-tests)
- [Data Pipeline](#data-pipeline)

---

## Overview

SafeRoute is a safety-first navigation app built for urban commuters in Bengaluru. It combines:

- **BBMP Grievance Data** — Real civic complaints (potholes, lighting, road issues) aggregated by ward to compute ward-level safety scores.
- **Mapbox Directions API** — Fetches up to 3 alternative routes between origin and destination.
- **Community Hazard Reporting** — Users report hazards (theft, accidents, deadzones, potholes, lighting) that are stored in Supabase and broadcast to other users in real time.
- **Guardian Mode** — Live GPS location sharing to emergency contacts during a trip, with SOS alerting.
- **Route Safety Engine** — Scores and ranks all candidate routes based on ward safety, reported hazards, and route exposure, then recommends the safest path.

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                  Flutter Mobile App                     │
│  ┌──────────┐ ┌──────────────┐ ┌──────────────────────┐│
│  │  Screens │ │   Services   │ │   Navigation Engine  ││
│  │  (4 tabs)│ │  (8 files)   │ │ (step + session)     ││
│  └──────────┘ └──────────────┘ └──────────────────────┘│
└───────────────────────┬─────────────────────────────────┘
                        │
         ┌──────────────┼───────────────┐
         ▼              ▼               ▼
   ┌───────────┐  ┌──────────┐  ┌─────────────────┐
   │  Supabase │  │  Mapbox  │  │  OpenCity (BBMP)│
   │ (Postgres │  │Directions│  │  Grievance Data │
   │ + Auth +  │  │Geocoding │  │  (opencity.in)  │
   │ Realtime) │  │  API     │  └─────────────────┘
   └───────────┘  └──────────┘
```

---

## Mobile App (Flutter)

### Tech Stack

| Category | Technology |
|---|---|
| Framework | Flutter (Dart) — SDK `^3.12.0` |
| Backend-as-a-Service | Supabase Flutter `^2.12.4` |
| Maps | `flutter_map ^8.3.0` + OpenStreetMap tiles |
| Routing | Mapbox Directions API (via `http ^1.6.0`) |
| Geocoding | Mapbox Geocoding API + Nominatim OSM fallback |
| Location | `geolocator ^13.0.0` |
| Fonts | Google Fonts — Inter (`google_fonts ^6.2.1`) |
| Animations | `flutter_animate ^4.5.0` |
| CSV Parsing | `csv ^6.0.0` |
| Sharing | `share_plus ^10.1.4` |
| URL Launching | `url_launcher ^6.3.2` |
| Config | `flutter_dotenv ^6.0.1` |

### Project Structure

```
saferoute/
├── lib/
│   ├── main.dart                        # App entry point, theme, Supabase init
│   ├── home_screen.dart                 # Bottom navigation host (4 tabs)
│   ├── screens/
│   │   ├── splash_screen.dart           # Auth gate + animated splash
│   │   ├── auth_screen.dart             # Sign In / Sign Up forms
│   │   ├── home_screen.dart             # Tab: Home dashboard
│   │   ├── tab_home_screen.dart         # Live monitoring, BBMP risk watch
│   │   ├── tab_plan_journey_screen.dart # Route planning + live navigation
│   │   ├── tab_safety_score_screen.dart # Animated safety score display
│   │   └── tab_guardian_screen.dart     # Guardian mode + SOS + contacts
│   ├── services/
│   │   ├── app_config.dart              # Reads .env via flutter_dotenv
│   │   ├── supabase_service.dart        # All Supabase CRUD + Realtime
│   │   ├── mapbox_service.dart          # Geocoding, reverse geocoding, routing
│   │   ├── bbmp_service.dart            # OpenCity BBMP data + ward scoring
│   │   ├── safety_data_service.dart     # Route ranking orchestration
│   │   ├── route_safety_engine.dart     # Pure scoring algorithm
│   │   ├── navigation_engine.dart       # Step tracking + off-route detection
│   │   ├── navigation_session_service.dart # ValueNotifier session state
│   │   └── location_service.dart        # Geolocator wrapper
│   └── widgets/
│       └── saferoute_appbar.dart        # Shared SliverAppBar widget
├── test/
│   ├── bbmp_service_test.dart
│   ├── mapbox_service_test.dart
│   ├── navigation_engine_test.dart
│   ├── navigation_session_service_test.dart
│   ├── plan_journey_route_option_test.dart
│   ├── route_safety_engine_test.dart
│   ├── sos_flow_test.dart
│   └── supabase_service_test.dart
├── bin/
│   └── sync_safety_data.dart            # CLI: syncs BBMP ward scores to Supabase
├── pubspec.yaml
└── .env                                 # Local secrets (not committed)
```

### Screens

#### 1. Home Tab (`tab_home_screen.dart`)
- Hero section with "Your safest route, every time" CTA
- Live stats cards: **Trips**, **Alerts**, **Guardians** (pulled from Supabase)
- Interactive mini Bengaluru map showing current GPS position
- **Sentinel Protocol** status — shows active community hazards count
- **BBMP Risk Watch** — top 3 highest-risk wards by safety score
- Latest saved route analysis card (destination + score + ward context)
- SOS Deadzone Alert banner showing active deadzone count

#### 2. Plan Journey Tab (`tab_plan_journey_screen.dart`)
- Location auto-detection via `geolocator` + Mapbox reverse geocoding
- Destination search field with Mapbox geocoding (OSM Nominatim fallback)
- Fetches up to 3 alternative routes from Mapbox Directions API
- Passes routes through `SafetyDataService` → `RouteSafetyEngine` to rank by safety score
- **Interactive map** (`flutter_map`) with color-coded polylines:
  - 🟢 Green = score ≥ 78 (Full coverage)
  - 🟡 Amber = score ≥ 60 (Partial)
  - 🔴 Red = score < 60 (Risk)
- Tap-to-select routes on the map (via `LayerHitNotifier`)
- Route cards showing: rank label, score, ETA, distance, hazard highlights, ward context
- **Start Navigation** → creates Supabase trip, saves route analysis snapshot, begins GPS tracking
- **Live Navigation Panel** — turn-by-turn instructions, progress bar, current step, next step
- **Auto-reroute** — detects off-route (>90m deviation) and fetches new route from current position

#### 3. Safety Score Tab (`tab_safety_score_screen.dart`)
- Animated circular progress indicator showing live route score (0–100)
- Color-coded: 🟢 ≥70, 🟡 ≥50, 🔴 <50
- Hazard breakdown cards: Potholes / Lighting Issues / Theft Incidents
- **Route Visualization** — custom `Canvas`-painted route path on a dark gradient background
- Route Forecast and Recommendation alert cards
- **Bengaluru Context** card — ward name + street summary from Supabase
- Share route via native share sheet (`share_plus`)
- Falls back to latest saved `route_analyses` record when no active trip

#### 4. Guardian Tab (`tab_guardian_screen.dart`)
- **Start / End Trip** — geocodes destination, creates Supabase trip record
- Live map (`flutter_map`) with polyline route + start/end/position markers
- **LIVE badge** pulsing green dot when trip is active
- Real-time location streaming — sends GPS pings to `location_pings` table every position update
- Trip stats panel: elapsed time, speed, distance to destination, ETA, coverage status
- Live turn-by-turn navigation instruction from `NavigationSessionService`
- **SOS Button** — triggers `sos_alerts` insert + marks trip as `sos_triggered`
- Emergency Contacts management (add / delete, call, SMS with location link)
- **Hazard Reporting** — in-app dialog to report pothole / lighting / theft / accident / deadzone at current GPS coords
- Supabase Realtime subscription for new hazards — shows snackbar alert immediately

### Services Layer

#### `supabase_service.dart`
Singleton service wrapping all Supabase interactions:

| Method | Description |
|---|---|
| `signIn / signUp / signOut` | Auth via `supabase_flutter` |
| `getMyProfile()` | Fetches `profiles` table row |
| `startTrip / endTrip / getActiveTrip` | Trip lifecycle management |
| `sendLocationPing` | Inserts into `location_pings` |
| `listenToTripPings(tripId)` | Realtime stream of latest ping |
| `triggerSOS / resolveSOS` | SOS alert lifecycle |
| `reportHazard / getActiveHazards` | Community hazard CRUD |
| `listenForNewHazards` | Realtime `INSERT` subscription |
| `addEmergencyContact / deleteEmergencyContact` | Guardian contacts CRUD |
| `saveRouteAnalysis / getLatestRouteAnalysis` | Route scoring persistence |
| `getWardSafetyScores / upsertWardSafetyScores` | Ward score cache table |
| `getStreetSegments / upsertStreetSegments` | Street data table |

#### `mapbox_service.dart`
Singleton wrapping Mapbox REST APIs:

| Method | Description |
|---|---|
| `geocode(query, proximity)` | Forward geocode with OSM Nominatim fallback |
| `reverseGeocode(point)` | Converts LatLng → human-readable address |
| `directions(start, end)` | Fetches up to 3 routes with full GeoJSON + step instructions |
| `geocodeMatchScore(query, label)` | Token-weighted fuzzy score for best result selection |

#### `bbmp_service.dart`
Fetches BBMP civic grievance data from **OpenCity.in**:
- Queries `datastore_search_sql` against dataset `1342a93b-...` for open grievances grouped by ward and category
- **Safety Score formula**: `score = 100 - min(total_grievances / 2, 50)` → range [50, 100]
- Tallies `road_grievances` (pothole/footpath keywords) and `light_grievances` (street light/electricity keywords)
- **10-minute in-memory cache** — loads from Supabase `ward_safety_scores` first; falls back to live OpenCity API fetch, then upserts results back to Supabase
- Fuzzy ward matching (case-insensitive substring match)

#### `route_safety_engine.dart`
Pure stateless scoring algorithm (no I/O):

| Hazard Type | Penalty |
|---|---|
| Theft | -14 pts |
| Accident | -12 pts |
| Deadzone | -10 pts |
| Lighting | -8 pts |
| Pothole | -6 pts |
| Other | -5 pts |

- **Exposure penalty**: extra points docked if route is longer/slower than shortest option (capped at -10 pts total)
- **Coverage labels**: Full (≥78), Partial (≥55), Risk (<55)
- Routes sorted by descending final score

#### `navigation_engine.dart`
Pure static step-tracking logic:
- `evaluate(route, currentStepIndex, currentLocation)` → `NavigationState`
- Off-route threshold: **90 m** from nearest route point
- Arrival threshold: **35 m** from destination
- Step advance threshold: **45 m** from next step target
- Returns: `currentStepIndex`, `isOffRoute`, `hasArrived`, `progressFraction`

#### `navigation_session_service.dart`
`ValueNotifier`-based session manager for live navigation:
- `activateRoute` / `updateWithLocation` / `applyReroute`
- `markRerouting` / `cancelRerouting`
- `markEmergencyActive` / `resolveEmergency`
- `currentInstruction` / `nextInstruction` accessors

#### `safety_data_service.dart`
Orchestration layer composing BBMP, Supabase, and Route Safety Engine:
- `rankRoutes(routes, originLabel, destinationLabel, activeHazards)` → `List<RouteSafetyBundle>`
- Fetches base ward score from BBMP, hazards near each route (350m corridor), street segments for context
- `saveAnalysisSnapshot(...)` → persists ranked route data to `route_analyses` table

### State Management

SafeRoute uses **Flutter's built-in state management**:
- `StatefulWidget` + `setState` for screen-level state
- `ValueNotifier<NavigationSessionSnapshot?>` for cross-screen live navigation state (observed via `ValueListenableBuilder`)
- `StreamSubscription` for Supabase Realtime pings and device GPS stream
- `RealtimeChannel` for Supabase Realtime hazard inserts

---

## Backend (Supabase)

### Database Schema

Located at [`supabase/schema.sql`](supabase/schema.sql). Apply to any Supabase project.

#### Tables

| Table | Purpose |
|---|---|
| `public.profiles` | User profiles; auto-created via trigger on `auth.users` insert |
| `public.emergency_contacts` | Guardian contacts per user (name, phone, is_primary) |
| `public.trips` | Trip records with start/end coordinates, status, and timestamps |
| `public.location_pings` | GPS pings during active trips (lat, lng, speed, battery_level) |
| `public.hazards` | Community-reported hazards (type, coordinates, description, upvotes) |
| `public.sos_alerts` | SOS events with coordinates, linked trip, and resolution status |
| `public.ward_safety_scores` | Cached BBMP-derived ward safety data (scores, grievance counts) |
| `public.street_segments` | OpenCity street map data enrichment by ward |
| `public.route_analyses` | Saved route scoring snapshots per trip (score, highlights, hazard types) |

#### Trip Status Enum
```sql
CREATE TYPE trip_status AS ENUM ('planned', 'active', 'completed', 'cancelled', 'sos_triggered');
```

#### Hazard Type Enum
```sql
CREATE TYPE hazard_type AS ENUM ('pothole', 'lighting', 'theft', 'accident', 'deadzone');
```

#### Database Triggers

| Trigger | Table | Effect |
|---|---|---|
| `on_auth_user_created` | `auth.users` | Auto-creates `profiles` row with `full_name` from metadata |
| `on_sos_alert_created` | `sos_alerts` | Updates linked `trips.status` → `'sos_triggered'` |
| `set_updated_at_ward_safety_scores` | `ward_safety_scores` | Auto-updates `updated_at` on row change |
| `set_updated_at_street_segments` | `street_segments` | Auto-updates `updated_at` on row change |

#### Extensions
```sql
CREATE EXTENSION IF NOT EXISTS postgis;   -- Geographic queries
CREATE EXTENSION IF NOT EXISTS "uuid-ossp"; -- UUID generation
```

### Realtime Features

Three tables are added to `supabase_realtime` publication:

| Table | Realtime Use |
|---|---|
| `location_pings` | Guardian sees live traveller position updates |
| `hazards` | All users see new community hazard reports immediately |
| `sos_alerts` | SOS broadcast to guardians / emergency logic |

### Row-Level Security

All tables have RLS enabled with granular policies:

| Table | Policy |
|---|---|
| `profiles` | Users can only SELECT/UPDATE their own row |
| `emergency_contacts` | Full CRUD only for owning user |
| `trips` | Full CRUD only for owning user |
| `location_pings` | INSERT/SELECT restricted to owner of the linked trip |
| `hazards` | Any authenticated user can SELECT active hazards; INSERT restricted to reporter |
| `sos_alerts` | Full CRUD only for owning user |
| `ward_safety_scores` | SELECT for all authenticated users |
| `street_segments` | SELECT for all authenticated users |
| `route_analyses` | Full CRUD only for owning user |

---

## Web Prototype (HTML/JS)

The root directory contains the original HTML prototype pages that served as the design reference for the Flutter app:

| File | Description |
|---|---|
| `index.html` | Landing page / onboarding |
| `login.html` | Auth page |
| `plan-journey.html` | Route planning UI prototype |
| `guardian-mode.html` | Guardian / live tracking prototype |
| `safety-score.html` | Safety score visualization prototype |
| `auth.js` | Supabase JS auth helpers |
| `style.css` | Base styles |

The Flutter app is a pixel-faithful implementation of these HTML designs as a native mobile app, using the same color palette (`slate-800`, `emerald-500`, `gray-50`), typography (Inter), and component hierarchy.

> **Note:** These HTML files are design references and the web prototype. The production app is the Flutter app inside `saferoute/`.

---

## External APIs

### Mapbox
- **Geocoding v5** — `GET /geocoding/v5/mapbox.places/{query}.json`
  - Country biased to `IN`
  - Proximity bias to current GPS location
  - Falls back to OpenStreetMap Nominatim on low-confidence results
- **Directions v5** — `GET /directions/v5/mapbox/driving/{coords}`
  - Up to 3 `alternatives`
  - Full GeoJSON geometry (`overview=full`)
  - Turn-by-turn `steps`

### OpenCity BBMP Data
- **Endpoint:** `https://data.opencity.in/api/3/action/datastore_search_sql`
- **Dataset ID:** `1342a93b-9a61-4766-9c34-c8357b7926c2`
- SQL aggregates open grievances by ward and category (road, lighting)
- Used to compute ward-level safety scores cached in Supabase

### OpenStreetMap Tiles
- Tile URL: `https://tile.openstreetmap.org/{z}/{x}/{y}.png`
- Used by `flutter_map` for the in-app map display

---

## Environment Variables

### `saferoute/.env` (Flutter app)

```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
MAPBOX_PUBLIC_KEY=pk.your-mapbox-public-key
```

> The `.env` file is declared as a Flutter asset in `pubspec.yaml` and loaded at startup via `flutter_dotenv`. **Never commit your real keys.** Use `.env.example` as a template.

### Root `.env` (Web prototype)

```env
SUPABASE_URL=...
SUPABASE_ANON_KEY=...
MAPBOX_PUBLIC_KEY=...
```

---

## Getting Started

### Prerequisites
- Flutter SDK `>=3.12.0`
- A [Supabase](https://supabase.com) project
- A [Mapbox](https://mapbox.com) account with a public access token

### 1. Clone the repository

```bash
git clone https://github.com/Abhigyan-Shekhar/mad-frontend-app.git
cd mad-frontend-app
```

### 2. Set up the database

In your Supabase project SQL editor, run:

```bash
# Copy the full schema
cat supabase/schema.sql
```

Paste and execute it in the Supabase SQL editor.

### 3. Configure environment

```bash
cd saferoute
cp .env.example .env
# Fill in your Supabase URL, keys, and Mapbox token
```

### 4. Install dependencies

```bash
cd saferoute
flutter pub get
```

### 5. Run the app

```bash
flutter run
```

For a specific platform:
```bash
flutter run -d android
flutter run -d ios
flutter run -d chrome   # Web preview
```

---

## Running Tests

```bash
cd saferoute
flutter test
```

### Test Coverage

| Test File | What It Covers |
|---|---|
| `bbmp_service_test.dart` | Ward score parsing, caching, fuzzy matching |
| `mapbox_service_test.dart` | Geocode match scoring, route parsing |
| `navigation_engine_test.dart` | Off-route detection, step advancement, arrival |
| `navigation_session_service_test.dart` | Session lifecycle, reroute, emergency state |
| `plan_journey_route_option_test.dart` | Route option selection, map hit handling, trip payload |
| `route_safety_engine_test.dart` | Hazard penalties, exposure penalty, coverage labels |
| `sos_flow_test.dart` | SOS status derivation logic |
| `supabase_service_test.dart` | Table guard error handling, fallback behaviour |

---

## Data Pipeline

The `bin/sync_safety_data.dart` CLI script syncs ward safety scores from OpenCity directly into Supabase:

```bash
cd saferoute
dart bin/sync_safety_data.dart
```

This is useful for pre-populating `ward_safety_scores` before the mobile app's lazy-loading cache kicks in.

---

## Color Palette

| Token | Hex | Usage |
|---|---|---|
| Slate 800 | `#1E293B` | Primary buttons, appbar text |
| Emerald 500 | `#10B981` | Safe route, live indicator |
| Gray 50 | `#F9FAFB` | Scaffold background |
| Gray 900 | `#111827` | Body text |
| Red 500 | `#EF4444` | SOS, errors, high-risk routes |
| Amber 500 | `#F59E0B` | Warnings, medium-risk routes |
| Blue 600 | `#2563EB` | Guardian mode accent |

---

## License

See [`ATTRIBUTIONS.md`](ATTRIBUTIONS.md) for third-party attributions.

---

*Built with ❤️ for safer streets in Bengaluru.*