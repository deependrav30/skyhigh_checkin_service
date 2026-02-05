-- Seed Airbus A320neo realistic seat map for FL-123
-- Configuration: Business (Rows 1-3, 2-2) + Economy (Rows 4-15, 3-3)
-- Total: 12 Business + 72 Economy = 84 seats

-- Demo passengers with different IDs for testing
-- PNR Mapping: DEMO123->passenger-demo-1, DEMO456->passenger-demo-2, etc.
INSERT INTO checkins (passenger_id, flight_id, state, baggage_weight)
VALUES 
  ('DEMO123', 'FL-123', 'IN_PROGRESS', 0),
  ('DEMO456', 'FL-123', 'IN_PROGRESS', 0),
  ('DEMO789', 'FL-123', 'IN_PROGRESS', 0),
  ('DEMOA1B', 'FL-123', 'IN_PROGRESS', 0),
  ('DEMOC2D', 'FL-123', 'IN_PROGRESS', 0),
  ('DEMOE3F', 'FL-123', 'IN_PROGRESS', 0)
ON CONFLICT DO NOTHING;

-- Business Class: Rows 1-3 (2-2 configuration: A, C | D, F)
INSERT INTO seats (seat_id, flight_id, state, version) VALUES
  -- Row 1
  ('1A', 'FL-123', 'AVAILABLE', 0), ('1C', 'FL-123', 'AVAILABLE', 0),
  ('1D', 'FL-123', 'AVAILABLE', 0), ('1F', 'FL-123', 'AVAILABLE', 0),
  -- Row 2
  ('2A', 'FL-123', 'AVAILABLE', 0), ('2C', 'FL-123', 'AVAILABLE', 0),
  ('2D', 'FL-123', 'AVAILABLE', 0), ('2F', 'FL-123', 'AVAILABLE', 0),
  -- Row 3
  ('3A', 'FL-123', 'AVAILABLE', 0), ('3C', 'FL-123', 'AVAILABLE', 0),
  ('3D', 'FL-123', 'AVAILABLE', 0), ('3F', 'FL-123', 'AVAILABLE', 0),
  
  -- Economy Class: Rows 4-15 (3-3 configuration: A, B, C | D, E, F)
  -- Row 4
  ('4A', 'FL-123', 'AVAILABLE', 0), ('4B', 'FL-123', 'AVAILABLE', 0), ('4C', 'FL-123', 'AVAILABLE', 0),
  ('4D', 'FL-123', 'AVAILABLE', 0), ('4E', 'FL-123', 'AVAILABLE', 0), ('4F', 'FL-123', 'AVAILABLE', 0),
  -- Row 5
  ('5A', 'FL-123', 'AVAILABLE', 0), ('5B', 'FL-123', 'AVAILABLE', 0), ('5C', 'FL-123', 'AVAILABLE', 0),
  ('5D', 'FL-123', 'AVAILABLE', 0), ('5E', 'FL-123', 'AVAILABLE', 0), ('5F', 'FL-123', 'AVAILABLE', 0),
  -- Row 6
  ('6A', 'FL-123', 'AVAILABLE', 0), ('6B', 'FL-123', 'AVAILABLE', 0), ('6C', 'FL-123', 'AVAILABLE', 0),
  ('6D', 'FL-123', 'AVAILABLE', 0), ('6E', 'FL-123', 'AVAILABLE', 0), ('6F', 'FL-123', 'AVAILABLE', 0),
  -- Row 7
  ('7A', 'FL-123', 'AVAILABLE', 0), ('7B', 'FL-123', 'AVAILABLE', 0), ('7C', 'FL-123', 'AVAILABLE', 0),
  ('7D', 'FL-123', 'AVAILABLE', 0), ('7E', 'FL-123', 'AVAILABLE', 0), ('7F', 'FL-123', 'AVAILABLE', 0),
  -- Row 8
  ('8A', 'FL-123', 'AVAILABLE', 0), ('8B', 'FL-123', 'AVAILABLE', 0), ('8C', 'FL-123', 'AVAILABLE', 0),
  ('8D', 'FL-123', 'AVAILABLE', 0), ('8E', 'FL-123', 'AVAILABLE', 0), ('8F', 'FL-123', 'AVAILABLE', 0),
  -- Row 9
  ('9A', 'FL-123', 'AVAILABLE', 0), ('9B', 'FL-123', 'AVAILABLE', 0), ('9C', 'FL-123', 'AVAILABLE', 0),
  ('9D', 'FL-123', 'AVAILABLE', 0), ('9E', 'FL-123', 'AVAILABLE', 0), ('9F', 'FL-123', 'AVAILABLE', 0),
  -- Row 10
  ('10A', 'FL-123', 'AVAILABLE', 0), ('10B', 'FL-123', 'AVAILABLE', 0), ('10C', 'FL-123', 'AVAILABLE', 0),
  ('10D', 'FL-123', 'AVAILABLE', 0), ('10E', 'FL-123', 'AVAILABLE', 0), ('10F', 'FL-123', 'AVAILABLE', 0),
  -- Row 11
  ('11A', 'FL-123', 'AVAILABLE', 0), ('11B', 'FL-123', 'AVAILABLE', 0), ('11C', 'FL-123', 'AVAILABLE', 0),
  ('11D', 'FL-123', 'AVAILABLE', 0), ('11E', 'FL-123', 'AVAILABLE', 0), ('11F', 'FL-123', 'AVAILABLE', 0),
  -- Row 12
  ('12A', 'FL-123', 'AVAILABLE', 0), ('12B', 'FL-123', 'AVAILABLE', 0), ('12C', 'FL-123', 'AVAILABLE', 0),
  ('12D', 'FL-123', 'CONFIRMED', 0), ('12E', 'FL-123', 'AVAILABLE', 0), ('12F', 'FL-123', 'AVAILABLE', 0),
  -- Row 13
  ('13A', 'FL-123', 'AVAILABLE', 0), ('13B', 'FL-123', 'AVAILABLE', 0), ('13C', 'FL-123', 'AVAILABLE', 0),
  ('13D', 'FL-123', 'AVAILABLE', 0), ('13E', 'FL-123', 'AVAILABLE', 0), ('13F', 'FL-123', 'AVAILABLE', 0),
  -- Row 14
  ('14A', 'FL-123', 'AVAILABLE', 0), ('14B', 'FL-123', 'AVAILABLE', 0), ('14C', 'FL-123', 'AVAILABLE', 0),
  ('14D', 'FL-123', 'AVAILABLE', 0), ('14E', 'FL-123', 'AVAILABLE', 0), ('14F', 'FL-123', 'AVAILABLE', 0),
  -- Row 15
  ('15A', 'FL-123', 'AVAILABLE', 0), ('15B', 'FL-123', 'AVAILABLE', 0), ('15C', 'FL-123', 'AVAILABLE', 0),
  ('15D', 'FL-123', 'AVAILABLE', 0), ('15E', 'FL-123', 'AVAILABLE', 0), ('15F', 'FL-123', 'AVAILABLE', 0)
ON CONFLICT (seat_id, flight_id) DO NOTHING;
