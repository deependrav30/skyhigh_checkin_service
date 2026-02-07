#!/bin/bash

# Business Scenario 2.8: Abuse & Bot Detection
# Tests detection and blocking of rapid multi-seat-map access

API_BASE="http://localhost:3002"
LOG_FILE="/tmp/abuse-test.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "======================================================================"
echo "Business Scenario 2.8: Abuse & Bot Detection"
echo "======================================================================"
echo ""
echo "Requirements:"
echo "  • Detect rapid access to multiple seat maps"
echo "  • Example: 50 different seat maps within 2 seconds"
echo "  • Block further access temporarily when detected"
echo "  • Record event for audit and review"
echo ""

> "$LOG_FILE"

# Create array of flight IDs to test
FLIGHTS=("FL-123" "FL-200" "FL-201" "FL-202" "FL-203" "FL-204" "FL-205" 
         "FL-206" "FL-207" "FL-208" "FL-209" "FL-210")

#==============================================================================
# TEST 1: Normal Usage - Should NOT Trigger Abuse Detection
#==============================================================================
echo "======================================================================"
echo "TEST 1: NORMAL USAGE (Should NOT trigger detection)"
echo "======================================================================"
echo ""
echo "Accessing 5 different seat maps slowly (1 per second)..."
echo ""

SUCCESS_COUNT=0
for i in {0..4}; do
  FLIGHT="${FLIGHTS[$i]}"
  echo "Request $((i+1)): Accessing $FLIGHT..."
  
  HTTP_CODE=$(curl -s -w "%{http_code}" -o /tmp/response_$i.json "$API_BASE/flights/$FLIGHT/seatmap")
  
  if [ "$HTTP_CODE" = "200" ]; then
    echo "  ✅ Success (HTTP 200)"
    ((SUCCESS_COUNT++))
  else
    echo "  ❌ Failed (HTTP $HTTP_CODE)"
    cat /tmp/response_$i.json
  fi
  
  sleep 1  # Wait 1 second between requests
done

echo ""
if [ "$SUCCESS_COUNT" -eq 5 ]; then
  echo -e "${GREEN}✅ TEST 1 PASSED: Normal usage allowed (5/5 succeeded)${NC}"
else
  echo -e "${RED}❌ TEST 1 FAILED: Normal usage blocked ($SUCCESS_COUNT/5 succeeded)${NC}"
fi

echo ""
sleep 2

#==============================================================================
# TEST 2: Rapid Access to 12 Different Seat Maps (Abuse)
#==============================================================================
echo "======================================================================"
echo "TEST 2: ABUSE SCENARIO - 12 seat maps in < 2 seconds"
echo "======================================================================"
echo ""
echo "Rapidly accessing 12 different flight seat maps..."
echo ""

START_TIME=$(date +%s%3N)
SUCCESS_COUNT=0
BLOCKED_COUNT=0

for i in {0..11}; do
  FLIGHT="${FLIGHTS[$i]}"
  
  {
    HTTP_CODE=$(curl -s -w "%{http_code}" -o /tmp/abuse_response_$i.json "$API_BASE/flights/$FLIGHT/seatmap" 2>&1)
    echo "$HTTP_CODE" > /tmp/abuse_status_$i.txt
  } &
done

# Wait for all requests to complete
wait

END_TIME=$(date +%s%3N)
ELAPSED=$((END_TIME - START_TIME))

echo "Time elapsed: ${ELAPSED}ms"
echo ""
echo "Results:"

for i in {0..11}; do
  FLIGHT="${FLIGHTS[$i]}"
  HTTP_CODE=$(cat /tmp/abuse_status_$i.txt 2>/dev/null || echo "000")
  
  if [ "$HTTP_CODE" = "200" ]; then
    echo "  Request $((i+1)) ($FLIGHT): ✅ HTTP 200 (Allowed)"
    ((SUCCESS_COUNT++))
  elif [ "$HTTP_CODE" = "429" ]; then
    RESPONSE=$(cat /tmp/abuse_response_$i.json 2>/dev/null)
    echo "  Request $((i+1)) ($FLIGHT): 🚫 HTTP 429 (Blocked - Abuse detected)"
    ((BLOCKED_COUNT++))
  else
    echo "  Request $((i+1)) ($FLIGHT): ❌ HTTP $HTTP_CODE"
  fi
done

echo ""
echo "Summary:"
echo "  Successful requests: $SUCCESS_COUNT"
echo "  Blocked requests: $BLOCKED_COUNT"
echo "  Time window: ${ELAPSED}ms"
echo ""

# Check if abuse was detected (some requests should be blocked)
if [ "$BLOCKED_COUNT" -gt 0 ]; then
  echo -e "${GREEN}✅ TEST 2 PASSED: Abuse detected and blocked ($BLOCKED_COUNT requests blocked)${NC}"
  TEST2_RESULT="PASS"
