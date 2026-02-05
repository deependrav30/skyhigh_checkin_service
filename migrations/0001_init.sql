-- Schema initialization

CREATE TABLE IF NOT EXISTS schema_migrations (
  version TEXT PRIMARY KEY,
  applied_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS seats (
  seat_id TEXT NOT NULL,
  flight_id TEXT NOT NULL,
  state TEXT NOT NULL CHECK (state IN ('AVAILABLE','HELD','CONFIRMED','CANCELLED')),
  held_by TEXT,
  hold_expires_at TIMESTAMPTZ,
  version INT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (seat_id, flight_id)
);

CREATE TABLE IF NOT EXISTS seat_events (
  event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  seat_id TEXT NOT NULL,
  flight_id TEXT NOT NULL,
  event_type TEXT NOT NULL,
  actor TEXT,
  metadata JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS waitlist (
  waitlist_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  flight_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  seat_preferences JSONB,
  status TEXT NOT NULL DEFAULT 'QUEUED' CHECK (status IN ('QUEUED','ASSIGNED')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS payment_intents (
  intent_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  checkin_id TEXT NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('pending','succeeded','failed')),
  amount NUMERIC(10,2) DEFAULT 0,
  currency TEXT DEFAULT 'USD',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS checkins (
  checkin_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  passenger_id TEXT NOT NULL,
  flight_id TEXT NOT NULL,
  state TEXT NOT NULL CHECK (state IN ('IN_PROGRESS','WAITING_FOR_PAYMENT','COMPLETED')),
  baggage_weight NUMERIC(6,2),
  payment_intent_id UUID,
  CONSTRAINT fk_payment_intent FOREIGN KEY (payment_intent_id) REFERENCES payment_intents(intent_id)
);
