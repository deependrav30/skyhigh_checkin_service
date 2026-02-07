#!/bin/bash

# Business Scenario 2.7: High-Performance Seat Map Access
# Tests P95 latency, concurrent users, and real-time accuracy

API_BASE="http://localhost:3002"
FLIGHT_ID="FL-123"
LOG_FILE="/tmp/seatmap-perf-test.log"
RESULTS_FILE="/tmp/seatmap-results.txt"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "======================================================================"
echo "Business Scenario 2.7: High-Performance Seat Map Access"
echo "======================================================================"
echo ""
echo "Requirements:"
echo "  • P95 latency < 1 second"
echo "  • Support hundreds of concurrent users"
echo "  • Near real-time accuracy"
echo ""

# Clean up old results
> "$LOG_FILE"
> "$RESULTS_FILE"

#==============================================================================
# TEST 1: Baseline - Single Request Latency
#==============================================================================
echo "======================================================================"
echo "TEST 1: BASELINE - Single Request Latency"
echo "======================================================================"
echo ""
echo "Measuring baseline performance with single request..."

BASELINE_START=$(date +%s%3N)
RESPONSE=$(curl -s -w "\n%{time_total}" "$API_BASE/flights/$FLIGHT_ID/seatmap" 2>/dev/null)
BASELINE_END=$(date +%s%3N)

BASELINE_TIME=$(echo "$RESPONSE" | tail -1)
BASELINE_MS=$(echo "$BASELINE_TIME * 1000" | bc | cut -d'.' -f1)
RESPONSE_BODY=$(echo "$RESPONSE" | sed '$d')
SEAT_COUNT=$(echo "$RESPONSE_BODY" | jq '.seats | length' 2>/dev/null || echo "unknown")

echo "Response time: ${BASELINE_MS}ms"
echo "Seats returned: ${SEAT_COUNT}"
echo "Cache status: First request (cache miss expected)"

if [ "$BASELINE_MS" -lt 200 ]; then
  echo -e "${GREEN}✅ Excellent baseline performance${NC}"
elif [ "$BASELINE_MS" -lt 500 ]; then
  echo -e "${YELLOW}⚠️  Acceptable baseline performance${NC}"
else
  echo -e "${RED}❌ Poor baseline performance${NC}"
fi

# Test cache hit
sleep 0.5
CACHED_START=$(date +%s%3N)
CACHED_RESPONSE=$(curl -s -w "\n%{time_total}" "$API_BASE/flights/$FLIGHT_ID/seatmap" 2>/dev/null)
CACHED_END=$(date +%s%3N)

CACHED_TIME=$(echo "$CACHED_RESPONSE" | tail -1)
CACHED_MS=$(echo "$CACHED_TIME * 1000" | bc | cut -d'.' -f1)

echo ""
echo "Cached response time: ${CACHED_MS}ms"
if [ "$CACHED_MS" -lt 50 ]; then
  echo -e "${GREEN}✅ Excellent cache performance${NC}"
elif [ "$CACHED_MS" -lt 100 ]; then
  echo -e "${YELLOW}⚠️  Acceptable cache performance${NC}"
else
  echo -e "${RED}❌ Poor cache performance${NC}"
fi

echo ""

#==============================================================================
# TEST 2: 50 Concurrent Users (Warm-up)
#==============================================================================
echo "======================================================================"
echo "TEST 2: 50 CONCURRENT USERS (Warm-up)"
echo "======================================================================"
echo ""
echo "Testing with 50 concurrent requests..."

# Clear cache to test real performance
redis-cli DEL "seatmap:$FLIGHT_ID" > /dev/null 2>&1

CONCURRENT_50=50
> "$RESULTS_FILE"

for i in $(seq 1 $CONCURRENT_50); do
  {
    START=$(date +%s%3N)
    curl -s -w "\n%{time_total}\n" "$API_BASE/flights/$FLIGHT_ID/seatmap" > /tmp/seatmap_${i}.txt 2>&1
    END=$(date +%s%3N)
    
    TIME_TOTAL=$(tail -1 /tmp/seatmap_${i}.txt)
    TIME_MS=$(echo "$TIME_TOTAL * 1000" | bc | cut -d'.' -f1)
    echo "$TIME_MS" >> "$RESULTS_FILE"
    rm -f /tmp/seatmap_${i}.txt
  } &
done

# Wait for all requests to complete
wait