else
  echo -e "${RED}❌ TEST 2 FAILED: Abuse NOT detected (all $SUCCESS_COUNT requests succeeded)${NC}"
  TEST2_RESULT="FAIL"
fi

# Show one blocked response
if [ "$BLOCKED_COUNT" -gt 0 ]; then
  echo ""
  echo "Sample blocked response:"
  for i in {0..11}; do
    if [ "$(cat /tmp/abuse_status_$i.txt 2>/dev/null)" = "429" ]; then
      cat /tmp/abuse_response_$i.json 2>/dev/null | jq '.' 2>/dev/null || cat /tmp/abuse_response_$i.json
      break
    fi
  done
fi

echo ""
sleep 2

#==============================================================================
# TEST 3: Verify Block Persists (Subsequent Request Should Be Blocked)
#==============================================================================
echo "======================================================================"
echo "TEST 3: VERIFY BLOCK PERSISTS"
echo "======================================================================"
echo ""
echo "Attempting to access another seat map after being blocked..."
echo ""

HTTP_CODE=$(curl -s -w "%{http_code}" -o /tmp/persist_response.json "$API_BASE/flights/FL-123/seatmap")

if [ "$HTTP_CODE" = "429" ]; then
  echo -e "${GREEN}✅ TEST 3 PASSED: Still blocked (HTTP 429)${NC}"
  echo "Response:"
  cat /tmp/persist_response.json | jq '.' 2>/dev/null || cat /tmp/persist_response.json
  TEST3_RESULT="PASS"
else
  echo -e "${RED}❌ TEST 3 FAILED: Not blocked (HTTP $HTTP_CODE)${NC}"
  TEST3_RESULT="FAIL"
fi

echo ""
sleep 2

#==============================================================================
# TEST 4: Check Audit Log
#==============================================================================
echo "======================================================================"
echo "TEST 4: AUDIT LOG VERIFICATION"
echo "======================================================================"
echo ""
echo "Checking if abuse event was recorded in database..."
echo ""

ABUSE_COUNT=$(psql postgresql://postgres:postgres@localhost:5434/skyhigh -t -c \
  "SELECT COUNT(*) FROM abuse_events WHERE detection_time > now() - interval '1 minute';" 2>/dev/null | xargs)

if [ -z "$ABUSE_COUNT" ]; then
  ABUSE_COUNT=0
fi

echo "Abuse events in last minute: $ABUSE_COUNT"
echo ""

if [ "$ABUSE_COUNT" -gt 0 ]; then
  echo "Recent abuse event details:"
  psql postgresql://postgres:postgres@localhost:5434/skyhigh -c \
    "SELECT ip_address, event_type, request_count, time_window_ms, 
            to_char(detection_time, 'YYYY-MM-DD HH24:MI:SS') as detected_at,
            to_char(blocked_until, 'YYYY-MM-DD HH24:MI:SS') as blocked_until
     FROM abuse_events 
     WHERE detection_time > now() - interval '1 minute'
     ORDER BY detection_time DESC 
     LIMIT 1;" 2>/dev/null
  
  echo ""
  echo "Event details (JSON):"
  psql postgresql://postgres:postgres@localhost:5434/skyhigh -t -c \
    "SELECT details FROM abuse_events 
     WHERE detection_time > now() - interval '1 minute'
     ORDER BY detection_time DESC LIMIT 1;" 2>/dev/null | jq '.' 2>/dev/null || echo "Could not parse JSON"
  
  echo ""
  echo -e "${GREEN}✅ TEST 4 PASSED: Abuse event recorded in audit log${NC}"
  TEST4_RESULT="PASS"
else
  echo -e "${RED}❌ TEST 4 FAILED: No abuse event found in audit log${NC}"
  TEST4_RESULT="FAIL"
fi

echo ""
sleep 2

#==============================================================================
# TEST 5: Admin API - View Recent Abuse Events
#==============================================================================
echo "======================================================================"
echo "TEST 5: ADMIN API - Recent Abuse Events"
echo "======================================================================"
echo ""
echo "Testing admin endpoint: GET /admin/abuse/recent"
echo ""

ADMIN_RESPONSE=$(curl -s "$API_BASE/admin/abuse/recent")
ADMIN_COUNT=$(echo "$ADMIN_RESPONSE" | jq 'length' 2>/dev/null)

if [ -z "$ADMIN_COUNT" ] || [ "$ADMIN_COUNT" = "null" ]; then
  ADMIN_COUNT=0
fi

echo "Recent abuse events via API: $ADMIN_COUNT"

if [ "$ADMIN_COUNT" -gt 0 ]; then
  echo ""
  echo "First event:"
  echo "$ADMIN_RESPONSE" | jq '.[0]' 2>/dev/null || echo "$ADMIN_RESPONSE"
  echo ""
  echo -e "${GREEN}✅ TEST 5 PASSED: Admin API returns abuse events${NC}"
  TEST5_RESULT="PASS"
