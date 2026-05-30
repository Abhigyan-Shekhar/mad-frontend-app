-- ==========================================
-- SafeRoute Supabase Database Schema
-- ==========================================

-- Enable PostGIS extension for geographic queries (useful for finding hazards near a user)
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ==========================================
-- 1. Profiles Table
-- ==========================================
CREATE TABLE public.profiles (
    id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    full_name TEXT,
    phone_number TEXT,
    avatar_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- RLS Policies
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view their own profile" ON public.profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can update their own profile" ON public.profiles FOR UPDATE USING (auth.uid() = id);

-- Trigger to automatically create a profile when a new user signs up
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name)
  VALUES (new.id, new.raw_user_meta_data->>'full_name');
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();


-- ==========================================
-- 2. Emergency Contacts Table
-- ==========================================
CREATE TABLE public.emergency_contacts (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    contact_name TEXT NOT NULL,
    phone_number TEXT NOT NULL,
    is_primary BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- RLS Policies
ALTER TABLE public.emergency_contacts ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage their own contacts" ON public.emergency_contacts 
    FOR ALL USING (auth.uid() = user_id);


-- ==========================================
-- 3. Trips Table (Guardian Mode)
-- ==========================================
CREATE TYPE trip_status AS ENUM ('planned', 'active', 'completed', 'cancelled', 'sos_triggered');

CREATE TABLE public.trips (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    start_lat DOUBLE PRECISION NOT NULL,
    start_lng DOUBLE PRECISION NOT NULL,
    end_lat DOUBLE PRECISION NOT NULL,
    end_lng DOUBLE PRECISION NOT NULL,
    destination_name TEXT,
    status trip_status DEFAULT 'planned',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    ended_at TIMESTAMP WITH TIME ZONE
);

-- RLS Policies
ALTER TABLE public.trips ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage their own trips" ON public.trips 
    FOR ALL USING (auth.uid() = user_id);


-- ==========================================
-- 4. Location Pings Table (Real-time Tracking)
-- ==========================================
-- This table is optimized for Supabase Realtime to broadcast live locations.
CREATE TABLE public.location_pings (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    trip_id UUID REFERENCES public.trips(id) ON DELETE CASCADE NOT NULL,
    lat DOUBLE PRECISION NOT NULL,
    lng DOUBLE PRECISION NOT NULL,
    speed DOUBLE PRECISION, -- km/h
    battery_level INTEGER, -- optional: to warn guardians if phone is dying
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable Realtime for location pings
ALTER PUBLICATION supabase_realtime ADD TABLE public.location_pings;

-- RLS Policies
ALTER TABLE public.location_pings ENABLE ROW LEVEL SECURITY;
-- For the MVP, we allow the trip owner to insert/read. 
-- In a production app, you might use Edge Functions or signed tokens to let non-user Guardians read this.
CREATE POLICY "Users can insert pings for their trips" ON public.location_pings 
    FOR INSERT WITH CHECK (
        EXISTS (SELECT 1 FROM public.trips WHERE id = trip_id AND user_id = auth.uid())
    );
CREATE POLICY "Users can view their own trip pings" ON public.location_pings 
    FOR SELECT USING (
        EXISTS (SELECT 1 FROM public.trips WHERE id = trip_id AND user_id = auth.uid())
    );


-- ==========================================
-- 5. Hazards / Safety Reports Table
-- ==========================================
CREATE TYPE hazard_type AS ENUM ('pothole', 'lighting', 'theft', 'accident', 'deadzone');

CREATE TABLE public.hazards (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    reporter_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    hazard_type hazard_type NOT NULL,
    lat DOUBLE PRECISION NOT NULL,
    lng DOUBLE PRECISION NOT NULL,
    description TEXT,
    is_active BOOLEAN DEFAULT true,
    upvotes INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable Realtime for hazards (so users see new hazards immediately)
ALTER PUBLICATION supabase_realtime ADD TABLE public.hazards;

-- RLS Policies
ALTER TABLE public.hazards ENABLE ROW LEVEL SECURITY;
-- Anyone authenticated can read hazards
CREATE POLICY "Anyone can view active hazards" ON public.hazards FOR SELECT USING (is_active = true);
-- Users can report hazards
CREATE POLICY "Users can report hazards" ON public.hazards FOR INSERT WITH CHECK (auth.uid() = reporter_id);


-- ==========================================
-- 6. SOS Alerts Table
-- ==========================================
CREATE TABLE public.sos_alerts (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    trip_id UUID REFERENCES public.trips(id) ON DELETE CASCADE, -- Optional, SOS can happen outside a trip
    lat DOUBLE PRECISION NOT NULL,
    lng DOUBLE PRECISION NOT NULL,
    is_resolved BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    resolved_at TIMESTAMP WITH TIME ZONE
);

-- Enable Realtime for SOS Alerts
ALTER PUBLICATION supabase_realtime ADD TABLE public.sos_alerts;

-- RLS Policies
ALTER TABLE public.sos_alerts ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage their own SOS alerts" ON public.sos_alerts 
    FOR ALL USING (auth.uid() = user_id);

-- Trigger to automatically update trip status if an SOS is triggered during an active trip
CREATE OR REPLACE FUNCTION public.mark_trip_sos()
RETURNS trigger AS $$
BEGIN
  IF NEW.trip_id IS NOT NULL THEN
    UPDATE public.trips SET status = 'sos_triggered' WHERE id = NEW.trip_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_sos_alert_created
  AFTER INSERT ON public.sos_alerts
  FOR EACH ROW EXECUTE PROCEDURE public.mark_trip_sos();

-- ==========================================
-- 7. Ward Safety Scores (BBMP-derived safety intelligence)
-- ==========================================
CREATE TABLE IF NOT EXISTS public.ward_safety_scores (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    ward_name TEXT NOT NULL UNIQUE,
    total_grievances INTEGER DEFAULT 0 NOT NULL,
    road_grievances INTEGER DEFAULT 0 NOT NULL,
    light_grievances INTEGER DEFAULT 0 NOT NULL,
    safety_score DOUBLE PRECISION DEFAULT 70 NOT NULL,
    source_year TEXT,
    source_dataset TEXT DEFAULT 'bbmp_grievances',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.ward_safety_scores ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can read ward safety scores" ON public.ward_safety_scores
    FOR SELECT USING (auth.role() = 'authenticated');

-- ==========================================
-- 8. Street Segments (OpenCity street map enrichment)
-- ==========================================
CREATE TABLE IF NOT EXISTS public.street_segments (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    ward_name TEXT NOT NULL,
    ward_number TEXT,
    street_id TEXT NOT NULL,
    street_name TEXT,
    source_url TEXT,
    geometry_wkt TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE (ward_name, street_id)
);

ALTER TABLE public.street_segments ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can read street segments" ON public.street_segments
    FOR SELECT USING (auth.role() = 'authenticated');

-- ==========================================
-- 9. Route Analyses (saved route scoring snapshots)
-- ==========================================
CREATE TABLE IF NOT EXISTS public.route_analyses (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    trip_id UUID REFERENCES public.trips(id) ON DELETE CASCADE,
    route_id TEXT NOT NULL,
    destination_name TEXT,
    ward_name TEXT,
    street_summary TEXT,
    score DOUBLE PRECISION NOT NULL,
    base_score DOUBLE PRECISION NOT NULL,
    hazard_penalty DOUBLE PRECISION DEFAULT 0 NOT NULL,
    coverage TEXT NOT NULL,
    highlights JSONB DEFAULT '[]'::jsonb NOT NULL,
    hazard_types JSONB DEFAULT '[]'::jsonb NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.route_analyses ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage their own route analyses" ON public.route_analyses
    FOR ALL USING (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_route_analyses_user_created_at
    ON public.route_analyses (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_ward_safety_scores_safety_score
    ON public.ward_safety_scores (safety_score ASC);

CREATE INDEX IF NOT EXISTS idx_street_segments_ward_name
    ON public.street_segments (ward_name);

-- ==========================================
-- 10. Updated At helper trigger
-- ==========================================
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger AS $$
BEGIN
  NEW.updated_at = timezone('utc'::text, now());
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS set_updated_at_ward_safety_scores ON public.ward_safety_scores;
CREATE TRIGGER set_updated_at_ward_safety_scores
  BEFORE UPDATE ON public.ward_safety_scores
  FOR EACH ROW EXECUTE PROCEDURE public.set_updated_at();

DROP TRIGGER IF EXISTS set_updated_at_street_segments ON public.street_segments;
CREATE TRIGGER set_updated_at_street_segments
  BEFORE UPDATE ON public.street_segments
  FOR EACH ROW EXECUTE PROCEDURE public.set_updated_at();
