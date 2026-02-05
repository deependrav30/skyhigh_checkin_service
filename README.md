# SkyHigh Check-In Service

A comprehensive airline check-in system with seat selection, hold management, waitlist, and payment integration.

## Features

- **PNR Login**: Authenticate with PNR + last name (with dummy details option)
- **Seat Map**: Real-time seat availability with Redis caching (P95 < 1s)
- **Hold Management**: 120-second seat holds with automatic expiry
- **Confirmation**: Confirm held seats with idempotency
- **Waitlist**: FIFO queue with automatic assignment when seats become available
- **Baggage & Payment**: Overweight baggage detection with payment pause/resume
- **Rate Limiting**: Per-route limits + burst detection (>30 req/5s → 10min block)
- **Background Workers**: Automatic hold expiry, waitlist assignment, cache reconciliation

## Tech Stack

- **Backend**: Fastify 4.29.1 + TypeScript (ESM)
- **Frontend**: Vite + React 18 + TypeScript
- **Database**: PostgreSQL 15
- **Cache**: Redis 7
- **Schema Validation**: TypeBox
- **API Docs**: Swagger UI

## Quick Start

### Option 1: Automated Startup (Recommended)

```bash
./start.sh
```

This will:
- Start Postgres and Redis (if not running)
- Apply database migrations
- Start API server (port 3002)
- Start worker service
- Start Web UI (port 5173)

To stop all services:
```bash
./stop.sh
```

### Option 2: Manual Startup

#### 1. Start Infrastructure (Postgres + Redis)

```bash
docker-compose up -d postgres redis
```

#### 2. Run Migrations

```bash
cd api
npm install
npm run migrate
```

#### 3. Start API Server

```bash
cd api
npx tsx src/server.ts
```

API will be available at: http://localhost:3002

#### 4. Start Worker Service (in separate terminal)

```bash
cd api
npx tsx src/worker.ts
```

#### 5. Start Web UI (in separate terminal)

```bash
cd web
npm install
npm run dev
```

Web UI will be available at: http://localhost:5173

### 6. Access Services

- **Web UI**: http://localhost:5173
- **API Docs**: http://localhost:3002/docs
- **API Health**: http://localhost:3002/health

## API Endpoints

- `POST /auth/pnr-login` - Login with PNR + last name
- `GET /flights/:flightId/seatmap` - Get seat map
- `POST /flights/:flightId/seats/:seatId/hold` - Hold a seat
- `POST /holds/:holdId/confirm` - Confirm held seat
- `POST /holds/:holdId/cancel` - Cancel hold
- `POST /flights/:flightId/waitlist` - Join waitlist
- `POST /checkins/:checkinId/baggage` - Submit baggage (triggers payment if overweight)
- `POST /payments/webhook` - Payment webhook (resumes check-in after payment)
- `GET /health` - Health check
- `GET /ready` - Readiness check

## Configuration

Environment variables (see `api/.env`):

```env
DATABASE_URL=postgres://postgres:postgres@localhost:5434/skyhigh
REDIS_URL=redis://localhost:6381
API_PORT=3002
API_HOST=0.0.0.0
```

## Demo Data

The system includes demo data for testing:

- **PNR**: `DEMO123` / **Last Name**: `demo`
- **Flight**: FL-123
- **Seats**: 1A (AVAILABLE), 1B (CONFIRMED), 1C (HELD)

### Using the Web UI

1. Open http://localhost:5173
2. Click "Use Demo Details" button for instant login
3. Select an available seat (green) from the seat map
4. Seat will be held for 120 seconds (countdown shown)
5. Click "Confirm Seat" to lock in your selection
6. Enter baggage weight (try >23kg to test payment flow)
7. Complete check-in!

## Example API Calls

### Login
```bash
curl -X POST http://localhost:3002/auth/pnr-login \
  -H "Content-Type: application/json" \
  -d '{"pnr":"DEMO123","lastName":"demo"}'
```

### Hold Seat
```bash
curl -X POST http://localhost:3002/flights/FL-123/seats/1A/hold \
  -H "Content-Type: application/json" \
  -d '{"passengerId":"passenger-demo-1"}'
```

### Confirm Hold
```bash
curl -X POST http://localhost:3002/holds/hold-1A/confirm \
  -H "Content-Type: application/json" \
  -d '{"passengerId":"passenger-demo-1"}'
```

## Development

- **Lint**: `npm run lint`
- **Format**: `npm run format`
- **Test**: `npm test` (coming soon)

## Project Structure

```
api/
  src/
    server.ts          # Fastify app with routes
    worker.ts          # Background jobs
    seat-service.ts    # Seat management logic
    payment.ts         # Payment integration
    cache-reconcile.ts # Cache reconciliation
    rate-limit.ts      # Burst detection
    db.ts              # Postgres client
    cache.ts           # Redis client
    config.ts          # Configuration
    schemas.ts         # TypeBox schemas
    migrate.ts         # Migration runner
migrations/
  0001_init.sql        # Schema
web/
  src/
    App.tsx            # Main application flow
    api.ts             # API client functions
    types.ts           # TypeScript interfaces
    components/
      PNRLogin.tsx     # Login form with demo button
      SeatMapView.tsx  # Interactive seat selection grid
   x] Backend API with seat hold/confirm/cancel
- [x] Worker service for hold expiry and waitlist
- [x] Web UI with PNR login and seat selection
- [x] Baggage and payment flow UIage entry and payment
  0002_seed_demo.sql   # Demo data
mocks/
  mock-weight.js       # Weight service simulator
  mock-payment.js      # Payment service simulator
```

## Next Steps

- [ ] Build UI (Vite + React)
- [ ] Add comprehensive tests (>80% coverage)
- [ ] Add observability (metrics, logs, traces)
- [ ] Production deployment guide
- [ ] Load testing validation

## Documentation

- [PRD.md](PRD.md) - Product Requirements
- [FEATURE_BREAKDOWN.md](FEATURE_BREAKDOWN.md) - Feature specifications
- [API_SPECIFICATION.yml](API-SPECIFICATION.yml) - OpenAPI spec
- [API_EXAMPLES.md](API_EXAMPLES.md) - Curl examples and testing scenarios
- [WORKFLOW_DESIGN.md](WORKFLOW_DESIGN.md) - Technical design
- [TODO.md](TODO.md) - Task tracking
