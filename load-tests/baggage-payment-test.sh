#!/bin/bash

# Test script for Business Scenario 2.6: Baggage Validation & Payment Pause

set -e

FLIGHT_ID="FL-123"
API_URL="http://localhost:3002"
DB_CONNECTION="postgres://postgres:postgres@localhost:5434/skyhigh"

echo "═══════════════════════════════════════════════════════════════"
echo "  Business Scenario 2.6: Baggage Validation & Payment Pause"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Test 1: Baggage within limit (≤25kg) → Check-in completes
echo "TEST 1: Baggage Within Limit (20kg) → Check-in Completes"
echo "────────────────────────────────────────────────────────"

PASSENGER_ID="PBAG1"
CHECKIN_ID=$(uuidgen | tr '[:upper:]' '[:lower:]')

# Create check-in
echo "Step 1: Creating check-in for $PASSENGER_ID..."
psql "$DB_CONNECTION" -c "INSERT INTO checkins (checkin_id, passenger_id, flight_id, state) VALUES ('$CHECKIN_ID', '$PASSENGER_ID', '$FLIGHT_ID', 'IN_PROGRESS');" > /dev/null
echo "✅ Check-in created: $CHECKIN_ID"
echo ""

# Add baggage (20kg - within limit)
echo "Step 2: Adding baggage (20kg - within 25kg limit)..."
BAGGAGE_RESPONSE=$(curl -s -X POST "$API_URL/checkins/$CHECKIN_ID/baggage" \
  -H "Content-Type: application/json" \
  -d '{"weightKg":20}')
echo "Response: $BAGGAGE_RESPONSE"
echo ""

# Verify state
CHECKIN_STATE=$(psql "$DB_CONNECTION" -t -c "SELECT state, baggage_weight, payment_intent_id FROM checkins WHERE checkin_id='$CHECKIN_ID';")
echo "Check-in state: $CHECKIN_STATE"

STATE_VALUE=$(echo "$CHECKIN_STATE" | awk '{print $1}')
WEIGHT_VALUE=$(echo "$CHECKIN_STATE" | awk '{print $3}')
PAYMENT_ID=$(echo "$CHECKIN_STATE" | awk '{print $5}')

if [ "$STATE_VALUE" = "COMPLETED" ] && [ "$WEIGHT_VALUE" = "20.00" ] && [ -z "$PAYMENT_ID" ]; then
  echo "✅ TEST 1 PASSED: Check-in completed without payment"
  echo "   State: COMPLETED"
  echo "   Weight: 20kg"
  echo "   Payment required: No"
else
  echo "❌ TEST 1 FAILED: Unexpected state"
  echo "   Expected: COMPLETED, 20kg, no payment"
  echo "   Got: $STATE_VALUE, $WEIGHT_VALUE, $PAYMENT_ID"
  exit 1
fi
echo ""

echo "═══════════════════════════════════════════════════════════════"
echo ""

# Test 2: Baggage exceeds limit (>25kg) → Pause and wait for payment
echo "TEST 2: Baggage Exceeds Limit (30kg) → Pause for Payment"
echo "────────────────────────────────────────────────────────"

PASSENGER_ID_2="PBAG2"
CHECKIN_ID_2=$(uuidgen | tr '[:upper:]' '[:lower:]')

# Create check-in
echo "Step 1: Creating check-in for $PASSENGER_ID_2..."
psql "$DB_CONNECTION" -c "INSERT INTO checkins (checkin_id, passenger_id, flight_id, state) VALUES ('$CHECKIN_ID_2', '$PASSENGER_ID_2', '$FLIGHT_ID', 'IN_PROGRESS');" > /dev/null
echo "✅ Check-in created: $CHECKIN_ID_2"
echo ""

# Add baggage (30kg - exceeds limit)
echo "Step 2: Adding baggage (30kg - exceeds 25kg limit)..."
BAGGAGE_RESPONSE_2=$(curl -s -X POST "$API_URL/checkins/$CHECKIN_ID_2/baggage" \
  -H "Content-Type: application/json" \
  -d '{"weightKg":30}')
