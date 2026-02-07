#!/bin/bash
# Test: Multiple users trying to hold the same seat
# Expected: Only 1 success, rest fail

set -e

API_URL="http://localhost:3002"
FLIGHT_ID="FL-123"
SEAT_ID="1A"
NUM_ATTEMPTS=100

echo "🧪 Testing Concurrent Hold Requests"
echo "=================================="
echo "Target: $API_URL"
echo "Flight: $FLIGHT_ID, Seat: $SEAT_ID"
echo "Concurrent attempts: $NUM_ATTEMPTS"
echo ""

# Create temp files for results
SUCCESS_FILE=$(mktemp)
FAIL_FILE=$(mktemp)

echo "Starting concurrent requests..."
for i in $(seq 1 $NUM_ATTEMPTS); do
  (
    RESPONSE=$(curl -s -X POST "$API_URL/api/seats/hold" \
      -H "Content-Type: application/json" \
      -d "{\"flightId\":\"$FLIGHT_ID\",\"seatId\":\"$SEAT_ID\",\"passengerId\":\"P$i\"}" \
      2>&1)
    
    if echo "$RESPONSE" | grep -q "holdId"; then
      echo "SUCCESS: P$i got the seat" >> "$SUCCESS_FILE"
    else
      echo "FAIL: P$i" >> "$FAIL_FILE"
    fi
  ) &
done

# Wait for all background jobs
wait

echo ""
echo "📊 Results:"
echo "==========="

SUCCESS_COUNT=$(wc -l < "$SUCCESS_FILE" | tr -d ' ')
FAIL_COUNT=$(wc -l < "$FAIL_FILE" | tr -d ' ')

echo "✅ Successful holds: $SUCCESS_COUNT"
echo "❌ Failed holds: $FAIL_COUNT"
echo ""

if [ "$SUCCESS_COUNT" -eq 1 ]; then
  echo "✅ TEST PASSED: Exactly 1 hold succeeded"
  echo ""
  echo "Winner:"
  cat "$SUCCESS_FILE"
else
  echo "❌ TEST FAILED: Expected 1 success, got $SUCCESS_COUNT"
  echo ""
  echo "Successful holds:"
  cat "$SUCCESS_FILE"
fi

# Cleanup
rm -f "$SUCCESS_FILE" "$FAIL_FILE"

echo ""
echo "Verifying seat state in database..."
psql postgres://postgres:postgres@localhost:5434/skyhigh \
  -c "SELECT seat_id, state, held_by, hold_expires_at FROM seats WHERE seat_id='$SEAT_ID';"
