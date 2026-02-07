#!/bin/bash
# Test: Verify holds expire after 120 seconds
# Expected: Seat becomes AVAILABLE again

set -e

API_URL="http://localhost:3002"
FLIGHT_ID="FL-123"
SEAT_ID="5B"
PASSENGER_ID="PTEST"

echo "🧪 Testing Hold Expiry"
echo "====================="
echo ""

# Step 1: Hold a seat
echo "Step 1: Holding seat $SEAT_ID..."
RESPONSE=$(curl -s -X POST "$API_URL/api/seats/hold" \
  -H "Content-Type: application/json" \
  -d "{\"flightId\":\"$FLIGHT_ID\",\"seatId\":\"$SEAT_ID\",\"passengerId\":\"$PASSENGER_ID\"}")

if echo "$RESPONSE" | grep -q "holdId"; then
  HOLD_ID=$(echo "$RESPONSE" | grep -o '"holdId":"[^"]*"' | cut -d'"' -f4)
  EXPIRES_AT=$(echo "$RESPONSE" | grep -o '"holdExpiresAt":"[^"]*"' | cut -d'"' -f4)
  echo "✅ Seat held successfully"
  echo "   Hold ID: $HOLD_ID"
  echo "   Expires at: $EXPIRES_AT"
else
  echo "❌ Failed to hold seat"
  echo "$RESPONSE"
  exit 1
fi

echo ""

# Step 2: Verify seat is HELD
echo "Step 2: Verifying seat state..."
psql postgres://postgres:postgres@localhost:5434/skyhigh \
  -t -c "SELECT state FROM seats WHERE seat_id='$SEAT_ID';" | tr -d ' '

CURRENT_STATE=$(psql postgres://postgres:postgres@localhost:5434/skyhigh \
  -t -c "SELECT state FROM seats WHERE seat_id='$SEAT_ID';" | tr -d ' ' | tr -d '\n')

if [ "$CURRENT_STATE" = "HELD" ]; then
  echo "✅ Seat is HELD"
else
  echo "❌ Expected HELD, got $CURRENT_STATE"
  exit 1
fi

echo ""

# Step 3: Wait for expiry
echo "Step 3: Waiting for expiry (125 seconds to account for worker interval)..."
for i in {125..1}; do
  printf "\r   Remaining: %3d seconds" $i
  sleep 1
done
echo ""
echo ""

# Step 4: Verify seat is AVAILABLE
echo "Step 4: Verifying seat was released..."
FINAL_STATE=$(psql postgres://postgres:postgres@localhost:5434/skyhigh \
  -t -c "SELECT state FROM seats WHERE seat_id='$SEAT_ID';" | tr -d ' ' | tr -d '\n')

if [ "$FINAL_STATE" = "AVAILABLE" ]; then
  echo "✅ Seat is AVAILABLE again"
else
  echo "❌ Expected AVAILABLE, got $FINAL_STATE"
  exit 1
fi

echo ""

# Step 5: Check event log
echo "Step 5: Checking event log..."
psql postgres://postgres:postgres@localhost:5434/skyhigh \
  -c "SELECT event_type, actor, created_at 
      FROM seat_events 
      WHERE seat_id='$SEAT_ID' 
      ORDER BY created_at DESC 
      LIMIT 2;"

echo ""
echo "✅ TEST PASSED: Hold expired correctly"