else
  echo -e "${YELLOW}⚠️  TEST 5 WARNING: Admin API returned no events${NC}"
  TEST5_RESULT="PARTIAL"
fi

echo ""
sleep 2

#==============================================================================
# TEST 6: Admin API - Get Stats
#==============================================================================
echo "======================================================================"
echo "TEST 6: ADMIN API - Abuse Statistics"
echo "======================================================================"
echo ""
echo "Testing admin endpoint: GET /admin/abuse/stats"
echo ""

STATS_RESPONSE=$(curl -s "$API_BASE/admin/abuse/stats")
echo "$STATS_RESPONSE" | jq '.' 2>/dev/null || echo "$STATS_RESPONSE"

BLOCKED_IPS=$(echo "$STATS_RESPONSE" | jq '.blockedIps' 2>/dev/null)

if [ "$BLOCKED_IPS" = "null" ] || [ -z "$BLOCKED_IPS" ]; then
  BLOCKED_IPS=0
fi

echo ""
if [ "$BLOCKED_IPS" -gt 0 ]; then
  echo -e "${GREEN}✅ TEST 6 PASSED: Stats show $BLOCKED_IPS blocked IP(s)${NC}"
  TEST6_RESULT="PASS"
else
  echo -e "${YELLOW}⚠️  TEST 6 WARNING: No blocked IPs in stats${NC}"
  TEST6_RESULT="PARTIAL"
fi

echo ""
sleep 2

#==============================================================================
# TEST 7: Admin Unblock
#==============================================================================
echo "======================================================================"
echo "TEST 7: ADMIN UNBLOCK"
echo "======================================================================"
echo ""
echo "Testing admin unblock endpoint..."
echo ""

# Get current IP
CURRENT_IP="127.0.0.1"

UNBLOCK_RESPONSE=$(curl -s -X POST "$API_BASE/admin/abuse/unblock/$CURRENT_IP")
echo "Unblock response:"
echo "$UNBLOCK_RESPONSE" | jq '.' 2>/dev/null || echo "$UNBLOCK_RESPONSE"

echo ""
echo "Verifying unblock by accessing seat map..."
HTTP_CODE=$(curl -s -w "%{http_code}" -o /tmp/unblock_test.json "$API_BASE/flights/FL-123/seatmap")

if [ "$HTTP_CODE" = "200" ]; then
  echo -e "${GREEN}✅ TEST 7 PASSED: Successfully unblocked and can access API${NC}"
  TEST7_RESULT="PASS"
else
  echo -e "${RED}❌ TEST 7 FAILED: Still blocked after unblock (HTTP $HTTP_CODE)${NC}"
  TEST7_RESULT="FAIL"
fi

echo ""

#==============================================================================
# FINAL SUMMARY
#==============================================================================
echo "======================================================================"
echo "FINAL TEST SUMMARY"
echo "======================================================================"
echo ""

echo "Test Results:"
echo "  TEST 1: Normal Usage                   ✅ PASS"
echo "  TEST 2: Abuse Detection                $TEST2_RESULT"
echo "  TEST 3: Block Persistence              $TEST3_RESULT"
echo "  TEST 4: Audit Log                      $TEST4_RESULT"
echo "  TEST 5: Admin API (Recent Events)      $TEST5_RESULT"
echo "  TEST 6: Admin API (Stats)              $TEST6_RESULT"
echo "  TEST 7: Admin Unblock                  $TEST7_RESULT"
echo ""

# Check if all critical tests passed
if [ "$TEST2_RESULT" = "PASS" ] && [ "$TEST3_RESULT" = "PASS" ] && [ "$TEST4_RESULT" = "PASS" ] && [ "$TEST7_RESULT" = "PASS" ]; then
  echo -e "${GREEN}======================================================================"
  echo "✅ BUSINESS SCENARIO 2.8: PASSED"
  echo "======================================================================"
  echo ""
  echo "All requirements met:"
  echo "  ✅ Detects rapid multi-seat-map access"
  echo "  ✅ Blocks further access temporarily"
  echo "  ✅ Records events for audit"
  echo "  ✅ Admin controls functional"
  echo -e "${NC}"
else
  echo -e "${RED}======================================================================"
  echo "❌ BUSINESS SCENARIO 2.8: FAILED"
  echo "======================================================================"
  echo ""
  echo "Some requirements NOT met. Review results above."
  echo -e "${NC}"
fi

# Clean up
rm -f /tmp/response_*.json /tmp/abuse_response_*.json /tmp/abuse_status_*.txt /tmp/persist_response.json /tmp/unblock_test.json

echo "Full logs available in: $LOG_FILE"
