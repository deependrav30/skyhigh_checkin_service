# Project Structure (planned)

- api/ : Fastify backend (routes, schemas, DB/cache integration)
- worker/ : Background workers (expiry, waitlist, notifications, payment resume) — planned
- web/ : Vite + React UI (PNR login/dummy, seat map, baggage/payment) — planned
- shared/ : Shared TypeScript types/utilities — planned
- mocks/ : Mock services (weight, payment)
- migrations/ : Database migrations — planned
- docker-compose.yml : Local stack (Postgres, Redis, API, worker, mocks)
- API-SPECIFICATION.yml : OpenAPI contract
- PRD.md, FEATURE_BREAKDOWN.md, WORKFLOW_DESIGN.md, ARCHITECTURE.md, DESIGN_DISCUSSION.md : docs
- TODO.md : Feature-wise task list
- CHAT_HISTORY.md : Interaction log
