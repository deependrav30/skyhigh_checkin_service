# Product Requirements Document — SkyHigh Check-In & Seat Service

## Problem
SkyHigh needs to prevent seat overlaps and slow, error-prone check-ins that erode revenue and customer trust. The system must keep an authoritative seat state, handle bursty concurrent access without double assignment, pause/resume check-in for baggage payments, and surface accurate seat maps quickly during peak traffic.

## Goal
Deliver a reliable, auditable check-in and seat management service that eliminates double-booking, keeps check-in fast, supports time-bound holds, fair waitlisting, baggage validation with payment pauses, and delivers fast seat map reads under peak load.

## Scope
- In-scope: seat availability/holds/confirmation/cancellation lifecycle, waitlist management, baggage overweight handling with payment pause/resume, API contracts, observability, and local deployment artifacts.
- Out-of-scope: airline pricing logic, loyalty program accrual, ticketing issuance, fraud payments stack, and upstream booking flows.

## Personas
- Passenger: books or checks in, selects/holds/confirms seats, manages baggage and payments.
- Agent: assists passengers, resolves conflicts, views audit trail.
- Ops/Reviewer: validates system behavior via API, needs metrics, logs, and reproducible local env.

## User Stories & Acceptance Criteria
1) Hold a seat
- As a passenger, I can place a seat on hold for 120s if it is AVAILABLE, and receive a hold id and expiry timestamp.
- Acceptance: conditional update enforces AVAILABLE→HELD; hold expires automatically after 120s; conflicting holds are rejected with a deterministic error code.

2) Confirm a held seat
- As a passenger, I can confirm my held seat before expiry, provided I own the hold.
- Acceptance: HELD→CONFIRMED only when held_by matches; duplicate confirmations are idempotent; audit event recorded.

3) Release / cancel
- As a passenger or agent, I can cancel a held/confirmed seat, making it AVAILABLE.
- Acceptance: CANCELLED state recorded; waitlist task enqueued; audit event created.

4) Waitlist
- As a passenger, I can join a flight waitlist with preferences and be auto-assigned when a seat frees up.
- Acceptance: waitlist entry stored with ordering; worker assigns next eligible seat atomically; user is notified of assignment or failure.

5) Seat map
- As a passenger or agent, I can view an accurate seat map quickly, even during peak traffic.
- Acceptance: P95 seat map read <1s from cache; cache stays consistent via events and periodic reconciliation.

6) Baggage & payment pause
- As a passenger, I can submit baggage weight; if overweight, I am prompted for payment and my check-in is paused until webhook success.
- Acceptance: overweight triggers WAITING_FOR_PAYMENT state and payment_intent creation; webhook resumes to COMPLETED; retries are idempotent.

7) Abuse protection
- As a platform, I can rate-limit and detect anomalous seat map or hold requests to protect capacity.
- Acceptance: per-IP/API key limits enforced; anomalies logged and throttled; blocks expire automatically.

## Functional Requirements
- Seat state machine: AVAILABLE, HELD, CONFIRMED, CANCELLED; transitions are atomic with optimistic concurrency (version or updated_at).
- Time-bound holds: default 120s TTL; background worker reverts expired holds to AVAILABLE; optional Redis TTL mirror for fast expiry signals.
- Conflict-free assignment: conditional DB updates for claims; HELD→CONFIRMED verifies held_by; duplicate submissions are safe.
- Waitlist workflow: table storing entries; worker dequeues in order, applies assignment; notifications emitted; failures retried with backoff.
- Cancellation flow: immediate state update, enqueue waitlist assignment; events recorded in seat_events.
- Baggage validation: integrate WeightService; overweight sets WAITING_FOR_PAYMENT and creates payment_intent; payment webhook resumes check-in.
- Seat map caching: cache per flight; event-driven updates on seat changes; periodic reconcile with DB; pagination/partitioning for large flights.
- Abuse controls: edge rate limiter and anomaly detection window; temp blocks; audit logs for incidents.
- APIs: REST (or gRPC) covering seat map, hold, confirm, cancel, waitlist, baggage, payment webhook; publish OpenAPI in API-SPECIFICATION.yml.

