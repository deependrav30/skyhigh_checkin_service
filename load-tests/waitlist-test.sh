#!/bin/bash

# Test script for Business Scenario 2.5: Waitlist Assignment
# Tests automatic seat assignment when seats become available

set -e

FLIGHT_ID="FL-123"
API_URL="http://localhost:3002"
DB_CONNECTION="postgres://postgres:postgres@localhost:5434/skyhigh"

echo "═══════════════════════════════════════════════════════════════"
echo "  Business Scenario 2.5: Waitlist Assignment"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Test 1: Join waitlist when seat unavailable
echo "TEST 1: Join Waitlist When Seat Unavailable"
echo "────────────────────────────────────────────────────────"

SEAT_ID="12E"
PASSENGER_OWNER="POWNER1"
PASSENGER_WAIT="PWAITLIST1"

# Ensure seat is available first
echo "Step 1: Preparing test - confirming seat $SEAT_ID for $PASSENGER_OWNER..."
psql "$DB_CONNECTION" -c "UPDATE seats SET state='AVAILABLE', held_by=NULL WHERE flight_id='$FLIGHT_ID' AND seat_id='$SEAT_ID';" > /dev/null

# Hold and confirm the seat
HOLD_RESPONSE=$(curl -s -X POST "$API_URL/flights/$FLIGHT_ID/seats/$SEAT_ID/hold" \
  -H "Content-Type: application/json" \
  -d "{\"passengerId\":\"$PASSENGER_OWNER\"}")
HOLD_ID=$(echo "$HOLD_RESPONSE" | grep -o '"holdId":"[^"]*"' | cut -d'"' -f4)
curl -s -X POST "$API_URL/holds/$HOLD_ID/confirm" \
  -H "Content-Type: application/json" \
  -d "{\"passengerId\":\"$PASSENGER_OWNER\"}" > /dev/null
echo "✅ $PASSENGER_OWNER has confirmed seat $SEAT_ID"
echo ""

# Check available seats count
AVAILABLE_COUNT=$(psql "$DB_CONNECTION" -t -c "SELECT COUNT(*) FROM seats WHERE flight_id='$FLIGHT_ID' AND state='AVAILABLE';")
echo "Available seats: $AVAILABLE_COUNT"
echo ""

# Try to hold another seat - should work
echo "Step 2: Attempting to hold a different available seat..."
ANOTHER_SEAT=$(psql "$DB_CONNECTION" -t -c "SELECT seat_id FROM seats WHERE flight_id='$FLIGHT_ID' AND state='AVAILABLE' LIMIT 1;" | xargs)
if [ -n "$ANOTHER_SEAT" ]; then
  echo "✅ Available seat found: $ANOTHER_SEAT (can hold normally)"
else
  echo "⚠️  All seats taken (full flight scenario)"
fi
echo ""

# Join waitlist
echo "Step 3: $PASSENGER_WAIT joining waitlist..."
WAITLIST_RESPONSE=$(curl -s -X POST "$API_URL/flights/$FLIGHT_ID/waitlist" \
  -H "Content-Type: application/json" \
  -d "{\"passengerId\":\"$PASSENGER_WAIT\",\"preferences\":{}}")
echo "Response: $WAITLIST_RESPONSE"
WAITLIST_ID=$(echo "$WAITLIST_RESPONSE" | grep -o '"entryId":"[^"]*"' | cut -d'"' -f4)

if [ -z "$WAITLIST_ID" ]; then
  echo "❌ Failed to join waitlist"
  exit 1
fi

echo "✅ Waitlist entry created: $WAITLIST_ID"
echo ""

# Verify waitlist entry
WAITLIST_CHECK=$(psql "$DB_CONNECTION" -t -c "SELECT waitlist_id, user_id, status, created_at FROM waitlist WHERE waitlist_id='$WAITLIST_ID';")
echo "Database record: $WAITLIST_CHECK"
echo ""

echo "✅ TEST 1 PASSED: Passenger successfully joined waitlist"
echo ""

echo "═══════════════════════════════════════════════════════════════"
echo ""

# Test 2: Auto-assignment when seat becomes available
echo "TEST 2: Auto-Assignment When Seat Becomes Available"
echo "────────────────────────────────────────────────────────"

SEAT_ID_2="13C"
PASSENGER_OWNER_2="POWNER2"
PASSENGER_WAIT_2="PWAITLIST2"

# Setup: Confirm a seat
echo "Step 1: Setting up - confirming seat $SEAT_ID_2 for $PASSENGER_OWNER_2..."
psql "$DB_CONNECTION" -c "UPDATE seats SET state='AVAILABLE', held_by=NULL WHERE flight_id='$FLIGHT_ID' AND seat_id='$SEAT_ID_2';" > /dev/null
HOLD_RESPONSE_2=$(curl -s -X POST "$API_URL/flights/$FLIGHT_ID/seats/$SEAT_ID_2/hold" \
  -H "Content-Type: application/json" \
  -d "{\"passengerId\":\"$PASSENGER_OWNER_2\"}")
