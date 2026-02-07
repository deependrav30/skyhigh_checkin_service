#!/bin/bash
# Quick expiry test

API_URL="http://localhost:3002"
FLIGHT_ID="FL-123"
SEAT_ID="5E"
PASSENGER_ID="PEXPIRY"

echo "🧪 Testing Hold Expiry (120-second timeout)"
echo "=========================================="
echo ""

# Hold a seat
echo "Step 1: Holding seat $SEAT_ID..."
RESPONSE=$(curl -s -X POST "$API_URL/flights/$FLIGHT_ID/seats/$SEAT_ID/hold" \
  -H "Content-Type: application/json" \
  -d "{\"passengerId\":\"$PASSENGER_ID\"}")

if echo "$RESPONSE" | grep -q "holdId"; then
  echo "✅ Seat held successfully"
  echo "$RESPONSE" | head -3
else
  echo "❌ Failed to hold seat"
  echo "$RESPONSE"
  exit 1
fi

echo ""
echo "Step 2: Verifying seat is HELD..."
STATE=$(psql postgres://postgres:postgres@localhost:5434/skyhigh \
  -t -c "SELECT state FROM seats WHERE seat_id='$SEAT_ID';" | tr -d ' \n')
echo "Current state: $STATE"

if [ "$STATE" != "HELD" ]; then
  echo "❌ Expected HELD, got $STATE"
  exit 1
fi

echo ""
echo "Step 3: Waiting 125 seconds for expiry..."
for i in {125..1}; do
  printf "\r   Remaining: %3d seconds" $i
  sleep 1
done
echo ""

echo ""
echo "Step 4: Verifying seat was released..."
FINAL_STATE=$(psql postgres://postgres:postgres@localhost:5434/skyhigh \
  -t -c "SELECT state FROM seats WHERE seat_id='$SEAT_ID';" | tr -d ' \n')
echo "Final state: $FINAL_STATE"

if [ "$FINAL_STATE" = "AVAILABLE" ]; then
  echo "✅ TEST PASSED: Seat returned to AVAILABLE"
else
  echo "❌ TEST FAILED: Expected AVAILABLE, got $FINAL_STATE"
  exit 1
fi