## Non-Functional Requirements
- Performance: P95 seat map read <1s; hold/confirm/cancel API P95 <500ms under expected peak (specify TPS in env config).
- Consistency: no double assignments; authoritative state in Postgres; cache eventual consistency with reconcile.
- Reliability: background workers idempotent; retries with backoff; dead-letter queues for poison messages.
- Observability: metrics (latency, error rate, expired holds, conflicts, waitlist assignments), structured logs, tracing for critical flows.
- Security: authn/authz on APIs; rate limits; input validation; no sensitive data in logs.
- Compliance/Audit: append-only seat_events history; payment intents logged with status transitions.

## Adopted Assumptions & Defaults
- Peak load: ~5–10 seat map reads per second per active flight; 1–2 hold/confirm ops per second per active flight. Size tiers can scale these budgets up or down.
- Consistency: seat map cache may be briefly eventual (sub-second to a few seconds); DB is source of truth; responses expose a last-updated watermark.
- Waitlist policy: FIFO per flight with seat preference filtering; priority tiers (fare/loyalty) can be added later via a priority column without breaking APIs.
- Notification: email as the default for waitlist assignment; retries with exponential backoff for up to 24h or 5 attempts; include a confirmation token/link.
- Agent overrides: allowed under RBAC and feature flag; requires actor role, reason code, and audit entry in seat_events.
- Payment retries: webhooks may retry up to 72h; intent_id (and provider idempotency key) ensures idempotent handling; late successes are authoritative.
- Abuse controls: starting limits of ~60 seat map reads/min and 20 holds/min per IP/API key; anomaly throttle if >30 seat maps in 5s; blocks auto-expire after ~10–15 minutes.
- Retention: seat_events kept at least 1 year; waitlist history kept 180 days for support/analytics, then archived to cheaper storage.

## Data Model (authoritative in Postgres)
- seats(seat_id, flight_id, state, held_by, hold_expires_at, version, updated_at)
- seat_events(event_id, seat_id, flight_id, event_type, actor, metadata, created_at)
- waitlist(waitlist_id, flight_id, user_id, seat_preferences, created_at, status)
- payment_intents(intent_id, checkin_id, status, amount, currency, created_at, updated_at)
- checkins(checkin_id, passenger_id, flight_id, state, baggage_weight, payment_intent_id)

## Flows (happy path)
1) Hold: client calls hold → conditional UPDATE AVAILABLE→HELD, returns hold id + expiry; cache update event emitted.
2) Confirm: client calls confirm → verify held_by + state HELD → set CONFIRMED; emit events and cache update.
3) Expire: worker scans expired holds → set AVAILABLE; emits events; triggers waitlist worker.
4) Waitlist assign: worker picks next entry → attempt atomic claim; on success, notify user and mark entry assigned.
5) Baggage overweight: check-in calls WeightService; if overweight, create payment_intent and set WAITING_FOR_PAYMENT; webhook success moves to COMPLETED.
6) Cancellation: API sets CANCELLED/AVAILABLE and enqueues waitlist assignment; emit events.

## Success Metrics
- Zero double-assignments in load tests; conflict retries succeed without data loss.
- P95 seat map read <1s at peak; hold/confirm P95 <500ms.
- >99% expired holds cleared within 5s of expiry.
- Waitlist assignment latency P95 <10s after seat becomes available.
- Payment pause flows resume successfully >99% within 5s of webhook receipt.

## Dependencies
- Postgres for authoritative storage and transactions.
- Redis for cache, TTL mirrors, and queue (or RabbitMQ alternative).
- WeightService mock; Payment webhook mock.
- Background worker runtime (e.g., sidecar service) with queueing.

## Risks & Mitigations
- Hot-spot rows on popular flights: use partitioned seat maps and cache; keep transactions narrow.
- Clock drift affecting expiry: prefer DB now() as source of truth; Redis TTL as guard only.
- Cache divergence: periodic reconcile + event-driven invalidation.
- Payment webhook retries: idempotent handlers keyed by intent_id and version.

## Milestones
- M1: API contracts & schema migrations committed; local docker-compose up.
- M2: Seat lifecycle (hold/confirm/cancel) with events and cache updates; basic metrics.
- M3: Waitlist worker end-to-end; expiry worker; observability dashboards.
- M4: Baggage overweight pause/resume with payment webhook; abuse controls.
- M5: Load/concurrency test suite green; documentation and handoff.
