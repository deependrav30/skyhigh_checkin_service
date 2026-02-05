# Design Discussion — SkyHigh Core

This document analyses the requirements and explains the proposed implementation for each feature, with rationale for design decisions.

1) Seat Lifecycle (AVAILABLE → HELD → CONFIRMED → CANCELLED)
- Implementation: store authoritative state in a `seats` table (seat_id, flight_id, state, held_by, hold_expires_at, version) and an append-only `seat_events` history table. Transitions occur in DB transactions; keep a `version` or `updated_at` for optimistic concurrency checks.
- Why: Relational DB provides ACID guarantees for authoritative state and single-row transactions; the events table supports auditing and replay.

2) Time-Bound Seat Hold (120 seconds)
- Implementation: on hold, set `state=HELD`, `held_by=passenger_id`, `hold_expires_at=now+120s` via a conditional UPDATE that requires `state='AVAILABLE'`. Use a background worker to scan for expired holds and release them. Optionally maintain a Redis key with TTL for faster expiration signalling and to reduce DB pressure.
- Why: DB conditional update guarantees atomic claim of AVAILABLE seats; background worker ensures eventual release; Redis TTL provides low-latency guard under peak load.

3) Conflict-Free Seat Assignment
- Implementation: use atomic conditional updates in Postgres (UPDATE ... WHERE seat_id=? AND state='AVAILABLE') or a Redis Lua script for a compare-and-set lock if using Redis as primary guard. For confirm, transition HELD→CONFIRMED in one transaction that verifies `held_by` matches.
- Why: Atomic, single-step state change prevents race conditions and duplicate assignments even under high concurrency.

4) Cancellation
- Implementation: allow API to set `state=CANCELLED` (or RELEASE) and immediately enqueue a waitlist assignment task. Persist the cancellation event in `seat_events`.
- Why: Immediate DB update frees the seat reliably; enqueued processing ensures non-blocking notification and fair waitlist handling.

5) Waitlist Assignment
- Implementation: store waitlist entries in a `waitlist` table (flight_id, seat_preferences, user_id, created_at). When a seat becomes AVAILABLE (cancel/expired hold), a worker dequeues the next eligible entry and attempts an atomic seat assignment; on success, notify the user and record the event.
- Why: Worker-driven assignment ensures ordering, fairness, and simplifies API responsiveness.

6) Baggage Validation & Payment Pause
- Implementation: during check-in, call a `WeightService` to validate weight. If overweight (>25kg), mark check-in state `WAITING_FOR_PAYMENT` and create a `payment_intent` record. Pause finalization until a payment webhook confirms success, then resume and mark `COMPLETED`.
- Why: Separating payment concerns keeps the main flow deterministic; storing explicit states lets the system be resumed or retried reliably.

7) High-Performance Seat Map Access
- Implementation: maintain a read-optimized seat-map cache (Redis or read-replica in-memory store) updated via events when seats change. Serve seat map reads from cache; reconcile periodically with authoritative DB. Consider partitioning seat maps by flight and paginating updates.
- Why: Cache reduces DB load and yields P95 <1s during peaks; event-driven updates keep data near real-time.

8) Abuse & Bot Detection
- Implementation: edge rate-limiter (per IP/API key) plus a short-window anomaly detector that flags abnormal patterns (e.g., 50 different seat map requests within 2s). On detection, apply temporary blocks or throttles, record the incident to audit logs, and optionally require verification (CAPTCHA) or escalate.
- Why: Protects backend resources and enforces fair usage; logging aids post-event analysis and tuning.

9) Background Workers & Reliability
- Implementation: use a queue (Redis/RabbitMQ) for tasks: hold expiry, waitlist assignment, notifications, payment handling. Design handlers to be idempotent with retry/backoff and dead-letter capture for failures.
- Why: Decouples heavy or retry-prone work from user-facing APIs and improves resilience.

10) Data Model & Persistence
- Implementation: Postgres as the authoritative store for seats, holds, waitlist, events, and payment intents. Redis as cache and optionally for fast ephemeral locks/TTL. Use migrations and schema versioning. Keep state transitions logged in `seat_events` for audit and debugging.
- Why: Postgres provides strong consistency features; Redis complements for low-latency needs.

11) APIs & Contracts
- Implementation: design clear REST APIs (or gRPC) for operations: `GET /flights/{id}/seatmap`, `POST /flights/{id}/seats/{seatId}/hold`, `POST /holds/{id}/confirm`, `POST /holds/{id}/cancel`, `POST /flights/{id}/waitlist`, `POST /checkin/{id}/baggage`, `POST /payments/webhook`. Provide an OpenAPI spec (`API-SPECIFICATION.yml`).
- Why: Explicit API contracts enable automated tests, client integration, and grading validation.

12) Testing & Observability
- Implementation: unit tests for state machines and transitions; concurrent integration tests that simulate parallel seat claims; end-to-end tests for full check-in flows, waitlist, cancellations, and payment pause/resume. Collect metrics (latency, hold rates, expired holds, conflict counts) and traces for critical flows.
- Why: Ensures correctness under concurrency and provides evidence of meeting NFRs.

13) Deployment & Local Validation
- Implementation: provide components in `docker-compose.yml`: API, worker, Postgres, Redis, and mocked Weight/Payment services. Use health checks and simple orchestration scripts for local validation.
- Why: Simplifies reviewer validation and provides an environment close to production for testing.

Next steps
- I can split this into `PRD.md`, `WORKFLOW_DESIGN.md`, and other required files, or scaffold the codebase and `docker-compose.yml`. Tell me which you'd prefer next.
