export interface Family {
  id: string;
  name: string;
  contact_email: string;
  created_at: string;
}

export interface Participant {
  id: string;
  family_id: string;
  first_name: string;
  last_name: string;
  birth_date: string;
  created_at: string;
}

export interface Activity {
  id: string;
  name: string;
  description: string | null;
  points: number;
  created_at: string;
}

export interface ParticipationRecord {
  id: string;
  participant_id: string;
  activity_id: string;
  date: string;
  points: number;
  created_at: string;
}

export interface Tier {
  id: string;
  name: string;
  min_points: number;
  max_points: number;
  created_at: string;
}