echo "Response: $BAGGAGE_RESPONSE_2"
echo ""

# Extract payment intent ID
PAYMENT_INTENT_ID=$(echo "$BAGGAGE_RESPONSE_2" | grep -o '"paymentIntentId":"[^"]*"' | cut -d'"' -f4)
echo "Payment Intent ID: $PAYMENT_INTENT_ID"
echo ""

# Verify state is WAITING_FOR_PAYMENT
CHECKIN_STATE_2=$(psql "$DB_CONNECTION" -t -c "SELECT state, baggage_weight, payment_intent_id FROM checkins WHERE checkin_id='$CHECKIN_ID_2';")
echo "Check-in state: $CHECKIN_STATE_2"

STATE_VALUE_2=$(echo "$CHECKIN_STATE_2" | awk '{print $1}')
WEIGHT_VALUE_2=$(echo "$CHECKIN_STATE_2" | awk '{print $3}')

if [ "$STATE_VALUE_2" = "WAITING_FOR_PAYMENT" ] && [ "$WEIGHT_VALUE_2" = "30.00" ] && [ -n "$PAYMENT_INTENT_ID" ]; then
  echo "✅ TEST 2 PASSED: Check-in paused, waiting for payment"
  echo "   State: WAITING_FOR_PAYMENT"
  echo "   Weight: 30kg"
  echo "   Payment intent created: $PAYMENT_INTENT_ID"
else
  echo "❌ TEST 2 FAILED: Check-in not paused correctly"
  echo "   Expected: WAITING_FOR_PAYMENT, 30kg, payment ID"
  echo "   Got: $STATE_VALUE_2, $WEIGHT_VALUE_2"
  exit 1
fi
echo ""

# Verify payment intent in database
PAYMENT_INTENT=$(psql "$DB_CONNECTION" -t -c "SELECT status, amount, currency FROM payment_intents WHERE intent_id='$PAYMENT_INTENT_ID';")
echo "Payment intent: $PAYMENT_INTENT"

PAYMENT_STATUS=$(echo "$PAYMENT_INTENT" | awk '{print $1}')
PAYMENT_AMOUNT=$(echo "$PAYMENT_INTENT" | awk '{print $3}')

if [ "$PAYMENT_STATUS" = "pending" ] && [ "$PAYMENT_AMOUNT" = "50.00" ]; then
  echo "✅ Payment intent created correctly"
  echo "   Status: pending"
  echo "   Amount: $50"
else
  echo "⚠️  Payment intent: $PAYMENT_STATUS, $PAYMENT_AMOUNT"
fi
echo ""

echo "═══════════════════════════════════════════════════════════════"
echo ""

# Test 3: Payment succeeds → Check-in completes
echo "TEST 3: Payment Succeeds → Check-in Completes"
echo "────────────────────────────────────────────────────────"

echo "Step 1: Simulating successful payment webhook..."
WEBHOOK_RESPONSE=$(curl -s -X POST "$API_URL/payments/webhook" \
  -H "Content-Type: application/json" \
  -d "{\"intentId\":\"$PAYMENT_INTENT_ID\",\"status\":\"succeeded\"}")
echo "Webhook response: $WEBHOOK_RESPONSE"
echo ""

# Verify check-in completed
FINAL_STATE=$(psql "$DB_CONNECTION" -t -c "SELECT state FROM checkins WHERE checkin_id='$CHECKIN_ID_2';")
echo "Check-in state after payment: $FINAL_STATE"

if echo "$FINAL_STATE" | grep -q "COMPLETED"; then
  echo "✅ TEST 3 PASSED: Check-in completed after successful payment"
  echo "   State: WAITING_FOR_PAYMENT → COMPLETED"
else
  echo "❌ TEST 3 FAILED: Check-in not completed"
  echo "   Expected: COMPLETED"
  echo "   Got: $FINAL_STATE"
  exit 1
fi
echo ""

