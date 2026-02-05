# Feature Breakdown & Acceptance Criteria — SkyHigh Core

This document enumerates the features to be implemented per the initial requirements, with detailed acceptance criteria for each.

## 1) Seat Map Access
- Serve seat maps per flight with seat states (AVAILABLE/HELD/CONFIRMED/CANCELLED) and a last_updated watermark.
- Cache-backed reads via Redis; reconcile with Postgres to maintain accuracy.
- Acceptance:
  - P95 seat map response <1s under target load.
  - Seat states reflect DB truth within a brief reconciliation window.
  - Cache drift is detected and repaired automatically.

## 2) Seat Hold (AVAILABLE → HELD)
- API to place a 120s hold on an AVAILABLE seat with ownership (held_by) and expiry timestamp.
- Atomic conditional update to prevent double holds; hold_id returned to client.
- Acceptance:
  - Only AVAILABLE seats can be held; conflicts fail deterministically.
  - Hold has exact 120s TTL; expiry timestamp is returned.
  - Seat transitions to HELD with held_by set; audit event recorded.
  - Cache updated/invalidated after hold.

## 3) Seat Confirm (HELD → CONFIRMED)
- API to confirm a held seat before expiry, owned by the caller.
- Idempotent confirm using hold_id; rejects wrong owner or expired holds.
- Acceptance:
  - HELD→CONFIRMED only when held_by matches and not expired.
  - Duplicate confirms by same owner return success without duplicate effects.
  - Audit event recorded; cache updated/invalidated.

## 4) Seat Cancel/Release (HELD/CONFIRMED → CANCELLED/AVAILABLE)
- API for passenger/agent to cancel a hold or confirmed seat; agent requires RBAC + reason code.
- Option to release to AVAILABLE and trigger waitlist assignment.
- Acceptance:
  - State updated atomically; held_by/expiry cleared where applicable.
  - Audit event recorded with actor and reason code (for agents).
  - Waitlist assignment task enqueued; cache updated/invalidated.

## 5) Hold Expiry
- Worker scans hold_expires_at or consumes Redis TTL signals to release seats.
- Acceptance:
  - >99% expired holds reverted to AVAILABLE within 5s of expiry.
  - Audit event recorded for expiry; cache updated/invalidated.
  - Waitlist assignment task enqueued on expiry.

## 6) Waitlist Management & Assignment
- API to join waitlist with seat preferences; status query optional.
- Worker assigns next eligible entry FIFO per flight, with preference filtering.
- Acceptance:
  - Joining stores entry with created_at and preferences; returns entry id.
  - Assignment uses atomic claim; on success marks entry assigned and notifies user (email stub acceptable).
  - On conflict, worker retries next entry with backoff; idempotent per waitlist_id.
  - P95 waitlist assignment latency <10s after seat becomes available.

## 7) Baggage Validation & Payment Pause
- Check-in flow captures baggage weight via WeightService mock.
- Overweight (>25kg) creates payment_intent and sets state WAITING_FOR_PAYMENT; normal weight continues.
- Acceptance:
  - Overweight requests return payment intent info and paused state.
  - Non-overweight completes or progresses check-in without payment.
  - Audit/event recorded; state reflects IN_PROGRESS/WAITING_FOR_PAYMENT/COMPLETED appropriately.

## 8) Payment Webhook Resume
- Webhook to finalize payment and resume check-in from WAITING_FOR_PAYMENT to COMPLETED.
- Idempotent handling keyed by intent_id and provider idempotency key.
- Acceptance:
  - Valid webhook transitions check-in to COMPLETED and marks payment_intent succeeded.
  - Replayed webhooks return success without duplicate side effects.
  - Failed processing retried with backoff; DLQ after repeated failures.

## 9) Abuse & Bot Detection
- Rate limits per IP/API key for seat map and hold endpoints; anomaly detection for bursts.
- Temporary blocks and audit logging of incidents.
- Acceptance:
  - Requests beyond configured thresholds are throttled with clear error code.
  - Burst pattern (e.g., >30 seat maps in 5s) triggers temporary block (auto-expire in ~10–15m).
  - Incidents are logged with source and timeframe.

## 10) Observability
- Metrics, structured logs, and traces for critical paths (seat map, hold/confirm/cancel, waitlist assignment, baggage/payment).
- Acceptance:
  - Metrics emitted for latency, error rate, conflicts, expired holds cleared, waitlist latency, cache hit rate.
  - Logs include actor, seat_id/flight_id, event type, reason codes (where applicable).
  - Traces wrap API handlers and worker jobs around DB/Redis calls.

## 11) UI (Vite + React)
- Basic check-in UI with booking lookup, baggage entry, overweight indicator/payment pause state.
- Virtual seat map grid showing AVAILABLE/HELD/CONFIRMED, hold countdowns, and actions to hold/confirm/cancel; waitlist join when unavailable.
- Status panel with check-in state, payment status, waitlist position; toast feedback.
- Acceptance:
  - Seat map renders states consistent with API data; actions call corresponding APIs and reflect results.
  - Hold countdown visible and updates client-side; on expiry UI refreshes state.
  - Overweight flow surfaces payment pause and resumes on webhook-simulated success.

## 12) Login by PNR + Dummy Details (UI)
- UI provides a simple entry point to look up a booking by PNR and last name, then proceed to seat selection/check-in.
- For demo mode, expose a “Use dummy details” shortcut that pre-fills a sample PNR/passenger and loads a sample flight/seat map.
- Acceptance:
  - PNR + last name form must gate access to seat selection; invalid lookups show an error state.
  - Dummy details option immediately loads a sample booking and displays the seat map with selectable seats.
  - Subsequent actions (hold/confirm/cancel, waitlist, baggage flow) work from the loaded booking context.

## 13) Testing & Coverage
- Unit, integration (including concurrent hold/confirm), and end-to-end happy-path tests.
- Acceptance:
  - Coverage ≥80% reported.
  - Concurrency tests demonstrate no double assignments under parallel holds/confirms.
  - E2E covers hold→confirm, hold→expire→waitlist assign, overweight→payment resume.

## 14) Packaging & Tooling
- docker-compose to run API, worker, Postgres, Redis, Weight/Payment mocks.
- API-SPECIFICATION.yml generated/maintained; README with setup/run; PROJECT_STRUCTURE.md and ARCHITECTURE.md documented.
- Acceptance:
  - `docker-compose up` brings all services up and healthy.
  - API spec matches implemented endpoints and examples.
  - Docs present and consistent with implementation.
