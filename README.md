# SafeRoute Static Screens

This folder contains a small linked prototype for SafeRoute built as standalone HTML files styled with Tailwind via CDN.

## Pages

- `index.html`: landing page
- `plan-your-journey.html`: route selection page
- `safety-score.html`: safety score dashboard
- `guardian-tracking.html`: live trip tracking and guardian mode

## Key Features

- Safer route comparison
- Safety score based on potholes, roadlights, and theft
- Guardian mode with live trip tracking
- Accident notifications on the route
- SOS deadzone warning for long stretches with poor or zero cellular coverage

Each page also includes a shared top navigation bar so you can move between all screens directly.

## Cellular Deadzone Warning

The prototype now includes a frontend concept for a cellular coverage risk layer:

- Faster routes can be flagged if they enter a long no-service stretch.
- Slower routes can be preferred when they preserve full SOS coverage.
- Guardian mode surfaces the deadzone warning during live trip tracking.

This is intended to represent a future integration with route-coordinate analysis and cell tower density data.

## Run

Open any of the HTML files directly in a browser, or serve the folder with a static server.

Example:

```bash
python3 -m http.server 8000
```

Then open `http://localhost:8000`.
