# SafeRoute Static Screens

This folder contains a small linked prototype for SafeRoute built as standalone HTML files styled with Tailwind via CDN.

## Pages

- `index.html`: landing page
- `plan-your-journey.html`: route selection page
- `safety-score.html`: safety score dashboard
- `guardian-tracking.html`: live trip tracking and guardian mode

## Navigation Flow

- `index.html` links into route planning and guardian mode.
- `plan-your-journey.html` links into safety scoring and trip tracking.
- `safety-score.html` links back to route planning and forward to guardian mode.
- `guardian-tracking.html` links back across the rest of the flow.

Each page also includes a shared top navigation bar so you can move between all screens directly.

## Run

Open any of the HTML files directly in a browser, or serve the folder with a static server.

Example:

```bash
python3 -m http.server 8000
```

Then open `http://localhost:8000`.