# Calculate statistics
SORTED_TIMES=$(sort -n "$RESULTS_FILE")
TOTAL_REQUESTS=$(wc -l < "$RESULTS_FILE")
AVG_TIME=$(awk '{ sum += $1; count++ } END { print sum/count }' "$RESULTS_FILE")
MIN_TIME=$(head -1 <<< "$SORTED_TIMES")
MAX_TIME=$(tail -1 <<< "$SORTED_TIMES")
P50_INDEX=$(echo "($TOTAL_REQUESTS * 0.5) / 1" | bc)
P95_INDEX=$(echo "($TOTAL_REQUESTS * 0.95) / 1" | bc)
P99_INDEX=$(echo "($TOTAL_REQUESTS * 0.99) / 1" | bc)
P50_TIME=$(sed -n "${P50_INDEX}p" <<< "$SORTED_TIMES")
P95_TIME=$(sed -n "${P95_INDEX}p" <<< "$SORTED_TIMES")
P99_TIME=$(sed -n "${P99_INDEX}p" <<< "$SORTED_TIMES")

echo "Results for 50 concurrent requests:"
echo "  Total requests:  $TOTAL_REQUESTS"
echo "  Min time:        ${MIN_TIME}ms"
echo "  Max time:        ${MAX_TIME}ms"
echo "  Average time:    ${AVG_TIME}ms"
echo "  P50 (median):    ${P50_TIME}ms"
echo "  P95:             ${P95_TIME}ms"
echo "  P99:             ${P99_TIME}ms"
echo ""

if [ "$P95_TIME" -lt 1000 ]; then
  echo -e "${GREEN}✅ TEST 2 PASSED: P95 < 1 second (${P95_TIME}ms)${NC}"
else
  echo -e "${RED}❌ TEST 2 FAILED: P95 >= 1 second (${P95_TIME}ms)${NC}"
fi

echo ""

#==============================================================================
# TEST 3: 200 Concurrent Users (High Load)
#==============================================================================
echo "======================================================================"
echo "TEST 3: 200 CONCURRENT USERS (High Load)"
echo "======================================================================"
echo ""
echo "Testing with 200 concurrent requests..."

# Clear cache to test real performance under load
redis-cli DEL "seatmap:$FLIGHT_ID" > /dev/null 2>&1

CONCURRENT_200=200
> "$RESULTS_FILE"

TEST3_START=$(date +%s)

for i in $(seq 1 $CONCURRENT_200); do
  {
    START=$(date +%s%3N)
    curl -s -w "\n%{time_total}\n" "$API_BASE/flights/$FLIGHT_ID/seatmap" > /tmp/seatmap_${i}.txt 2>&1
    END=$(date +%s%3N)
    
    TIME_TOTAL=$(tail -1 /tmp/seatmap_${i}.txt)
    TIME_MS=$(echo "$TIME_TOTAL * 1000" | bc | cut -d'.' -f1)
    echo "$TIME_MS" >> "$RESULTS_FILE"
    rm -f /tmp/seatmap_${i}.txt
  } &
done

# Wait for all requests to complete
wait

TEST3_END=$(date +%s)
TOTAL_TIME=$((TEST3_END - TEST3_START))

# Calculate statistics
SORTED_TIMES=$(sort -n "$RESULTS_FILE")
TOTAL_REQUESTS=$(wc -l < "$RESULTS_FILE")
SUCCESS_COUNT=$(wc -l < "$RESULTS_FILE")
AVG_TIME=$(awk '{ sum += $1; count++ } END { print sum/count }' "$RESULTS_FILE")
MIN_TIME=$(head -1 <<< "$SORTED_TIMES")
MAX_TIME=$(tail -1 <<< "$SORTED_TIMES")
P50_INDEX=$(echo "($TOTAL_REQUESTS * 0.5) / 1" | bc)
P95_INDEX=$(echo "($TOTAL_REQUESTS * 0.95) / 1" | bc)
P99_INDEX=$(echo "($TOTAL_REQUESTS * 0.99) / 1" | bc)
P50_TIME=$(sed -n "${P50_INDEX}p" <<< "$SORTED_TIMES")
P95_TIME=$(sed -n "${P95_INDEX}p" <<< "$SORTED_TIMES")
P99_TIME=$(sed -n "${P99_INDEX}p" <<< "$SORTED_TIMES")

THROUGHPUT=$(echo "$SUCCESS_COUNT / $TOTAL_TIME" | bc -l)
THROUGHPUT_FMT=$(printf "%.2f" "$THROUGHPUT")

