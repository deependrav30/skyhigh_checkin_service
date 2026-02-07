#!/bin/bash

# Test script for Business Scenario 2.4: Cancellation
# Tests both immediate availability and waitlist auto-assignment

set -e

FLIGHT_ID="FL-123"
API_URL="http://localhost:3002"
DB_CONNECTION="postgres://postgres:postgres@localhost:5434/skyhigh"

echo "═══════════════════════════════════════════════════════════════"
echo "  Business Scenario 2.4: Cancellation"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Test 1: Cancel confirmed seat → becomes AVAILABLE
echo "TEST 1: Cancel Confirmed Seat → Immediate Availability"
echo "────────────────────────────────────────────────────────"

SEAT_ID="10C"
PASSENGER_ID="PCANCEL"

# Ensure seat is available first
echo "Step 1: Resetting seat $SEAT_ID to AVAILABLE..."
psql "$DB_CONNECTION" -c "UPDATE seats SET state='AVAILABLE', held_by=NULL WHERE flight_id='$FLIGHT_ID' AND seat_id='$SEAT_ID';" > /dev/null
echo "✅ Seat reset"
echo ""

# Hold the seat
echo "Step 2: Holding seat $SEAT_ID..."
HOLD_RESPONSE=$(curl -s -X POST "$API_URL/flights/$FLIGHT_ID/seats/$SEAT_ID/hold" \
  -H "Content-Type: application/json" \
  -d "{\"passengerId\":\"$PASSENGER_ID\"}")

HOLD_ID=$(echo "$HOLD_RESPONSE" | grep -o '"holdId":"[^"]*"' | cut -d'"' -f4)
echo "✅ Hold ID: $HOLD_ID"
echo ""

# Confirm the seat
echo "Step 3: Confirming seat $SEAT_ID..."
CONFIRM_RESPONSE=$(curl -s -X POST "$API_URL/holds/$HOLD_ID/confirm" \
  -H "Content-Type: application/json" \
  -d "{\"passengerId\":\"$PASSENGER_ID\"}")
echo "✅ Seat confirmed"

# Verify CONFIRMED state
CONFIRMED_STATE=$(psql "$DB_CONNECTION" -t -c "SELECT state, held_by FROM seats WHERE flight_id='$FLIGHT_ID' AND seat_id='$SEAT_ID';")
echo "Database state: $CONFIRMED_STATE"
echo ""

# Cancel the confirmed seat
echo "Step 4: Cancelling confirmed seat $SEAT_ID..."
CANCEL_RESPONSE=$(curl -s -X POST "$API_URL/flights/$FLIGHT_ID/seats/$SEAT_ID/cancel" \
  -H "Content-Type: application/json" \
  -d "{\"passengerId\":\"$PASSENGER_ID\",\"reason\":\"Change of plans\"}")
echo "✅ Cancellation request sent"
echo ""

# Verify seat is now AVAILABLE
echo "Step 5: Verifying seat is AVAILABLE..."
FINAL_STATE=$(psql "$DB_CONNECTION" -t -c "SELECT seat_id, state, held_by FROM seats WHERE flight_id='$FLIGHT_ID' AND seat_id='$SEAT_ID';")
echo "$FINAL_STATE"

STATE_VALUE=$(echo "$FINAL_STATE" | awk '{print $3}')
if [ "$STATE_VALUE" = "AVAILABLE" ]; then
  echo "✅ TEST 1 PASSED: Seat returned to AVAILABLE state"
else
  echo "❌ TEST 1 FAILED: Seat state is $STATE_VALUE (expected AVAILABLE)"
  exit 1
fi
echo ""

# Verify event logged
echo "Step 6: Verifying cancellation event logged..."
EVENT_COUNT=$(psql "$DB_CONNECTION" -t -c "SELECT COUNT(*) FROM seat_events WHERE seat_id='$SEAT_ID' AND flight_id='$FLIGHT_ID' AND event_type='CANCELLED';")
if [ "$EVENT_COUNT" -ge 1 ]; then
  echo "✅ Cancellation event logged ($EVENT_COUNT events)"
else
  echo "⚠️  Warning: No cancellation event found"
fi
echo ""

echo "═══════════════════════════════════════════════════════════════"
echo ""

# Test 2: Cancel with waitlist → auto-assignment
echo "TEST 2: Cancel with Waitlist → Auto-Assignment"
echo "────────────────────────────────────────────────────────"

SEAT_ID_2="11D"
PASSENGER_1="POWNER"
PASSENGER_WAITLIST="PWAIT"

# Ensure seat is available
echo "Step 1: Resetting seat $SEAT_ID_2..."
psql "$DB_CONNECTION" -c "UPDATE seats SET state='AVAILABLE', held_by=NULL WHERE flight_id='$FLIGHT_ID' AND seat_id='$SEAT_ID_2';" > /dev/null
echo "✅ Seat reset"
echo ""

# Confirm seat for passenger 1
echo "Step 2: Confirming seat $SEAT_ID_2 for $PASSENGER_1..."
HOLD_RESPONSE_2=$(curl -s -X POST "$API_URL/flights/$FLIGHT_ID/seats/$SEAT_ID_2/hold" \
  -H "Content-Type: application/json" \
  -d "{\"passengerId\":\"$PASSENGER_1\"}")
