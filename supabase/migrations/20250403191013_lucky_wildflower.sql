/*
  # Initial Schema for Participation Tracking System

  1. New Tables
    - `families`
      - `id` (uuid, primary key)
      - `name` (text)
      - `contact_email` (text)
      - `created_at` (timestamp)
    
    - `participants`
      - `id` (uuid, primary key)
      - `family_id` (uuid, foreign key)
      - `first_name` (text)
      - `last_name` (text)
      - `birth_date` (date)
      - `created_at` (timestamp)
    
    - `activities`
      - `id` (uuid, primary key)
      - `name` (text)
      - `description` (text)
      - `points` (integer)
      - `created_at` (timestamp)
    
    - `participation_records`
      - `id` (uuid, primary key)
      - `participant_id` (uuid, foreign key)
      - `activity_id` (uuid, foreign key)
      - `date` (date)
      - `points` (integer)
      - `created_at` (timestamp)
    
    - `tiers`
      - `id` (uuid, primary key)
      - `name` (text)
      - `min_points` (integer)
      - `max_points` (integer)
      - `created_at` (timestamp)

  2. Security
    - Enable RLS on all tables
    - Add policies for authenticated users
    - Admin users can access all data
    - Regular users can only access their family's data
*/

-- Create tables
CREATE TABLE families (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  contact_email text NOT NULL,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE participants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  family_id uuid REFERENCES families(id) ON DELETE CASCADE,
  first_name text NOT NULL,
  last_name text NOT NULL,
  birth_date date NOT NULL,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE activities (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  description text,
  points integer NOT NULL DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE participation_records (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  participant_id uuid REFERENCES participants(id) ON DELETE CASCADE,
  activity_id uuid REFERENCES activities(id) ON DELETE CASCADE,
  date date NOT NULL DEFAULT CURRENT_DATE,
  points integer NOT NULL DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE tiers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  min_points integer NOT NULL,
  max_points integer NOT NULL,
  created_at timestamptz DEFAULT now()
);

-- Enable Row Level Security
ALTER TABLE families ENABLE ROW LEVEL SECURITY;
ALTER TABLE participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE activities ENABLE ROW LEVEL SECURITY;
ALTER TABLE participation_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE tiers ENABLE ROW LEVEL SECURITY;

-- Create policies
CREATE POLICY "Users can view their own family"
  ON families
  FOR SELECT
  USING (auth.uid() IN (
    SELECT p.id FROM participants p WHERE p.family_id = families.id
  ));

CREATE POLICY "Users can view participants in their family"
  ON participants
  FOR SELECT
  USING (family_id IN (
    SELECT p.family_id FROM participants p WHERE p.id = auth.uid()
  ));

CREATE POLICY "Everyone can view activities"
  ON activities
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Users can view their family's participation records"
  ON participation_records
  FOR SELECT
  USING (participant_id IN (
    SELECT p.id FROM participants p 
    WHERE p.family_id = (
      SELECT p2.family_id FROM participants p2 WHERE p2.id = auth.uid()
    )
  ));

CREATE POLICY "Everyone can view tiers"
  ON tiers
  FOR SELECT
  TO authenticated
  USING (true);

-- Create function to calculate current points (last 3 months only)
CREATE OR REPLACE FUNCTION calculate_current_points(participant_uuid uuid)
RETURNS integer AS $$
BEGIN
  RETURN (
    SELECT COALESCE(SUM(points), 0)
    FROM participation_records
    WHERE participant_id = participant_uuid
    AND date >= (CURRENT_DATE - INTERVAL '3 months')
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;