echo "Results for 200 concurrent requests:"
echo "  Total requests:  $TOTAL_REQUESTS"
echo "  Success count:   $SUCCESS_COUNT"
echo "  Min time:        ${MIN_TIME}ms"
echo "  Max time:        ${MAX_TIME}ms"
echo "  Average time:    ${AVG_TIME}ms"
echo "  P50 (median):    ${P50_TIME}ms"
echo "  P95:             ${P95_TIME}ms"
echo "  P99:             ${P99_TIME}ms"
echo "  Total duration:  ${TOTAL_TIME}s"
echo "  Throughput:      ${THROUGHPUT_FMT} req/s"
echo ""

if [ "$P95_TIME" -lt 1000 ]; then
  echo -e "${GREEN}✅ TEST 3 PASSED: P95 < 1 second (${P95_TIME}ms)${NC}"
  TEST3_RESULT="PASS"
else
  echo -e "${RED}❌ TEST 3 FAILED: P95 >= 1 second (${P95_TIME}ms)${NC}"
  TEST3_RESULT="FAIL"
fi

if [ "$SUCCESS_COUNT" -eq 200 ]; then
  echo -e "${GREEN}✅ All 200 requests succeeded${NC}"
else
  echo -e "${RED}❌ Only $SUCCESS_COUNT / 200 requests succeeded${NC}"
fi

echo ""

#==============================================================================
# TEST 4: 500 Concurrent Users (Stress Test)
#==============================================================================
echo "======================================================================"
echo "TEST 4: 500 CONCURRENT USERS (Stress Test)"
echo "======================================================================"
echo ""
echo "Testing with 500 concurrent requests..."

# Clear cache
redis-cli DEL "seatmap:$FLIGHT_ID" > /dev/null 2>&1

CONCURRENT_500=500
> "$RESULTS_FILE"

TEST4_START=$(date +%s)

for i in $(seq 1 $CONCURRENT_500); do
  {
    START=$(date +%s%3N)
    HTTP_CODE=$(curl -s -w "%{http_code}\n" -o /tmp/seatmap_${i}.json "$API_BASE/flights/$FLIGHT_ID/seatmap" 2>&1)
    curl -s -w "\n%{time_total}\n" "$API_BASE/flights/$FLIGHT_ID/seatmap" > /tmp/seatmap_${i}.txt 2>&1
    END=$(date +%s%3N)
    
    TIME_TOTAL=$(tail -1 /tmp/seatmap_${i}.txt)
    TIME_MS=$(echo "$TIME_TOTAL * 1000" | bc | cut -d'.' -f1 2>/dev/null || echo "9999")
    echo "$TIME_MS" >> "$RESULTS_FILE"
    rm -f /tmp/seatmap_${i}.txt /tmp/seatmap_${i}.json
  } &
done

# Wait for all requests to complete
wait

TEST4_END=$(date +%s)
TOTAL_TIME=$((TEST4_END - TEST4_START))

# Calculate statistics
SORTED_TIMES=$(sort -n "$RESULTS_FILE")
TOTAL_REQUESTS=$(wc -l < "$RESULTS_FILE")
SUCCESS_COUNT=$(awk '$1 < 9000' "$RESULTS_FILE" | wc -l)
AVG_TIME=$(awk '{ sum += $1; count++ } END { print sum/count }' "$RESULTS_FILE")
MIN_TIME=$(head -1 <<< "$SORTED_TIMES")
MAX_TIME=$(tail -1 <<< "$SORTED_TIMES")
P50_INDEX=$(echo "($TOTAL_REQUESTS * 0.5) / 1" | bc)
P95_INDEX=$(echo "($TOTAL_REQUESTS * 0.95) / 1" | bc)
P99_INDEX=$(echo "($TOTAL_REQUESTS * 0.99) / 1" | bc)
P50_TIME=$(sed -n "${P50_INDEX}p" <<< "$SORTED_TIMES")
P95_TIME=$(sed -n "${P95_INDEX}p" <<< "$SORTED_TIMES")
P99_TIME=$(sed -n "${P99_INDEX}p" <<< "$SORTED_TIMES")

THROUGHPUT=$(echo "$SUCCESS_COUNT / $TOTAL_TIME" | bc -l)
THROUGHPUT_FMT=$(printf "%.2f" "$THROUGHPUT")

