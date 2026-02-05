# SkyHigh Check-In Service - API Examples

This document provides curl examples for testing all API endpoints.

## Prerequisites

Ensure services are running:
- API: http://localhost:3002
- Worker: Background service
- Postgres: localhost:5434
- Redis: localhost:6381

## 1. Health Check

```bash
curl http://localhost:3002/health
# Expected: {"status":"ok"}

curl http://localhost:3002/ready
# Expected: {"status":"ok"}
```

## 2. PNR Login

```bash
# Login with demo credentials
curl -X POST http://localhost:3002/auth/pnr-login \
  -H "Content-Type: application/json" \
  -d '{
    "pnr": "DEMO123",
    "lastName": "demo"
  }'

# Expected: 
# {
#   "checkinId": "chk-demo-1",
#   "flightId": "FL-123",
#   "passenger": {
#     "firstName": "Demo",
#     "lastName": "User"
#   },
#   "seatMap": { ... }
# }
```

## 3. Get Seat Map

```bash
curl http://localhost:3002/flights/FL-123/seatmap

# Expected:
# {
#   "flightId": "FL-123",
#   "lastUpdated": "2026-02-04T...",
#   "seats": [
#     {"seatId": "1A", "state": "AVAILABLE", ...},
#     {"seatId": "1B", "state": "CONFIRMED", ...},
#     {"seatId": "1C", "state": "HELD", ...}
#   ]
# }
```

## 4. Hold a Seat (120 seconds)

```bash
curl -X POST http://localhost:3002/flights/FL-123/seats/1A/hold \
  -H "Content-Type: application/json" \
  -d '{
    "passengerId": "passenger-demo-1"
  }'

# Expected:
# {
#   "holdId": "hold-1A",
#   "seatId": "1A",
#   "flightId": "FL-123",
#   "state": "HELD",
#   "holdExpiresAt": "2026-02-04T..." // 120 seconds from now
# }
```

## 5. Confirm Hold

```bash
curl -X POST http://localhost:3002/holds/hold-1A/confirm \
  -H "Content-Type: application/json" \
  -d '{
    "passengerId": "passenger-demo-1"
  }'

# Expected:
# {
#   "seatId": "1A",
#   "state": "CONFIRMED",
#   "message": "Seat confirmed"
# }
```

## 6. Cancel Hold

```bash
curl -X POST http://localhost:3002/holds/hold-1A/cancel \
  -H "Content-Type: application/json" \
  -d '{
    "passengerId": "passenger-demo-1"
  }'

# Expected:
# {
#   "seatId": "1A",
#   "state": "AVAILABLE",
#   "message": "Hold cancelled, seat released"
# }
```

## 7. Join Waitlist

```bash
curl -X POST http://localhost:3002/flights/FL-123/waitlist \
  -H "Content-Type: application/json" \
  -d '{
    "passengerId": "passenger-demo-2",
    "preferences": {
      "seatType": "window"
    }
  }'

# Expected:
# {
#   "waitlistId": "wl-...",
#   "position": 1,
#   "message": "Added to waitlist"
# }
```

## 8. Submit Baggage (Normal Weight)

```bash
curl -X POST http://localhost:3002/checkins/chk-demo-1/baggage \
  -H "Content-Type: application/json" \
  -d '{
    "weight": 20
  }'

# Expected:
# {
#   "checkinId": "chk-demo-1",
#   "state": "COMPLETED",
#   "paymentRequired": false
# }
```

## 9. Submit Baggage (Overweight - Triggers Payment)

```bash
curl -X POST http://localhost:3002/checkins/chk-demo-1/baggage \
  -H "Content-Type: application/json" \
  -d '{
    "weight": 30
  }'

# Expected:
# {
#   "checkinId": "chk-demo-1",
#   "state": "WAITING_FOR_PAYMENT",
#   "paymentRequired": true,
#   "paymentIntent": {
#     "intentId": "pi-...",
#     "amount": 70,
#     "status": "PENDING"
#   }
# }
```

## 10. Payment Webhook (Simulate Payment Completion)

```bash
curl -X POST http://localhost:3002/payments/webhook \
  -H "Content-Type: application/json" \
  -d '{
    "intentId": "pi-123",
    "status": "succeeded",
    "amount": 70
  }'

# Expected:
# {
#   "checkinId": "chk-demo-1",
#   "state": "COMPLETED",
#   "message": "Payment processed, check-in completed"
# }
```

## Testing Scenarios

### Scenario 1: Normal Check-In Flow
```bash
# 1. Login
CHECKIN_ID=$(curl -s -X POST http://localhost:3002/auth/pnr-login \
  -H "Content-Type: application/json" \
  -d '{"pnr":"DEMO123","lastName":"demo"}' | jq -r '.checkinId')

# 2. Hold seat
HOLD_ID=$(curl -s -X POST http://localhost:3002/flights/FL-123/seats/1A/hold \
  -H "Content-Type: application/json" \
  -d '{"passengerId":"passenger-demo-1"}' | jq -r '.holdId')

# 3. Confirm seat
curl -X POST http://localhost:3002/holds/$HOLD_ID/confirm \
  -H "Content-Type: application/json" \
  -d '{"passengerId":"passenger-demo-1"}'

# 4. Submit baggage
curl -X POST http://localhost:3002/checkins/$CHECKIN_ID/baggage \
  -H "Content-Type: application/json" \
  -d '{"weight":20}'
```

### Scenario 2: Hold Expiry Test
```bash
# Hold a seat
curl -X POST http://localhost:3002/flights/FL-123/seats/1A/hold \
  -H "Content-Type: application/json" \
  -d '{"passengerId":"passenger-demo-1"}'

# Wait 120+ seconds, then check seat map
sleep 125
curl http://localhost:3002/flights/FL-123/seatmap | jq '.seats[] | select(.seatId=="1A")'
# Should show state: "AVAILABLE"
```

### Scenario 3: Rate Limit Test
```bash
# Make rapid requests (should trigger burst protection after 30)
for i in {1..35}; do
  curl -s http://localhost:3002/flights/FL-123/seatmap > /dev/null
  echo "Request $i"
done
# After 30 requests in 5 seconds, should receive 429 Too Many Requests
```

### Scenario 4: Concurrent Holds (Conflict Resolution)
```bash
# Try to hold the same seat from two different terminals simultaneously
# Terminal 1:
curl -X POST http://localhost:3002/flights/FL-123/seats/1A/hold \
  -H "Content-Type: application/json" \
  -d '{"passengerId":"passenger-1"}'

# Terminal 2 (immediately):
curl -X POST http://localhost:3002/flights/FL-123/seats/1A/hold \
  -H "Content-Type: application/json" \
  -d '{"passengerId":"passenger-2"}'
# Second request should fail with "Seat not available"
```

## Performance Testing

### Measure Seat Map Response Time (P95 < 1s target)
```bash
# Using Apache Bench (install: brew install apache-bench)
ab -n 100 -c 10 http://localhost:3002/flights/FL-123/seatmap

# Check that 95% of requests complete under 1000ms
```

### Monitor Worker Processing
```bash
# Watch worker logs
tail -f logs/worker.log

# Observe:
# - Hold expiry processing (every 5s)
# - Waitlist assignment (every 5s)
# - Cache reconciliation (every 60s)
```

## Swagger Documentation

For interactive API testing, open:
```
http://localhost:3002/docs
```

All endpoints are documented with request/response schemas and can be tested directly from the browser.