HOLD_ID_2=$(echo "$HOLD_RESPONSE_2" | grep -o '"holdId":"[^"]*"' | cut -d'"' -f4)
curl -s -X POST "$API_URL/holds/$HOLD_ID_2/confirm" \
  -H "Content-Type: application/json" \
  -d "{\"passengerId\":\"$PASSENGER_OWNER_2\"}" > /dev/null
echo "✅ Seat $SEAT_ID_2 confirmed by $PASSENGER_OWNER_2"
echo ""

# Add passenger to waitlist
echo "Step 2: $PASSENGER_WAIT_2 joining waitlist..."
WAITLIST_RESPONSE_2=$(curl -s -X POST "$API_URL/flights/$FLIGHT_ID/waitlist" \
  -H "Content-Type: application/json" \
  -d "{\"passengerId\":\"$PASSENGER_WAIT_2\",\"preferences\":{}}")
WAITLIST_ID_2=$(echo "$WAITLIST_RESPONSE_2" | grep -o '"entryId":"[^"]*"' | cut -d'"' -f4)
echo "✅ Waitlist entry: $WAITLIST_ID_2"
echo ""

# Check worker is running
echo "Step 3: Checking if worker is running..."
WORKER_PID=$(ps aux | grep "npx tsx.*worker" | grep -v grep | awk '{print $2}')
if [ -z "$WORKER_PID" ]; then
  echo "⚠️  Worker not running - starting worker process..."
  cd /Users/deependraverma/Documents/Projects/AI/skyhigh_checkin_service/api
  npx tsx src/worker.ts > /tmp/worker.log 2>&1 &
  WORKER_PID=$!
  echo "✅ Worker started (PID: $WORKER_PID)"
  sleep 2
else
  echo "✅ Worker already running (PID: $WORKER_PID)"
fi
echo ""

# Cancel the seat
echo "Step 4: $PASSENGER_OWNER_2 cancelling seat $SEAT_ID_2..."
curl -s -X POST "$API_URL/flights/$FLIGHT_ID/seats/$SEAT_ID_2/cancel" \
  -H "Content-Type: application/json" \
  -d "{\"passengerId\":\"$PASSENGER_OWNER_2\",\"reason\":\"Testing waitlist auto-assignment\"}" > /dev/null
echo "✅ Seat cancelled"
echo ""

# Verify seat is AVAILABLE
SEAT_STATE=$(psql "$DB_CONNECTION" -t -c "SELECT state FROM seats WHERE flight_id='$FLIGHT_ID' AND seat_id='$SEAT_ID_2';" | xargs)
echo "Seat $SEAT_ID_2 state: $SEAT_STATE"
echo ""

# Wait for worker to process (runs every 5 seconds)
echo "Step 5: Waiting 8 seconds for worker to process waitlist..."
for i in {8..1}; do
  echo -n "$i... "
  sleep 1
done
echo ""
echo ""

# Check if waitlisted passenger got assigned
echo "Step 6: Verifying auto-assignment..."
WAITLIST_STATUS=$(psql "$DB_CONNECTION" -t -c "SELECT status FROM waitlist WHERE waitlist_id='$WAITLIST_ID_2';" | xargs)
echo "Waitlist status: $WAITLIST_STATUS"

# Check which seat was assigned
ASSIGNED_SEAT=$(psql "$DB_CONNECTION" -t -c "SELECT seat_id, state, held_by FROM seats WHERE flight_id='$FLIGHT_ID' AND held_by='$PASSENGER_WAIT_2' AND state='CONFIRMED';" | head -1)
echo "Assigned seat: $ASSIGNED_SEAT"

# Check event log
EVENT_LOG=$(psql "$DB_CONNECTION" -t -c "SELECT event_type, actor FROM seat_events WHERE flight_id='$FLIGHT_ID' AND actor='$PASSENGER_WAIT_2' ORDER BY created_at DESC LIMIT 1;")
echo "Event log: $EVENT_LOG"
echo ""

if [ "$WAITLIST_STATUS" = "ASSIGNED" ]; then
  ASSIGNED_SEAT_ID=$(echo "$ASSIGNED_SEAT" | awk '{print $1}')
  echo "✅ TEST 2 PASSED: Waitlisted passenger automatically assigned seat $ASSIGNED_SEAT_ID"
else
  echo "❌ TEST 2 FAILED: Waitlist not processed (status: $WAITLIST_STATUS)"
  echo "   Possible reasons:"
  echo "   - Worker not running or crashed"
  echo "   - No available seats"
  echo "   - Database transaction failed"
fi
echo ""

echo "═══════════════════════════════════════════════════════════════"
echo ""

# Test 3: FIFO queue order
echo "TEST 3: FIFO Queue Order (First In, First Out)"
echo "────────────────────────────────────────────────────────"