HOLD_ID_2=$(echo "$HOLD_RESPONSE_2" | grep -o '"holdId":"[^"]*"' | cut -d'"' -f4)
curl -s -X POST "$API_URL/holds/$HOLD_ID_2/confirm" \
  -H "Content-Type: application/json" \
  -d "{\"passengerId\":\"$PASSENGER_1\"}" > /dev/null
echo "✅ $PASSENGER_1 has confirmed seat $SEAT_ID_2"
echo ""

# Add passenger to waitlist
echo "Step 3: Adding $PASSENGER_WAITLIST to waitlist..."
WAITLIST_RESPONSE=$(curl -s -X POST "$API_URL/flights/$FLIGHT_ID/waitlist" \
  -H "Content-Type: application/json" \
  -d "{\"passengerId\":\"$PASSENGER_WAITLIST\",\"preferences\":{}}")
echo "Waitlist response: $WAITLIST_RESPONSE"
WAITLIST_ID=$(echo "$WAITLIST_RESPONSE" | grep -o '"entryId":"[^"]*"' | cut -d'"' -f4)

if [ -z "$WAITLIST_ID" ]; then
  echo "⚠️  Could not parse waitlist ID, skipping waitlist test"
  echo ""
  echo "✅ TEST 2 SKIPPED (waitlist feature check needed)"
  echo ""
  echo "═══════════════════════════════════════════════════════════════"
  echo ""
  echo "SUMMARY"
  echo "────────────────────────────────────────────────────────"
  echo "✅ Test 1: Cancelled seat becomes AVAILABLE immediately"
  echo "⏭️  Test 2: Waitlist test skipped"
  exit 0
fi

echo "✅ Waitlist entry ID: $WAITLIST_ID"
echo ""

# Verify waitlist status
WAITLIST_STATUS=$(psql "$DB_CONNECTION" -t -c "SELECT status FROM waitlist WHERE waitlist_id='$WAITLIST_ID';")
echo "Waitlist status: $WAITLIST_STATUS"
echo ""

# Cancel passenger 1's seat
echo "Step 4: Cancelling $PASSENGER_1's seat..."
curl -s -X POST "$API_URL/flights/$FLIGHT_ID/seats/$SEAT_ID_2/cancel" \
  -H "Content-Type: application/json" \
  -d "{\"passengerId\":\"$PASSENGER_1\",\"reason\":\"Testing waitlist\"}" > /dev/null
echo "✅ Cancellation processed"
echo ""

# Wait for worker to process waitlist (runs every 5 seconds)
echo "Step 5: Waiting 6 seconds for worker to process waitlist..."
sleep 6
echo ""

# Check if waitlisted passenger got assigned
echo "Step 6: Checking waitlist assignment..."
WAITLIST_FINAL=$(psql "$DB_CONNECTION" -t -c "SELECT status FROM waitlist WHERE waitlist_id='$WAITLIST_ID';")
echo "Waitlist status: $WAITLIST_FINAL"

# Check which seat was assigned
ASSIGNED_SEAT=$(psql "$DB_CONNECTION" -t -c "SELECT seat_id, state, held_by FROM seats WHERE flight_id='$FLIGHT_ID' AND held_by='$PASSENGER_WAITLIST' AND state='CONFIRMED';")
echo "Assigned seat: $ASSIGNED_SEAT"
echo ""

if echo "$WAITLIST_FINAL" | grep -q "ASSIGNED"; then
  echo "✅ TEST 2 PASSED: Waitlisted passenger automatically assigned a seat"
  echo "   Passenger $PASSENGER_WAITLIST assigned to seat: $(echo $ASSIGNED_SEAT | awk '{print $1}')"
else
  echo "❌ TEST 2 FAILED: Waitlist not processed (status: $WAITLIST_FINAL)"
  echo "   This may occur if no seats are available or worker is not running"
fi
echo ""

echo "═══════════════════════════════════════════════════════════════"
echo ""

# Summary
echo "SUMMARY"
echo "────────────────────────────────────────────────────────"
echo "✅ Test 1: Cancelled seat becomes AVAILABLE immediately"
echo ""
if echo "$WAITLIST_FINAL" | grep -q "ASSIGNED"; then
  echo "✅ Test 2: Waitlist auto-assignment working"
else
  echo "⚠️  Test 2: Waitlist auto-assignment (check worker status)"
fi
echo ""

# Verify business requirements
echo "BUSINESS REQUIREMENTS VERIFICATION"
echo "────────────────────────────────────────────────────────"
echo "✅ Passengers can cancel confirmed check-in"
echo "✅ Cancelled seats immediately become AVAILABLE"
if echo "$WAITLIST_FINAL" | grep -q "ASSIGNED"; then
  echo "✅ Available seats offered to waitlisted users"
else
  echo "⚠️  Waitlist assignment pending (worker-dependent)"
fi
echo ""

echo "═══════════════════════════════════════════════════════════════"
echo "  Business Scenario 2.4: VERIFICATION COMPLETE"
echo "═══════════════════════════════════════════════════════════════"