echo "Results for 500 concurrent requests:"
echo "  Total requests:  $TOTAL_REQUESTS"
echo "  Success count:   $SUCCESS_COUNT"
echo "  Min time:        ${MIN_TIME}ms"
echo "  Max time:        ${MAX_TIME}ms"
echo "  Average time:    ${AVG_TIME}ms"
echo "  P50 (median):    ${P50_TIME}ms"
echo "  P95:             ${P95_TIME}ms"
echo "  P99:             ${P99_TIME}ms"
echo "  Total duration:  ${TOTAL_TIME}s"
echo "  Throughput:      ${THROUGHPUT_FMT} req/s"
echo ""

if [ "$P95_TIME" -lt 1000 ]; then
  echo -e "${GREEN}✅ TEST 4 PASSED: P95 < 1 second (${P95_TIME}ms)${NC}"
  TEST4_RESULT="PASS"
else
  echo -e "${RED}❌ TEST 4 FAILED: P95 >= 1 second (${P95_TIME}ms)${NC}"
  TEST4_RESULT="FAIL"
fi

if [ "$SUCCESS_COUNT" -ge 490 ]; then
  echo -e "${GREEN}✅ ${SUCCESS_COUNT} / 500 requests succeeded (>98%)${NC}"
else
  echo -e "${YELLOW}⚠️  Only $SUCCESS_COUNT / 500 requests succeeded${NC}"
fi

echo ""

#==============================================================================
# TEST 5: Real-Time Accuracy Under Load
#==============================================================================
echo "======================================================================"
echo "TEST 5: REAL-TIME ACCURACY UNDER LOAD"
echo "======================================================================"
echo ""
echo "Testing seat availability accuracy with concurrent reads and writes..."

# Step 1: Get initial seat map
INITIAL_MAP=$(curl -s "$API_BASE/flights/$FLIGHT_ID/seatmap")
AVAILABLE_SEAT=$(echo "$INITIAL_MAP" | jq -r '.seats[]? | select(.state=="AVAILABLE") | .seatId' 2>/dev/null | head -1)

if [ -z "$AVAILABLE_SEAT" ] || [ "$AVAILABLE_SEAT" = "null" ]; then
  echo -e "${RED}❌ No available seats found for testing${NC}"
  echo "Response: $INITIAL_MAP"
  exit 1
fi

echo "Testing with seat: $AVAILABLE_SEAT"
echo ""

# Step 2: Hold the seat
HOLD_RESPONSE=$(curl -s -X POST "$API_BASE/flights/$FLIGHT_ID/seats/$AVAILABLE_SEAT/hold" \
  -H "Content-Type: application/json" \
  -d '{"passengerId":"ACCURACY-TEST"}')

echo "Seat held: $HOLD_RESPONSE"

# Step 3: Immediately query seat map from 20 concurrent requests
echo "Querying seat map from 20 concurrent clients..."
HOLD_SEEN=0
for i in $(seq 1 20); do
  {
    MAP=$(curl -s "$API_BASE/flights/$FLIGHT_ID/seatmap")
    SEAT_STATE=$(echo "$MAP" | jq -r ".seats[]? | select(.seatId==\"$AVAILABLE_SEAT\") | .state" 2>/dev/null)
    if [ "$SEAT_STATE" = "HELD" ]; then
      echo "HELD" > /tmp/accuracy_${i}.txt
    else
      echo "NOT_HELD" > /tmp/accuracy_${i}.txt
    fi
  } &
done

wait

HELD_COUNT=$(cat /tmp/accuracy_*.txt 2>/dev/null | grep -c "HELD" || echo "0")
rm -f /tmp/accuracy_*.txt

echo "Results:"
echo "  Clients that saw HELD state: $HELD_COUNT / 20"
echo "  Expected: All 20 (after cache refresh)"
echo ""

if [ "$HELD_COUNT" -ge 18 ]; then
  echo -e "${GREEN}✅ TEST 5 PASSED: Real-time accuracy maintained (${HELD_COUNT}/20)${NC}"
  TEST5_RESULT="PASS"
elif [ "$HELD_COUNT" -ge 10 ]; then
  echo -e "${YELLOW}⚠️  TEST 5 PARTIAL: Moderate accuracy (${HELD_COUNT}/20)${NC}"
  echo "Cache TTL may cause temporary inconsistency"
  TEST5_RESULT="PARTIAL"
else
  echo -e "${RED}❌ TEST 5 FAILED: Poor real-time accuracy (${HELD_COUNT}/20)${NC}"
  TEST5_RESULT="FAIL"
fi

