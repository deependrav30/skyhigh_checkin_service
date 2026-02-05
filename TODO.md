# TODO — Feature-wise Plan

## 0) Initial Setup ✅
- [x] Root package.json/workspaces, shared tsconfig base
- [x] docker-compose with Postgres, Redis, api, worker, mocks
- [x] .env.example and config loading
- [x] Lint/format/test tooling (eslint, prettier, vitest/jest)
- [x] PROJECT_STRUCTURE.md outline
- [x] Wire Swagger UI at /docs and ensure API-SPECIFICATION.yml stays in sync with schemas
- [ ] CI placeholder (optional) to run lint + tests

## 1) Data Model & Migrations ✅
- [x] Migrations: seats, seat_events, waitlist, checkins, payment_intents
- [x] Seed demo flight/seat map and dummy PNR booking
- [x] DB client wrapper/pooling

## 2) Seat Map API + Cache ✅
- [x] GET /flights/{id}/seatmap from Redis cache
- [x] Cache warm/invalidate on seat changes; periodic reconcile
- [x] Seat map response watermark (last_updated)
- [ ] P95 <1s target validated in local load smoke

## 3) Seat Hold/Confirm/Cancel ✅
- [x] POST hold with conditional AVAILABLE→HELD (120s TTL)
- [x] POST confirm (HELD→CONFIRMED, ownership check)
- [x] POST cancel/release with audit and enqueue waitlist
- [x] Emit seat_events; update cache
- [x] Idempotent responses for duplicate confirm/cancel by same actor

## 4) Hold Expiry Worker ✅
- [x] Scan hold_expires_at (DB) and/or Redis TTL pop
- [x] Release to AVAILABLE, emit event, enqueue waitlist
- [ ] SLA: >99% cleared within 5s (needs load testing to validate)

## 5) Waitlist Join & Assignment ✅
- [x] POST join waitlist with preferences
- [x] Worker FIFO assignment with atomic claim and notification stub
- [x] Track waitlist entry status; idempotent processing
- [ ] P95 assignment latency <10s after seat becomes available (measured in tests/sim)

## 6) Baggage & Payment Pause ✅
- [x] POST baggage to WeightService mock; overweight -> WAITING_FOR_PAYMENT + payment_intent
- [x] POST payments/webhook idempotent resume to COMPLETED
- [x] Record events; payment intent state machine

## 7) Abuse Protection ✅
- [x] Rate limits per IP/API key (seat map, hold)
- [x] Burst/anomaly throttle (>30 seat maps/5s) with temp block
- [x] Audit incident logging
- [x] Auto-expire blocks after ~10–15m

## 8) Observability
- [ ] Metrics (latency, conflicts, expiry clears, waitlist latency, cache hit rate)
- [ ] Structured logs with actor/reason; tracing around DB/Redis
- [ ] Health/ready endpoints and basic dashboards (local)

## 9) UI (PNR/Dummy + Seat Map)
- [ ] PNR + last name login gate; dummy booking shortcut
- [ ] Seat map grid with states, hold countdowns, actions (hold/confirm/cancel), waitlist join
- [ ] Baggage/payment pause flow; status panel
- [ ] Error/success toasts; invalid PNR shows inline error

## 10) Testing & Coverage
- [ ] Unit tests for state transitions
- [ ] Integration: concurrent hold/confirm, expiry, waitlist
- [ ] E2E: hold→confirm; hold→expire→waitlist; overweight→payment resume
- [ ] Coverage ≥80%
- [ ] Report coverage artifact

## 11) Docs & Packaging
- [ ] README with setup/run; API-SPECIFICATION.yml linked
- [ ] ARCHITECTURE.md, WORKFLOW_DESIGN.md refs, PROJECT_STRUCTURE.md
- [ ] CHAT_HISTORY.md update; PRESENTATION.md outline
- [ ] Diagram placeholders (workflow, DB schema) for WORKFLOW_DESIGN.md/ARCHITECTURE.md
- [ ] Coverage/How-to-run tests documented
