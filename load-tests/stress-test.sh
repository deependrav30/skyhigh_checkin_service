#!/bin/bash

# High-concurrency stress test for Business Scenario 2.3
# Tests conflict-free seat assignment under extreme load

set -e

FLIGHT_ID="FL-123"
SEAT_ID="8D"  # Target seat for all concurrent requests
CONCURRENT_REQUESTS=100  # Stress test with 100 concurrent users
API_URL="http://localhost:3002"
DB_CONNECTION="postgres://postgres:postgres@localhost:5434/skyhigh"

echo "=== Business Scenario 2.3: Conflict-Free Seat Assignment ==="
echo "Configuration:"
echo "  Flight: $FLIGHT_ID"
echo "  Target Seat: $SEAT_ID"
echo "  Concurrent Requests: $CONCURRENT_REQUESTS"
echo ""

# Step 1: Ensure seat is available
echo "Step 1: Ensuring seat $SEAT_ID is AVAILABLE..."
psql "$DB_CONNECTION" -c "UPDATE seats SET state='AVAILABLE', held_by=NULL, hold_expires_at=NULL WHERE flight_id='$FLIGHT_ID' AND seat_id='$SEAT_ID';" > /dev/null

INITIAL_STATE=$(psql "$DB_CONNECTION" -t -c "SELECT state FROM seats WHERE flight_id='$FLIGHT_ID' AND seat_id='$SEAT_ID';")
echo "✅ Initial state: $INITIAL_STATE"
echo ""

# Step 2: Launch concurrent hold requests
echo "Step 2: Launching $CONCURRENT_REQUESTS concurrent hold requests..."
TEMP_DIR=$(mktemp -d)
SUCCESS_FILE="$TEMP_DIR/success.txt"
FAIL_FILE="$TEMP_DIR/fail.txt"

for i in $(seq 1 $CONCURRENT_REQUESTS); do
  (
    PASSENGER_ID="P$(printf '%03d' $i)"
    RESPONSE=$(curl -s -X POST "$API_URL/flights/$FLIGHT_ID/seats/$SEAT_ID/hold" \
      -H "Content-Type: application/json" \
      -d "{\"passengerId\":\"$PASSENGER_ID\"}")
    
    if echo "$RESPONSE" | grep -q '"holdId"'; then
      echo "$PASSENGER_ID succeeded" >> "$SUCCESS_FILE"
    else
      echo "$PASSENGER_ID failed" >> "$FAIL_FILE"
    fi
  ) &
done

# Wait for all background processes
wait

echo "✅ All requests completed"
echo ""

# Step 3: Analyze results
echo "Step 3: Analyzing results..."
echo ""

SUCCESS_COUNT=0
FAIL_COUNT=0

if [ -f "$SUCCESS_FILE" ]; then
  SUCCESS_COUNT=$(wc -l < "$SUCCESS_FILE")
  echo "=== Successful Requests ==="
  cat "$SUCCESS_FILE"
  echo ""
fi

if [ -f "$FAIL_FILE" ]; then
  FAIL_COUNT=$(wc -l < "$FAIL_FILE")
  echo "=== Failed Requests (first 10) ==="
  head -10 "$FAIL_FILE"
  if [ $FAIL_COUNT -gt 10 ]; then
    echo "... and $(($FAIL_COUNT - 10)) more failures"
  fi
  echo ""
fi

echo "=== Summary ==="
echo "Total Requests: $CONCURRENT_REQUESTS"
echo "Successes: $SUCCESS_COUNT"
echo "Failures: $FAIL_COUNT"
echo "Success Rate: $(echo "scale=2; $SUCCESS_COUNT * 100 / $CONCURRENT_REQUESTS" | bc)%"
echo ""

# Step 4: Database verification
echo "Step 4: Database verification..."
DB_STATE=$(psql "$DB_CONNECTION" -t -c "SELECT seat_id, state, held_by FROM seats WHERE flight_id='$FLIGHT_ID' AND seat_id='$SEAT_ID';")
echo "$DB_STATE"
echo ""

# Step 5: Check for duplicate assignments (critical!)
echo "Step 5: Checking for duplicate assignments..."
DUPLICATE_CHECK=$(psql "$DB_CONNECTION" -t -c "
  SELECT COUNT(DISTINCT held_by) as holders, COUNT(*) as records 
  FROM seats 
  WHERE flight_id='$FLIGHT_ID' AND seat_id='$SEAT_ID' AND state='HELD';
")
HOLDERS=$(echo "$DUPLICATE_CHECK" | awk '{print $1}')
RECORDS=$(echo "$DUPLICATE_CHECK" | awk '{print $3}')

if [ "$HOLDERS" -le 1 ] && [ "$RECORDS" -eq 1 ]; then
  echo "✅ No duplicate assignments detected"
else
  echo "❌ CRITICAL: Duplicate assignment detected!"
  echo "   Holders: $HOLDERS, Records: $RECORDS"
  exit 1
fi
echo ""

# Step 6: Validate test result
echo "Step 6: Validating test result..."
if [ "$SUCCESS_COUNT" -eq 1 ]; then
  echo "✅ TEST PASSED: Exactly 1 passenger successfully held the seat"
  echo "   Expected behavior: Only 1 success out of $CONCURRENT_REQUESTS concurrent requests"
  echo "   Conflict-free seat assignment is working correctly!"
elif [ "$SUCCESS_COUNT" -eq 0 ]; then
  echo "⚠️  TEST INCONCLUSIVE: No passenger succeeded (possible rate limiting)"
  echo "   Try reducing CONCURRENT_REQUESTS or waiting before retry"
elif [ "$SUCCESS_COUNT" -gt 1 ]; then
  echo "❌ TEST FAILED: Multiple passengers ($SUCCESS_COUNT) held the same seat!"
  echo "   CRITICAL: Race condition detected - seat assignment is NOT conflict-free"
  exit 1
fi

# Cleanup
rm -rf "$TEMP_DIR"

echo ""
echo "=== Test Complete ==="
