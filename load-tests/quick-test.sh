#!/bin/bash
# Quick concurrent test with 20 requests

API_URL="http://localhost:3002"
FLIGHT_ID="FL-123"
SEAT_ID="1D"
NUM_ATTEMPTS=20

SUCCESS=0
FAIL=0

echo "🧪 Testing Concurrent Hold Requests ($NUM_ATTEMPTS concurrent)"
echo "=============================================================="
echo "Target: $API_URL"
echo "Seat: $SEAT_ID"
echo ""

for i in $(seq 1 $NUM_ATTEMPTS); do
  (
    RESPONSE=$(curl -s -X POST "$API_URL/flights/$FLIGHT_ID/seats/$SEAT_ID/hold" \
      -H "Content-Type: application/json" \
      -d "{\"passengerId\":\"P$i\"}")
    
    if echo "$RESPONSE" | grep -q "holdId"; then
      echo "✓ P$i succeeded"
    else
      echo "✗ P$i failed"
    fi
  ) &
done

wait

echo ""
echo "Verifying final state..."
psql postgres://postgres:postgres@localhost:5434/skyhigh \
  -c "SELECT seat_id, state, held_by FROM seats WHERE seat_id='$SEAT_ID';"