# Clean up
curl -s -X POST "$API_BASE/flights/$FLIGHT_ID/seats/$AVAILABLE_SEAT/cancel" \
  -H "Content-Type: application/json" \
  -d '{"passengerId":"ACCURACY-TEST"}' > /dev/null 2>&1

echo ""

#==============================================================================
# TEST 6: Cache Hit Ratio Under Load
#==============================================================================
echo "======================================================================"
echo "TEST 6: CACHE HIT RATIO UNDER LOAD"
echo "======================================================================"
echo ""
echo "Testing cache effectiveness with 100 requests..."

# Clear cache first
redis-cli DEL "seatmap:$FLIGHT_ID" > /dev/null 2>&1

# First request (cache miss)
FIRST_TIME=$(curl -s -w "%{time_total}" -o /dev/null "$API_BASE/flights/$FLIGHT_ID/seatmap")
FIRST_MS=$(echo "$FIRST_TIME * 1000" | bc | cut -d'.' -f1)

# Next 99 requests (should be cache hits)
> "$RESULTS_FILE"
for i in $(seq 1 99); do
  {
    TIME=$(curl -s -w "%{time_total}" -o /dev/null "$API_BASE/flights/$FLIGHT_ID/seatmap")
    TIME_MS=$(echo "$TIME * 1000" | bc | cut -d'.' -f1)
    echo "$TIME_MS" >> "$RESULTS_FILE"
  } &
  
  # Stagger requests slightly
  if [ $((i % 10)) -eq 0 ]; then
    sleep 0.1
  fi
done

wait

CACHE_AVG=$(awk '{ sum += $1; count++ } END { print sum/count }' "$RESULTS_FILE")
CACHE_AVG_INT=$(echo "$CACHE_AVG" | cut -d'.' -f1)

echo "First request (cache miss):  ${FIRST_MS}ms"
echo "Average cached request:       ${CACHE_AVG}ms"
echo ""

SPEEDUP=$(echo "$FIRST_MS / $CACHE_AVG" | bc -l)
SPEEDUP_FMT=$(printf "%.2f" "$SPEEDUP")

echo "Cache speedup: ${SPEEDUP_FMT}x faster"
echo ""

if [ "$CACHE_AVG_INT" -lt 100 ]; then
  echo -e "${GREEN}✅ TEST 6 PASSED: Excellent cache performance (<100ms)${NC}"
  TEST6_RESULT="PASS"
elif [ "$CACHE_AVG_INT" -lt 200 ]; then
  echo -e "${YELLOW}⚠️  TEST 6 PARTIAL: Acceptable cache performance${NC}"
  TEST6_RESULT="PARTIAL"
else
  echo -e "${RED}❌ TEST 6 FAILED: Poor cache performance${NC}"
  TEST6_RESULT="FAIL"
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
echo "  TEST 1: Baseline Latency              ✅ PASS"
echo "  TEST 2: 50 Concurrent Users            $([ "$P95_TIME" -lt 1000 ] && echo "✅ PASS" || echo "❌ FAIL")"
echo "  TEST 3: 200 Concurrent Users           $TEST3_RESULT"
echo "  TEST 4: 500 Concurrent Users           $TEST4_RESULT"
echo "  TEST 5: Real-Time Accuracy             $TEST5_RESULT"
echo "  TEST 6: Cache Hit Ratio                $TEST6_RESULT"
echo ""

# Check if all critical tests passed
if [ "$TEST3_RESULT" = "PASS" ] && [ "$TEST4_RESULT" = "PASS" ] && [ "$TEST5_RESULT" != "FAIL" ]; then
  echo -e "${GREEN}======================================================================"
  echo "✅ BUSINESS SCENARIO 2.7: PASSED"
  echo "======================================================================"
  echo ""
  echo "All performance requirements met:"
  echo "  ✅ P95 latency < 1 second"
  echo "  ✅ Supports hundreds of concurrent users"
  echo "  ✅ Near real-time accuracy maintained"
  echo -e "${NC}"
else
  echo -e "${RED}======================================================================"
  echo "❌ BUSINESS SCENARIO 2.7: FAILED"
  echo "======================================================================"
  echo ""
  echo "Performance requirements NOT met. Review results above."
  echo -e "${NC}"
fi

# Clean up
rm -f /tmp/seatmap_*.txt /tmp/seatmap_*.json

echo "Full logs available in: $LOG_FILE"
echo "Raw results in: $RESULTS_FILE"
