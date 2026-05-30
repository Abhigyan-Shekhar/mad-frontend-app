# SafeRoute Navigation, Guardian, and SOS Design

**Goal**

Upgrade SafeRoute from a route chooser with safety scoring into a Google-Maps-like live navigation product with integrated guardian tracking and reliable SOS state handling.

**Why This Exists**

The app already supports:

- route alternatives
- route safety scoring
- selected-route persistence
- guardian trip state
- live location pings
- SOS alert creation

But these pieces still behave like adjacent features, not one coherent navigation system. The missing layer is a shared live trip engine that powers route progress, step advancement, rerouting, guardian visibility, and SOS status from one source of truth.

**Approved Product Direction**

The app will be implemented as one product program with two linked delivery tracks:

1. `Navigation Core`
2. `Guardian + SOS Reliability`

They share a single active trip engine and trip state model.

## Scope

### In Scope

- live follow-my-location navigation mode
- selected route as the active route of record
- current-step progression using Mapbox route steps
- next maneuver and route progress UI
- off-route detection and reroute flow
- arrival detection and clean trip completion
- guardian screen driven from live trip state
- SOS tied to active trip and latest known location
- Supabase persistence for navigation, tracking, and emergency state

### Out of Scope for This Phase

- voice guidance
- background-native navigation behavior matching full mobile OS navigation apps
- push notifications to real guardian devices
- full production-grade map tilting or lane guidance

## Architecture

### Shared Trip Engine

Introduce one dedicated navigation/trip controller as the source of truth for:

- active trip id
- active selected route
- route step list
- current step index
- current user location
- route progress
- off-route state
- reroute state
- arrival state
- guardian-visible live trip state
- SOS lifecycle state

This engine should be the only place that interprets live movement against the route.

### Service Responsibilities

#### `MapboxService`

Continues to own:

- geocoding
- reverse geocoding
- alternative route retrieval
- route geometry
- route step parsing
- reroute requests

#### `SupabaseService`

Continues to own:

- trips
- location pings
- SOS alerts
- hazards
- emergency contacts
- route analysis snapshots

It should be extended only where persistence is necessary for the active trip state.

#### Navigation Engine

Owns runtime interpretation:

- matching the current position to the active route
- deciding when the current step is complete
- computing next maneuver
- estimating route progress
- deciding if the user is off-route
- triggering reroute requests
- deciding when arrival has occurred

## User Experience

### Trip Planning

- user enters a destination
- app fetches 2 to 3 route alternatives
- each route has:
  - map path
  - safety score
  - ETA
  - distance
  - hazard count
  - short route-step preview
- user can select a route by:
  - tapping a card
  - tapping a route line on the map

### Start Navigation

When the user starts navigation:

- the chosen route becomes the active route
- the app enters live navigation mode
- current position is tracked against the selected route
- current step and next step are shown clearly
- the map follows the user location by default

### In-Trip Navigation

During navigation:

- the current step advances automatically
- the next maneuver updates from live location
- route progress is visible
- off-route state is detected with a configurable threshold
- if off-route, the app fetches a reroute and rescored alternatives
- the rerouted path becomes the new active route only after a successful update

### Guardian Experience

Guardian mode should reflect the same active trip state, not reconstruct it separately.

It should show:

- current route path
- current location
- destination
- ETA
- progress
- route hazard context
- trip status
- SOS status

### SOS Experience

SOS is tied to the current active trip.

When triggered:

- the latest known location is attached
- the active trip is marked as `sos_triggered`
- guardian-facing views reflect the emergency state
- the UI clearly distinguishes:
  - ready
  - sending
  - sent
  - resolved

### End Trip

Trip end occurs by:

- arrival detection
- manual user action

On trip end:

- trip is marked completed
- live tracking stops
- navigation state is cleared
- guardian screen falls back to the latest completed trip summary

## Screen-Level Design

### Plan Journey

Responsible for:

- route discovery
- route comparison
- route selection
- trip start
- short turn preview before navigation begins

### Dedicated Navigation State

The app should have a true in-trip navigation experience. This may live as a dedicated screen or a strongly differentiated in-trip mode within the existing route flow, but it must present:

- follow-mode map
- current maneuver
- next maneuver
- progress
- reroute state
- quick access to guardian and SOS actions

### Guardian Screen

Responsible for:

- live follower view
- route path visibility
- destination and ETA
- current ping status
- emergency state
- trip controls where appropriate

### Safety Screen

Responsible for:

- active route risk context
- live and saved route safety interpretation
- hazard summaries

It should read from active trip state when a trip is running.

## Data Model Changes

The current schema remains the base, with extensions for active navigation behavior.

### Likely Additions

- active route id on trip state
- route step snapshot or serialized route guidance
- current step index
- progress fraction
- off-route flag
- reroute counter or status
- arrival timestamp or arrival state

These additions can live either in:

- Supabase trip records
- route analysis snapshots
- or a new active trip state table if runtime state persistence needs stronger separation

The preferred direction is minimal schema expansion unless runtime state persistence clearly needs a separate table.

## Reliability Rules

- route selection must remain stable during tracking until reroute succeeds
- guardian state must always derive from the same live trip state as navigation
- SOS must never rely on stale route-only data when live ping data exists
- missing BBMP or street cache data must not block navigation
- Mapbox route or reroute failures must degrade gracefully instead of breaking the trip

## Testing Strategy

### Unit Tests

- step parsing from Mapbox response
- step progression
- progress computation
- off-route threshold logic
- reroute replacement logic
- arrival detection
- SOS state transitions

### Widget Tests

- route selection persistence
- selected-route maneuver panel
- in-trip navigation state presentation
- guardian live trip state rendering

### Manual Verification

1. choose destination
2. compare routes
3. select route by map line
4. start trip
5. verify current step and next step appear
6. verify guardian reflects movement
7. trigger SOS
8. resolve or end trip
9. verify completed-trip fallback behavior

## Delivery Order

### Phase 1: Navigation Core

- active trip engine
- step progression
- current maneuver UI
- route progress
- off-route detection
- reroute handling
- arrival handling

### Phase 2: Guardian + SOS Reliability

- guardian state driven from active trip engine
- stronger live tracking polish
- SOS lifecycle state
- trip recovery and completion polish

## Success Criteria

- route selection feels like a real navigation app
- active trip state advances as the user moves
- guardian mode shows the same live trip truth as navigation
- SOS is attached to the active route and location state
- trips start, track, reroute, and end cleanly
- the app feels materially closer to a real consumer navigation experience
