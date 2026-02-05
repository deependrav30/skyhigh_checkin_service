User: Build a folder .copilot/instructions and add a file named as INITIAL.REQUIREMENT.md

GitHub Copilot: I'll add a todo and create the `.copilot/instructions` directory and file.

Created 2 todos

Created [](file:///Users/deependraverma/Documents/Projects/AI/skyhigh_checkin_service/.copilot/instructions)

Created [](file:///Users/deependraverma/Documents/Projects/AI/skyhigh_checkin_service/.copilot/instructions/INITIAL.REQUIREMENT.md)

Completed: *Create .copilot/instructions directory* (1/2)

Progress: created the folder and added the file.

- File: INITIAL.REQUIREMENT.md

Would you like me to populate `INITIAL.REQUIREMENT.md` with a template or specific contents?

Made changes.

User: INITIAL_REQUIREMENT.md rename to this

GitHub Copilot: I'll add a todo and rename the file to INITIAL_REQUIREMENT.md.

Added 1 todo

Using "Apply Patch"


```

```


Using "Apply Patch"

Completed: *Rename INITIAL.REQUIREMENT.md to INITIAL_REQUIREMENT.md* (3/3)

Progress: renamed the file and updated the todo.

- Removed: INITIAL.REQUIREMENT.md
- Added: INITIAL_REQUIREMENT.md

Do you want me to populate `INITIAL_REQUIREMENT.md` with a template or additional details?

Made changes.

User: add below data there

SkyHigh Core – Digital Check-In System
1. Business Scenario
SkyHigh Airlines is transforming its airport self-check-in experience to handle heavy peakhour traffic. During popular flight check-in windows, hundreds of passengers attempt to
select seats, add baggage, and complete check-in simultaneously.
The business requires a fast, safe, and automated digital check-in system that:
• Prevents seat conflicts
• Handles short-lived seat reservations
• Supports baggage fee handling
• Detects abusive access patterns
• Scales reliably during check-in rushes
You are tasked with building SkyHigh Core, the backend service responsible for managing
this experience.
2. Core Functional Requirements
2.1 Seat Availability & Lifecycle Management
Each seat on a flight follows a defined lifecycle.
Seat States
AVAILABLE → HELD → CONFIRMED-> CANCELLED
• AVAILABLE: Seat can be viewed and selected
• HELD: Seat is temporarily reserved for a passenger
• CONFIRMED: Seat is permanently assigned
• CANCELLED: Seat is released due to passenger cancellation
Business Rules
• A seat can only be held if it is currently AVAILABLE
• A seat in HELD state is exclusive to one passenger
• CONFIRMED seats can be CANCELLED by the passenger
2.2 Time-Bound Seat Hold (2 Minutes)
When a passenger selects a seat:
• The system must reserve the seat for exactly 120 seconds
• During this time:
o No other passenger can reserve or confirm the same seat
• If the passenger does not complete check-in within the time window:
o The seat must automatically become AVAILABLE again
• This behavior must work reliably even during high traffic
2.3 Conflict-Free Seat Assignment
The system must provide the following hard guarantee:
If multiple passengers attempt to reserve the same seat at the same time, only one
reservation can succeed.
• Seat assignment must remain correct regardless of request volume
• No race condition should result in duplicate seat assignments
• The system must remain consistent under concurrent usage
2.4 Cancellation:
• Passengers can cancel a confirmed check-in before departure
• Cancelled seats immediately become AVAILABLE or are offered to waitlisted users
2.5 Waitlist Assignment:
• If a seat is unavailable, passengers can join a waitlist
• When a seat becomes AVAILABLE (from cancellation or expired hold), the system
automatically assigns it to the next eligible waitlisted passenger
• Passengers are notified when their waitlisted seat is assigned
2.6 Baggage Validation & Payment Pause
During check-in, passengers may add baggage.
Business Rules
• Maximum allowed baggage weight: 25kg
• If baggage weight exceeds the limit:
o Check-in must be paused
o Passenger must pay an additional baggage fee
o Only after successful payment can check-in continue
• A separate Weight service can be used for this.
• Payment processing may be simulated as a separate service.
The system must clearly reflect whether a check-in is:
• In progress
• Waiting for payment
• Completed
2.7 High-Performance Seat Map Access
Seat map browsing is the most frequently used feature.
Expectations:
• Seat map data must be loaded quickly during peak usage. P95 should be less than 1
second.
• The system must support hundreds of concurrent users.
• Seat availability should be accurate and near real-time
2.8 Abuse & Bot Detection
To protect system integrity:
• Detect cases where a single source rapidly accesses multiple seat maps
• Example scenario:
o One source accessing 50 different seat maps within 2 seconds
• When detected:
o The system must restrict or block further access temporarily
o The event must be recorded for audit and review
The
automated evaluation mechanism expects that those file names are accurate; if not,
then it will impact the final score.
Your submission will be a single private GitHub repository containing the following:
1. PRD.md : PRD containing a clear description of the problem being solved, the goals
the system must achieve (e.g., no seat overlaps, fast check-in, baggage validation),
and the key users who will interact with it ,along with NFRs.
2. Source Code: The complete, running source code for the application.
3. README.md: A clear overview of the project and detailed instructions on how to set
up the database and run the application and its background workers.
4. PROJECT_STRUCTURE.md: Explaining the structure of the project and the purpose for
each of the folder and key modules.
5. WORKFLOW_DESIGN.md: A document explaining your implementation
 Flow Diagrams: Include simple diagrams for the primary flows.
 Database Schema: A diagram or description of your database tables,
explaining the relationships and how you store the state history.
6. ARCHITECTURE.md: A document explaining your architecture with diagrams.
7. API-SPECIFICATION.yml: A simple document or Postman collection defining the API
endpoints you built.
 The file name should be POSTMAN_COLLECTION.json in case of a postman
collection.
 The file name should be API-SPECIFICATION.md if it is a markdown file.
 The file name should be API-SPECIFICATION.yml if it is an API sepecification
file.
8. docker-compose.yml: A single, working Docker Compose file that starts all required
components of your system for easy validation.
9. CHAT_HISTORY.md: A summary document that chronicles your design journey with
your AI assistant, highlighting key decision points and how you used AI to evaluate
alternatives.
10.Unit Tests & Coverage Report.
11.Video [PRESENTATION.md to contains its content]: An 8-10 min video explaining:
 Design, architecture and the different components and how they
communicate with each other.
 Explain the journey from initial brainstorming till the final implementation
and the conversation with the coding assistant.
 Key decisions and trade-offs.
 Demo of the entire working of the application.
 Test case coverage % (more than 80%)

GitHub Copilot: I'll add a todo, read the current file to avoid conflicts, then append your provided specification to the file.

Created 4 todos

Read [](file:///Users/deependraverma/Documents/Projects/AI/skyhigh_checkin_service/.copilot/instructions/INITIAL_REQUIREMENT.md)

Now appending the full specification into INITIAL_REQUIREMENT.md.Now applying the patch to update the file with the provided specification.

Using "Apply Patch"


```

```


Completed: *Append provided specification to INITIAL_REQUIREMENT.md* (4/4)

Done — I appended the full specification to INITIAL_REQUIREMENT.md.

Next step: would you like me to convert this into separate docs (PRD.md, WORKFLOW_DESIGN.md, etc.) now?

Made changes.

User: Before PRD just analyse requirement and let me know about the feature and how you going to implement that feature and why as well for each decision

GitHub Copilot: I'll add a short TODO to track this analysis step.

Created 2 todos

Progress: TODO created; next I'll analyze each feature and provide implementation approach plus rationale.

**Seat Lifecycle (AVAILABLE→HELD→CONFIRMED→CANCELLED)**
- Implementation: model a `seats` table (seat_id, flight_id, state, held_by, hold_expires_at, version) and an immutable `seat_events` history table. Use optimistic concurrency (row version) for updates and DB transactions for single-row state transitions.
- Why: relational DB gives strong persistence and ACID for single-row updates; event/history table provides audit and replay; optimistic concurrency prevents lost updates with minimal locking.

**Time-Bound Seat Hold (120s)**
- Implementation: on hold request set `state=HELD`, `held_by=passenger_id`, `hold_expires_at=now+120s`. Enforce via:
  - API-level check + DB conditional update: UPDATE ... WHERE seat_id=? AND state='AVAILABLE'
  - Background worker (cron/queue) to scan expired holds and release them.
  - Optional Redis TTL as a fast secondary guard for high throughput.
- Why: DB conditional UPDATE guarantees single successful holder; background worker ensures eventual release even if process dies; Redis TTL provides low-latency expiration and reduces DB pressure under peak.

**Conflict-Free Seat Assignment (hard guarantee)**
- Implementation: perform conditional atomic DB update or use a single Redis Lua script (compare-and-set) when using Redis for locks. For confirm step, promote HELD→CONFIRMED in a single transaction verifying held_by matches.
- Why: atomic DB update (WHERE state='AVAILABLE') or atomic Redis script prevents race conditions; single-transaction confirm avoids double-assign.

**Cancellation**
- Implementation: API to set `state=CANCELLED` (or RELEASE) in DB; immediately notify waitlist worker to assign next person.
- Why: immediate DB update ensures availability; hooking into waitlist worker keeps flow automated.

**Waitlist Assignment**
- Implementation: `waitlist` table (flight_id, seat_pref, user_id, created_at). When seat becomes available, a background worker dequeues next eligible waitlisted user and atomically assigns seat (same conditional update path) and notifies user (email/push).
- Why: decoupling via worker avoids blocking user-facing APIs and handles ordering/fairness consistently.

**Baggage Validation & Payment Pause**
- Implementation: during check-in, call a `WeightService` (internal API) to validate. If overweight, set check-in state to `WAITING_FOR_PAYMENT` and create a `payment_intent` record; after payment success webhook, resume and complete check-in.
- Why: separating payment and weight concerns keeps services bounded; state machine ensures deterministic behavior and replayability.

**High-Performance Seat Map Access**
- Implementation: maintain a read-optimized seat-map cache (Redis or in-memory read replicas) updated via events (on hold/confirm/cancel). Serve seat map API from cache; occasionally reconcile with authoritative DB (eventual consistency window <1s).
- Why: caches provide P95 <1s under load; event-driven updates keep near real-time accuracy with low DB load.

**Abuse & Bot Detection**
- Implementation: rate-limiter (per IP/API key) in edge layer + anomaly detector that flags excessive seat-map fetches (e.g., 50 maps/2s). On detection, temporarily block and record event to audit log; optionally apply progressive penalties (CAPTCHA, throttling).
- Why: edge throttling protects backend under attack; logging supports audits and tuning.

**Background Workers & Reliability**
- Implementation: queue system (Redis/RabbitMQ) for background tasks: hold expiry, waitlist assignment, notification, payment processing. Use idempotent handlers and retries with backoff.
- Why: queues decouple heavy tasks, improve resiliency and scaling.

**Data Model & Persistence**
- Implementation: primary relational DB (Postgres) for authoritative state and transactions. Redis as cache/fast locks. Use migrations and schema to store versions and events.
- Why: Postgres offers strong consistency and rich features; Redis complements for low-latency operations.

**APIs & Contracts**
- Implementation: clear REST/HTTP JSON APIs (or gRPC) for: fetch seat map, hold seat, confirm seat, cancel, join waitlist, add baggage/start payment, payment webhook. Provide OpenAPI / `API-SPECIFICATION.yml`.
- Why: well-defined contracts enable testing, clients, and automated checking.

**Testing & Observability**
- Implementation: unit tests for state transitions, integration tests for concurrency (simulated parallel requests), end-to-end tests for hold/confirm/cancel and waitlist. Collect metrics (request latencies, holds/sec, conflicts, expired holds) and tracing.
- Why: tests verify correctness under concurrency; metrics aid tuning and proofs of NFRs.

**Deployment & Compose**
- Implementation: components: API service, worker service, Postgres, Redis, optional weight/payment mocks. Provide `docker-compose.yml` to run locally.
- Why: compose simplifies validation and grading.

If you want, I can now:
- expand any feature into a short design doc, or
- start scaffolding `PRD.md` and the repo structure (I can create `PRD.md`, `WORKFLOW_DESIGN.md`, etc.).

Which would you like next?

User: Add the above in a file called DESIGN_DISCUSSION.md under main folder

GitHub Copilot: I'll create `DESIGN_DISCUSSION.md` at the repo root containing the analysis and implementation rationale.

Completed: *Analyze requirements and list features* (1/5)

Using "Apply Patch"


```

```


Completed: *Add DESIGN_DISCUSSION.md* (5/5)

Done — added DESIGN_DISCUSSION.md at the repository root with the analysis and rationale.

- File: DESIGN_DISCUSSION.md

Next: scaffold `PRD.md`, or start implementing the service skeleton and `docker-compose.yml` — which would you like?

Made changes.

User: scaffold PRD.md

GitHub Copilot: Chat took too long to get ready. Please ensure you are signed in to GitHub and that the extension `GitHub.copilot-chat` is installed and enabled.


User: Design PRD.md

GitHub Copilot: Enable GPT-5.1-Codex-Max for all clients
[object Object]

User: @agent Enable: "Enable GPT-5.1-Codex-Max for all clients"

GitHub Copilot: Read [](file:///Users/deependraverma/Documents/Projects/AI/skyhigh_checkin_service/DESIGN_DISCUSSION.md)

Created [](file:///Users/deependraverma/Documents/Projects/AI/skyhigh_checkin_service/PRD.md)

Added the PRD at PRD.md capturing goals, scope, personas, user stories, functional/non-functional requirements, data model, key flows, success metrics, risks, milestones, and open questions tailored to the existing design. Want me to also split out workflow design or API spec next?

Made changes.