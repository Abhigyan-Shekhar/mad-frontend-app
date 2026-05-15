# SafeRoute

SafeRoute is a modern, responsive web application designed for intelligent and secure navigation. It prioritizes user safety by providing real-time data on route conditions, lighting, emergency access, and incident alerts.

This repository contains the pure, zero-dependency static frontend for SafeRoute.

## Architecture

The project has been simplified from a complex React/Vite/TypeScript setup to a clean, fast, and easy-to-deploy static site using plain HTML, CSS, and Vanilla JavaScript.

- **Zero Build Step:** No `npm install`, no `vite build`, no `node_modules`.
- **Styling:** Uses Tailwind CSS via CDN.
- **Icons:** Uses Lucide Icons via CDN.
- **Animations:** Custom CSS animations defined in `style.css`.

## Pages Directory

The application consists of 4 main pages:

1. **`index.html` (Home)**
   - The landing page of the application.
   - Features quick navigation options, key statistics, and a live monitoring map snippet showing the active "Sentinel Protocol."
   - Warns users of any immediate SOS dead zones.

2. **`plan-journey.html` (Routes / Plan Journey)**
   - Allows users to compare different routes (e.g., "Well-lit Streets", "Standard Path", "Direct Route").
   - Highlights route duration, cell coverage status, and safety features.
   - Includes real-time warnings (e.g., no-service zones).

3. **`safety-score.html` (Safety Metrics)**
   - Displays a comprehensive "Route Safety Score" (0-100).
   - Breaks down safety metrics such as pothole reports, active streetlights, and recent theft incidents.
   - Provides live route forecasts and actionable recommendations based on current data.

4. **`guardian-mode.html` (Live Tracking & Guardian)**
   - An active trip monitoring dashboard.
   - Shows a live map with current position, upcoming hazards, SOS warnings, and accident alerts.
   - Includes quick action buttons to contact emergency services or share trip history.

## Development & Deployment

Because this is a pure static site, you don't need any special tools to run or deploy it:

- **Local Development:** Simply double-click `index.html` to open it in your browser, or use a basic local server (like VS Code Live Server or `python -m http.server`).
- **Deployment:** You can host this instantly on **GitHub Pages**, Vercel, Netlify, or any basic web server by simply uploading the files. No build configuration is required.