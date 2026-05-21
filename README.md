# SafeRoute

SafeRoute is a modern, mobile-first web application designed for intelligent and secure navigation. It prioritizes user safety by tracking live journeys, predicting hazards, and instantly alerting emergency contacts when needed.

## Architecture & Stack

SafeRoute is divided into two distinct components:

1. **Frontend (Static UI)**
   - Built with plain HTML, CSS, and Vanilla JS (zero build tools).
   - Styled with Tailwind CSS (via CDN) and Lucide Icons.
   - Hosted effortlessly on any static server (like GitHub Pages or Vercel).

2. **Backend (Supabase)**
   - Powered by a robust **Supabase PostgreSQL** database.
   - The backend schema (`supabase/schema.sql`) provides the complete foundation for the app's functionality:
     - **Profiles & Contacts:** Manage user accounts and emergency contacts.
     - **Live Tracking (Guardian Mode):** Uses Supabase Realtime to broadcast live GPS coordinates and speed.
     - **Hazards:** A community-driven system to report potholes, bad lighting, or dead zones.
     - **SOS Alerts:** A dedicated emergency trigger that instantly updates trip status and notifies guardians.
   - Fully secured using strict Row Level Security (RLS) policies.

## Project Structure

```text
mad-frontend-app/
├── supabase/
│   └── schema.sql       ← Full backend database schema & logic (Run this in Supabase)
├── index.html           ← Home page
├── plan-journey.html    ← Plan Journey & Route Selection
├── safety-score.html    ← Live Safety Metrics & Alerts
├── guardian-mode.html   ← Active Trip Tracking & SOS
└── style.css            ← Shared CSS animations
```

## Setup Instructions

### 1. The Frontend
Since there are no dependencies or build steps, simply open `index.html` in your browser or host the files on a static server.

### 2. The Backend
1. Create a free account at [Supabase](https://supabase.com).
2. Create a new project.
3. Open the **SQL Editor** in the Supabase dashboard.
4. Copy and paste the entire contents of `supabase/schema.sql` and click **Run**.
5. Your database, real-time broadcasts, triggers, and security policies will be instantly generated.