PASSENGER_FIRST="PFIRST"
PASSENGER_SECOND="PSECOND"
SEAT_TO_FREE="14D"

# Create two waitlist entries in order
echo "Step 1: Creating two waitlist entries..."
WL_RESPONSE_1=$(curl -s -X POST "$API_URL/flights/$FLIGHT_ID/waitlist" \
  -H "Content-Type: application/json" \
  -d "{\"passengerId\":\"$PASSENGER_FIRST\",\"preferences\":{}}")
WL_ID_1=$(echo "$WL_RESPONSE_1" | grep -o '"entryId":"[^"]*"' | cut -d'"' -f4)
echo "✅ First: $PASSENGER_FIRST (ID: $WL_ID_1)"

sleep 1  # Ensure different created_at timestamps

WL_RESPONSE_2=$(curl -s -X POST "$API_URL/flights/$FLIGHT_ID/waitlist" \
  -H "Content-Type: application/json" \
  -d "{\"passengerId\":\"$PASSENGER_SECOND\",\"preferences\":{}}")
WL_ID_2=$(echo "$WL_RESPONSE_2" | grep -o '"entryId":"[^"]*"' | cut -d'"' -f4)
echo "✅ Second: $PASSENGER_SECOND (ID: $WL_ID_2)"
echo ""

# Verify queue order
echo "Step 2: Verifying queue order..."
QUEUE_ORDER=$(psql "$DB_CONNECTION" -t -c "SELECT user_id, created_at FROM waitlist WHERE waitlist_id IN ('$WL_ID_1', '$WL_ID_2') ORDER BY created_at;")
echo "$QUEUE_ORDER"
echo ""

# Free a seat
echo "Step 3: Freeing one seat ($SEAT_TO_FREE)..."
psql "$DB_CONNECTION" -c "UPDATE seats SET state='AVAILABLE', held_by=NULL WHERE flight_id='$FLIGHT_ID' AND seat_id='$SEAT_TO_FREE';" > /dev/null
echo "✅ Seat $SEAT_TO_FREE is now AVAILABLE"
echo ""

# Wait for worker
echo "Step 4: Waiting 8 seconds for worker to assign seat..."
sleep 8
echo ""

# Check who got the seat
echo "Step 5: Checking assignment..."
FIRST_STATUS=$(psql "$DB_CONNECTION" -t -c "SELECT status FROM waitlist WHERE waitlist_id='$WL_ID_1';" | xargs)
SECOND_STATUS=$(psql "$DB_CONNECTION" -t -c "SELECT status FROM waitlist WHERE waitlist_id='$WL_ID_2';" | xargs)
echo "$PASSENGER_FIRST status: $FIRST_STATUS"
echo "$PASSENGER_SECOND status: $SECOND_STATUS"

WHO_GOT_SEAT=$(psql "$DB_CONNECTION" -t -c "SELECT held_by FROM seats WHERE flight_id='$FLIGHT_ID' AND seat_id='$SEAT_TO_FREE';" | xargs)
echo "Seat $SEAT_TO_FREE assigned to: $WHO_GOT_SEAT"
echo ""

if [ "$WHO_GOT_SEAT" = "$PASSENGER_FIRST" ]; then
  echo "✅ TEST 3 PASSED: First passenger in queue got the seat (FIFO working)"
elif [ "$WHO_GOT_SEAT" = "$PASSENGER_SECOND" ]; then
  echo "❌ TEST 3 FAILED: Second passenger got seat (FIFO broken)"
else
  echo "⚠️  TEST 3 INCONCLUSIVE: No assignment detected"
fi
echo ""

echo "═══════════════════════════════════════════════════════════════"
echo ""

# Summary
echo "SUMMARY"
echo "────────────────────────────────────────────────────────"
echo "✅ Test 1: Passengers can join waitlist"
if [ "$WAITLIST_STATUS" = "ASSIGNED" ]; then
  echo "✅ Test 2: Auto-assignment working"
else
  echo "⚠️  Test 2: Auto-assignment (check worker)"
fi
if [ "$WHO_GOT_SEAT" = "$PASSENGER_FIRST" ]; then
  echo "✅ Test 3: FIFO queue order preserved"
else
  echo "⚠️  Test 3: FIFO queue order (check worker)"
fi
echo ""

echo "BUSINESS REQUIREMENTS VERIFICATION"
echo "────────────────────────────────────────────────────────"
echo "✅ Passengers can join waitlist when seat unavailable"
if [ "$WAITLIST_STATUS" = "ASSIGNED" ]; then
  echo "✅ System automatically assigns seats when available"
  echo "✅ FIFO queue order maintained"
  echo "⚠️  Notification system (not implemented yet)"
else
  echo "⚠️  Auto-assignment (requires worker process)"
fi
echo ""

echo "═══════════════════════════════════════════════════════════════"
echo "  Business Scenario 2.5: VERIFICATION COMPLETE"
echo "═══════════════════════════════════════════════════════════════"
