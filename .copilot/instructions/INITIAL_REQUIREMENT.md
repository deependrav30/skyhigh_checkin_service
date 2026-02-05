# Initial Requirement

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
3. README.md: A clear overview of the project and detailed instructions on how to set up the database and run the application and its background workers.
4. PROJECT_STRUCTURE.md: Explaining the structure of the project and the purpose for
each of the folder and key modules.
5. WORKFLOW_DESIGN.md: A document explaining your implementation
 Flow Diagrams: Include simple diagrams for the primary flows.
 Database Schema: A diagram or description of your database tables,
explaining the relationships and how you store the state history.
6. ARCHITECTURE.md: A document explaining your architecture with diagrams.
7. API-SPECIFICATION.yml: A simple document or Postman collection defining the API
endpoints you built.
 The file name should be POSTMAN_COLLECTION.json in case of a postman collection.
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

