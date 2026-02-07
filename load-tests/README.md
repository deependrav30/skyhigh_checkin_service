# Load Testing Suite

This directory contains load testing scripts for the SkyHigh Check-In Service.

## Prerequisites

```bash
# Install Artillery (recommended for comprehensive load testing)
npm install -g artillery@latest

# Or use curl + bash for simple tests
# (Already available on macOS/Linux)

# PostgreSQL client for verification
brew install postgresql  # macOS
```

## Quick Start

### 1. Concurrent Holds Test (Race Condition)

Tests if multiple users can hold the same seat simultaneously.

```bash
chmod +x concurrent-holds.sh
./concurrent-holds.sh
```

**Expected Result:** Only 1 success out of 100 attempts

---

### 2. Expiry Test (Time-Bound Hold)

Tests if holds automatically expire after 120 seconds.

```bash
chmod +x expiry-test.sh
./expiry-test.sh
```

**Expected Result:** Seat returns to AVAILABLE after ~125 seconds

---

### 3. Artillery Load Test (Full System)

Comprehensive load test with multiple scenarios.

```bash
# Install Artillery if not already installed
npm install -g artillery@latest

# Run the test
artillery run artillery-config.yml

# Run with report generation
artillery run --output results.json artillery-config.yml
artillery report results.json
```

**Monitors:**
- Response times (p50, p95, p99)
- Error rates
- Concurrent users
- Throughput (req/s)

---

## Test Scenarios

### Scenario 1: Race Condition Test

**Purpose:** Verify seat hold exclusivity  
**Duration:** ~30 seconds  
**Load:** 100 concurrent requests  

```bash
./concurrent-holds.sh
```

**Success Criteria:**
- ✅ Exactly 1 hold succeeds
- ✅ 99 holds fail with null/error
- ✅ Database shows 1 HELD seat

---

### Scenario 2: Expiry Test

**Purpose:** Verify automatic hold expiry  
**Duration:** ~125 seconds  
**Load:** Single user  

```bash
./expiry-test.sh
```

**Success Criteria:**
- ✅ Seat HELD immediately after hold request
- ✅ Seat AVAILABLE after 125 seconds
- ✅ Event log shows EXPIRED entry

---

### Scenario 3: Sustained Load Test

**Purpose:** Verify system stability under continuous load  
**Duration:** 4 minutes  
**Load:** 20-50 requests/second  

```bash
artillery run artillery-config.yml
```

**Success Criteria:**
- ✅ p95 latency < 500ms
- ✅ p99 latency < 1000ms
- ✅ Error rate < 1%
- ✅ No database connection exhaustion

---

## Monitoring During Tests

### Real-Time API Monitoring

```bash
# Watch API logs
tail -f /path/to/api.log

# Monitor worker
tail -f /tmp/worker.log | grep expireHolds
```

### Database Monitoring

```bash
# Watch active connections
watch -n 1 "psql postgres://postgres:postgres@localhost:5434/skyhigh \
  -c \"SELECT count(*), state FROM pg_stat_activity WHERE datname='skyhigh' GROUP BY state;\""

# Watch seat states
watch -n 1 "psql postgres://postgres:postgres@localhost:5434/skyhigh \
  -c \"SELECT state, COUNT(*) FROM seats GROUP BY state;\""

# Check for slow queries
psql postgres://postgres:postgres@localhost:5434/skyhigh \
  -c "SELECT pid, now() - query_start AS duration, query 
      FROM pg_stat_activity 
      WHERE state = 'active' AND now() - query_start > interval '1 second';"
```

### Redis Monitoring

```bash
# Monitor Redis latency
redis-cli --latency-history

# Check cache hit rate
redis-cli INFO stats | grep hits

# Watch commands in real-time
redis-cli MONITOR
```

---

## Performance Benchmarks

| Metric | Target | Current | Status |
|--------|--------|---------|--------|
| Hold request p50 | < 50ms | TBD | ⏳ |
| Hold request p99 | < 200ms | TBD | ⏳ |
| Seatmap p50 | < 10ms | TBD | ⏳ |
| Error rate | < 1% | TBD | ⏳ |
| Concurrent users | 500 | TBD | ⏳ |

*Run tests to populate "Current" values*

---

## Troubleshooting

### Test fails with "Connection refused"

**Problem:** API server not running

**Solution:**
```bash
cd api
npx tsx src/server.ts
```

### All holds succeed (race condition test)

**Problem:** Requests not truly concurrent

**Solution:**
```bash
# Increase concurrent attempts
# Edit concurrent-holds.sh: NUM_ATTEMPTS=500
```

### Expiry test times out

**Problem:** Worker not running

**Solution:**
```bash
# Check worker logs
tail -f /tmp/worker.log

# Restart worker if needed
cd api
npx tsx src/worker.ts &
```

### Artillery test shows high error rates

**Problem:** Connection pool exhaustion

**Solution:**
```bash
# Increase database connection pool
# Edit api/src/db.ts:
# max: 50  // Instead of 20
```

---

## Custom Test Scenarios

### Test Specific Seat

```bash
# Modify concurrent-holds.sh
SEAT_ID="12F"  # Change to your target seat
```

### Test Different Load Levels

```bash
# Modify artillery-config.yml
arrivalRate: 100  # Increase from 50 for stress test
```

### Test Hold Expiry at Scale

```bash
# Create 100 holds that will all expire
for i in {1..100}; do
  curl -X POST http://localhost:3002/api/seats/hold \
    -H "Content-Type: application/json" \
    -d "{\"flightId\":\"SK123\",\"seatId\":\"${i}A\",\"passengerId\":\"P${i}\"}" &
done
wait

# Wait for expiry
sleep 125

# Verify all expired
psql postgres://postgres:postgres@localhost:5434/skyhigh \
  -c "SELECT COUNT(*) FROM seats WHERE state='HELD';"
# Expected: 0
```

---

## Results Analysis

### Artillery Report

After running Artillery tests, open the HTML report:

```bash
artillery run --output results.json artillery-config.yml
artillery report results.json
open artillery_report_*.html
```

The report shows:
- Request rate over time
- Response time distribution
- Error rate
- Scenario-specific metrics

### Database Query Analysis

```sql
-- Check most held seats (contention points)
SELECT seat_id, COUNT(*) as hold_attempts
FROM seat_events
WHERE event_type = 'HELD'
GROUP BY seat_id
ORDER BY hold_attempts DESC
LIMIT 10;

-- Check expiry frequency
SELECT COUNT(*), DATE_TRUNC('minute', created_at) as minute
FROM seat_events
WHERE event_type = 'EXPIRED'
GROUP BY minute
ORDER BY minute DESC
LIMIT 10;
```

---

## Continuous Integration

Add to your CI/CD pipeline:

```yaml
# .github/workflows/load-test.yml
name: Load Tests
on: [push]
jobs:
  load-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Start services
        run: docker-compose up -d
      - name: Run load tests
        run: |
          npm install -g artillery
          artillery run load-tests/artillery-config.yml
      - name: Check performance thresholds
        run: artillery run --quiet load-tests/artillery-config.yml | grep "ok"
```

---

## Next Steps

1. ✅ Run `concurrent-holds.sh` to verify race condition handling
2. ✅ Run `expiry-test.sh` to verify time-bound holds
3. ✅ Run `artillery run artillery-config.yml` for full load test
4. 📊 Update performance benchmarks table with your results
5. 🚀 Optimize bottlenecks identified during testing

---

For detailed implementation analysis, see `../TECHNICAL_IMPLEMENTATION.md`.
