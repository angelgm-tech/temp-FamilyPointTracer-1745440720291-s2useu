/*
  # Initial Database Schema for Participation Tracking System

  1. New Tables
    - families: Stores family information
    - participants: Stores participant information with family relationships
    - activities: Stores activity definitions and point values
    - participation_records: Tracks participation and points
    - tiers: Defines point thresholds for different tiers
    - point_expirations: Tracks point expiration dates

  2. Security
    - Enable RLS on all tables
    - Add policies for authenticated users to view their own data
    - Add policies for admins to manage all data

  3. Initial Data
    - Insert initial tier definitions
*/

-- Create families table
CREATE TABLE IF NOT EXISTS families (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  contact_email text,
  contact_phone text,
  notes text,
  created_at timestamptz DEFAULT now()
);

-- Create participants table
CREATE TABLE IF NOT EXISTS participants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  family_id uuid REFERENCES families(id) ON DELETE CASCADE,
  first_name text NOT NULL,
  last_name text NOT NULL,
  email text,
  phone text,
  total_points integer DEFAULT 0,
  current_tier text DEFAULT 'Tier 1',
  created_at timestamptz DEFAULT now()
);

-- Create activities table
CREATE TABLE IF NOT EXISTS activities (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  activity_date date NOT NULL,
  points_value integer NOT NULL,
  category text,
  description text,
  created_at timestamptz DEFAULT now()
);

-- Create participation_records table
CREATE TABLE IF NOT EXISTS participation_records (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  participant_id uuid REFERENCES participants(id) ON DELETE CASCADE,
  activity_id uuid REFERENCES activities(id) ON DELETE CASCADE,
  points_earned integer NOT NULL,
  participation_date date NOT NULL,
  is_expired boolean DEFAULT false,
  expiration_date date,
  created_at timestamptz DEFAULT now()
);

-- Create tiers table
CREATE TABLE IF NOT EXISTS tiers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  min_points integer NOT NULL,
  max_points integer DEFAULT 2147483647,
  created_at timestamptz DEFAULT now()
);

-- Create point_expirations table
CREATE TABLE IF NOT EXISTS point_expirations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  expiration_date date NOT NULL,
  description text,
  created_at timestamptz DEFAULT now()
);

-- Enable Row Level Security
ALTER TABLE families ENABLE ROW LEVEL SECURITY;
ALTER TABLE participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE activities ENABLE ROW LEVEL SECURITY;
ALTER TABLE participation_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE tiers ENABLE ROW LEVEL SECURITY;
ALTER TABLE point_expirations ENABLE ROW LEVEL SECURITY;

-- Create policies for families
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'families' 
    AND policyname = 'Users can view their own family'
  ) THEN
    CREATE POLICY "Users can view their own family"
      ON families
      FOR SELECT
      TO authenticated
      USING (
        id IN (
          SELECT p.family_id 
          FROM participants p 
          WHERE p.id = auth.uid()
        )
      );
  END IF;
END $$;

-- Create policies for participants
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'participants' 
    AND policyname = 'Users can view participants in their family'
  ) THEN
    CREATE POLICY "Users can view participants in their family"
      ON participants
      FOR SELECT
      TO authenticated
      USING (
        family_id IN (
          SELECT p.family_id 
          FROM participants p 
          WHERE p.id = auth.uid()
        )
      );
  END IF;
END $$;

-- Create policies for activities
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'activities' 
    AND policyname = 'Everyone can view activities'
  ) THEN
    CREATE POLICY "Everyone can view activities"
      ON activities
      FOR SELECT
      TO authenticated
      USING (true);
  END IF;
END $$;

-- Create policies for participation_records
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'participation_records' 
    AND policyname = 'Users can view their family''s participation records'
  ) THEN
    CREATE POLICY "Users can view their family's participation records"
      ON participation_records
      FOR SELECT
      TO authenticated
      USING (
        participant_id IN (
          SELECT p.id 
          FROM participants p 
          WHERE p.family_id = (
            SELECT p2.family_id 
            FROM participants p2 
            WHERE p2.id = auth.uid()
          )
        )
      );
  END IF;
END $$;

-- Create policies for tiers
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'tiers' 
    AND policyname = 'Everyone can view tiers'
  ) THEN
    CREATE POLICY "Everyone can view tiers"
      ON tiers
      FOR SELECT
      TO authenticated
      USING (true);
  END IF;
END $$;

-- Create policies for point_expirations
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'point_expirations' 
    AND policyname = 'Everyone can view point expirations'
  ) THEN
    CREATE POLICY "Everyone can view point expirations"
      ON point_expirations
      FOR SELECT
      TO authenticated
      USING (true);
  END IF;
END $$;

-- Insert initial tier data if not exists
INSERT INTO tiers (name, min_points, max_points)
SELECT name, min_points, COALESCE(max_points, 2147483647)
FROM (VALUES
  ('Tier 1', 0, 5),
  ('Tier 2', 6, 11),
  ('Tier 3', 12, 18),
  ('Tier 4', 19, 2147483647)
) AS new_tiers(name, min_points, max_points)
WHERE NOT EXISTS (
  SELECT 1 FROM tiers
  WHERE name = new_tiers.name
);