# Workflow Design — SkyHigh Check-In & Seat Service

## Purpose
Define the end-to-end workflows, components, and data flows that realize the PRD: no seat overlaps, fast check-in, baggage validation with payment pause, fair waitlist, and quick seat maps.

## Components
- API Service: REST/gRPC handlers for seat map, hold, confirm, cancel, waitlist, baggage, payment webhook.
- Postgres (source of truth): seats, seat_events, waitlist, checkins, payment_intents.
- Redis: seat-map cache, TTL mirrors for holds, rate-limits, optional queue.
- Worker Service: expiry scanner, waitlist assigner, notification dispatcher, payment resume handler.
- External mocks: WeightService (baggage validation), Payment Provider (webhook callbacks).

## Tech Stack Choices
- Backend: Fastify (TypeScript) with JSON Schema validation and typed routes; pg client for Postgres; Redis client for cache/rate limits; background jobs via lightweight worker loop (or bullmq if needed).
- Database: Postgres as authoritative store for seats/checkins/events/waitlist/payment_intents.
- Cache/Queue/Rate limit: Redis for seat map cache, TTL mirrors, counters, and lightweight queues.
- UI: Vite + React (TypeScript) for the basic check-in/seat selection UI, sharing TypeScript models with the API.
- APIs: OpenAPI/Swagger generated from Fastify schemas; API-SPECIFICATION.yml kept in repo.
- Containers: docker-compose to run API, worker, Postgres, Redis, and mock Weight/Payment services.

## State Models
- Seat state machine: AVAILABLE → HELD → CONFIRMED → CANCELLED; HELD → AVAILABLE on expiry/cancel; CONFIRMED → CANCELLED on cancel.
- Check-in state: INITIATED → BAGGAGE_VALIDATED → WAITING_FOR_PAYMENT → COMPLETED; WAITING_FOR_PAYMENT → COMPLETED on successful webhook; retries are idempotent.

## Key Workflows
1) Seat Hold (AVAILABLE → HELD)
- API call validates auth and seat ownership rules.
- Conditional UPDATE seats WHERE seat_id & flight_id match and state=AVAILABLE; set HELD, held_by, hold_expires_at=now+120s, bump version.
- Emit seat_event; update/invalidate cache; set Redis TTL mirror (optional) for expiry hint.
- Return hold_id and expiry.

2) Seat Confirm (HELD → CONFIRMED)
- API verifies hold owner and non-expired hold.
- Transaction: conditional UPDATE seats WHERE state=HELD AND held_by=caller; set CONFIRMED; record seat_event.
- Update/invalidate cache; respond idempotently (re-issuing success if already CONFIRMED by same actor).

3) Seat Cancel/Release (HELD/CONFIRMED → CANCELLED/AVAILABLE)
- API allows passenger or agent (RBAC) with reason code.
- Transaction: set state=CANCELLED (or AVAILABLE if releasing a hold), clear held_by/expiry; record seat_event.
- Enqueue waitlist assignment task; update/invalidate cache.

4) Hold Expiry (HELD → AVAILABLE)
- Worker scans for hold_expires_at <= now OR consumes Redis TTL signals.
- Transaction: conditional UPDATE state back to AVAILABLE; record seat_event.
- Enqueue waitlist assignment task; update/invalidate cache.

5) Waitlist Assignment
- Triggered by cancellation/expiry event or periodic sweep.
- Worker dequeues next FIFO waitlist entry for the flight (filtering seat preferences).
- Attempts atomic claim via same conditional UPDATE to AVAILABLE → HELD/CONFIRMED (configurable: direct confirm or hold then notify).
- On success: record seat_event, notify user (email), mark waitlist entry assigned.
- On conflict: retry next entry with backoff; keep idempotent via waitlist_id processing keys.

6) Seat Map Read
- API serves from Redis cache keyed by flight_id; includes last_updated watermark.
- Cache updated/invalidated on seat state changes; periodic reconcile compares to Postgres for drift.

7) Baggage Validation and Payment Pause
- Check-in API sends baggage weight to WeightService.
- If <= threshold: set check-in state BAGGAGE_VALIDATED/COMPLETED (depending on flow) and proceed.
- If overweight: create payment_intent, set WAITING_FOR_PAYMENT, return payment action to client; record event.

8) Payment Webhook Resume
- Webhook handler validates signature/idempotency keys.
- Transaction: load intent/checkin, ensure current state; set COMPLETED on success; record event.
- Idempotent: repeated webhooks return success if already completed; failures retried with backoff.

9) Abuse Protection
- Edge rate-limit per IP/API key using Redis counters (e.g., 60 seat maps/min, 20 holds/min).
- Anomaly detector: throttle if burst > threshold (e.g., >30 seat maps in 5s); blocks auto-expire.

## Background Workers
- Hold Expiry Scanner: periodic or TTL-triggered; idempotent; small batch per run.
- Waitlist Assigner: consumes queue; retries with exponential backoff; DLQ on repeated failure.
- Cache Reconciler: periodic compare of cache vs DB for active flights; repairs drift.
- Notification Dispatcher: sends emails for waitlist assignment; retries with backoff.
- Payment Resume Handler: processes webhook tasks to ensure idempotent state transitions.

## Idempotency & Concurrency
- All state transitions use conditional UPDATE with version/updated_at checks.
- Idempotency keys: hold_id for confirm/cancel; waitlist_id for assignment; intent_id + provider key for payments.
- Workers store processed keys to avoid duplicate side effects; retries are safe.

## Failure Handling
- Retries with exponential backoff; DLQ for poison messages.
- Partial failure isolation: API returns success only after DB commit; cache updates are best-effort with reconcile safety net.
- Clock source: DB now() for expiry; Redis TTL is advisory only.

## Observability
- Metrics: latency, error rate, conflict rate, expired holds cleared, waitlist assignment latency, cache hit rate.
- Logs: structured events for state transitions with actor and reason codes.
- Traces: wrap API handlers and workers around DB/cache calls.

## Deployment Notes
- Provide docker-compose with API, worker, Postgres, Redis, WeightService mock, Payment mock.
- Feature flags: agent overrides, direct waitlist auto-confirm, Redis TTL mirror usage.
- Configuration: hold TTL, rate-limit thresholds, retry/backoff settings.