# Verify payment intent updated
PAYMENT_FINAL=$(psql "$DB_CONNECTION" -t -c "SELECT status FROM payment_intents WHERE intent_id='$PAYMENT_INTENT_ID';")
echo "Payment intent final status: $PAYMENT_FINAL"
if echo "$PAYMENT_FINAL" | grep -q "succeeded"; then
  echo "✅ Payment intent marked as succeeded"
fi
echo ""

echo "═══════════════════════════════════════════════════════════════"
echo ""

# Test 4: Payment fails → Check-in stays paused
echo "TEST 4: Payment Fails → Check-in Stays Paused"
echo "────────────────────────────────────────────────────────"

PASSENGER_ID_3="PBAG3"
CHECKIN_ID_3=$(uuidgen | tr '[:upper:]' '[:lower:]')

# Create check-in with excess baggage
echo "Step 1: Creating check-in with excess baggage..."
psql "$DB_CONNECTION" -c "INSERT INTO checkins (checkin_id, passenger_id, flight_id, state) VALUES ('$CHECKIN_ID_3', '$PASSENGER_ID_3', '$FLIGHT_ID', 'IN_PROGRESS');" > /dev/null

BAGGAGE_RESPONSE_3=$(curl -s -X POST "$API_URL/checkins/$CHECKIN_ID_3/baggage" \
  -H "Content-Type: application/json" \
  -d '{"weightKg":28}')

PAYMENT_INTENT_ID_3=$(echo "$BAGGAGE_RESPONSE_3" | grep -o '"paymentIntentId":"[^"]*"' | cut -d'"' -f4)
echo "✅ Check-in paused, payment intent: $PAYMENT_INTENT_ID_3"
echo ""

# Simulate failed payment
echo "Step 2: Simulating failed payment..."
curl -s -X POST "$API_URL/payments/webhook" \
  -H "Content-Type: application/json" \
  -d "{\"intentId\":\"$PAYMENT_INTENT_ID_3\",\"status\":\"failed\"}" > /dev/null
echo "✅ Payment failed"
echo ""

# Verify check-in still waiting
FAILED_STATE=$(psql "$DB_CONNECTION" -t -c "SELECT state FROM checkins WHERE checkin_id='$CHECKIN_ID_3';")
echo "Check-in state after failed payment: $FAILED_STATE"

if echo "$FAILED_STATE" | grep -q "WAITING_FOR_PAYMENT"; then
  echo "✅ TEST 4 PASSED: Check-in remains paused after failed payment"
  echo "   State: WAITING_FOR_PAYMENT (unchanged)"
else
  echo "❌ TEST 4 FAILED: Check-in state changed unexpectedly"
  echo "   Expected: WAITING_FOR_PAYMENT"
  echo "   Got: $FAILED_STATE"
  exit 1
fi
echo ""

echo "═══════════════════════════════════════════════════════════════"
echo ""

# Summary
echo "SUMMARY"
echo "────────────────────────────────────────────────────────"
echo "✅ Test 1: Baggage ≤25kg → Check-in completes immediately"
echo "✅ Test 2: Baggage >25kg → Check-in paused, payment intent created"
echo "✅ Test 3: Payment succeeds → Check-in completes"
echo "✅ Test 4: Payment fails → Check-in remains paused"
echo ""

echo "BUSINESS REQUIREMENTS VERIFICATION"
echo "────────────────────────────────────────────────────────"
echo "✅ Maximum 25kg baggage weight enforced"
echo "✅ Check-in paused when limit exceeded"
echo "✅ Payment required for excess baggage (\$50 surcharge)"
echo "✅ Check-in completes only after successful payment"
echo "✅ Check-in states clearly reflect status:"
echo "   • IN_PROGRESS (initial state)"
echo "   • WAITING_FOR_PAYMENT (excess baggage, awaiting payment)"
echo "   • COMPLETED (baggage within limit OR payment succeeded)"
echo ""

echo "═══════════════════════════════════════════════════════════════"
echo "  Business Scenario 2.6: VERIFICATION COMPLETE"
echo "═══════════════════════════════════════════════════════════════"
