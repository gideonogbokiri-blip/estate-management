# Estate Management - Backend-First Implementation Plan

**Status:** Standalone implementation in progress; local API and Flutter previews are running.

**Product direction:** This is an independent estate-management product. Its API, identity, database, permissions, document storage, audit and notifications belong to this project. Do not depend on or brand the product as Zvend. Older, dated integration notes below are historical and are superseded where they conflict with this direction.

**Current evidence:** `backend/` is a runnable NestJS API backed by PostgreSQL and Prisma; `client/` is the Flutter application with separate onboarding, platform review, estate manager, resident, landlord, security and property/map entry points. The local browser preview starts at `http://localhost:8765/onboarding/`, the manager route is `http://localhost:8765/admin/`, and the resident route is `http://localhost:8765/web/`. Manager login and the notifications API have been authenticated against the local demo database. See `FLUTTER_PREVIEW_RECOVERY.md` for the demo walkthrough and build commands.

### Presentation demo repair flow (13 November 2026)

The Flutter resident maintenance screen now selects from the server-authorized active property list, so approved resident occupancy and verified ownership can submit a request even when no tenancy row exists. Requests still carry an estate/property ID and the API rechecks the actor's current property relationship. When the account has tenancies in multiple estates, the resident chooses a unique estate first, then an authorized property. The current local resident demo has an approved occupancy and can use this flow. `flutter analyze` reports no errors (existing style infos remain), the resident release build completed, and `/web/`, `/admin/`, `/onboarding/`, `/landlord-live/` plus API readiness return HTTP 200. Manual browser interaction is still needed before a live presentation.

### Resident outstanding charge read (13 November 2026)

Added authenticated `GET /api/v1/estate/invoices/mine` to project only unpaid invoice-draft records whose payer or current property occupancy, verified ownership, or active tenancy matches the actor, within an active estate and active resident/landlord membership. Estate charge setup continues to create drafts; the resident view calls them outstanding charges and shows no payment success. Flutter `/web/` loads this endpoint on workspace refresh and displays charge description, property, due date and exact amount. Verified receipts, payment initiation and issuing enforceable invoices remain unimplemented until payment/settlement and invoice lifecycle services are built. Nest build, targeted Dart analysis and resident web release build completed.

### Private estate application documents (13 November 2026)

Added standalone private document storage for estate onboarding. Authenticated applicants can upload PDF, JPEG and PNG files (10 MB cap) under controlled categories while an application is draft or returned for more information, list safe metadata, and download their own documents. Platform reviewers can download content only after the existing application assignment check. Uploads use generated private object references, actual file-signature checks, SHA-256 checksums, idempotency, scoped access and audit events. The Flutter onboarding and platform review screens expose upload/download controls. The policy does not invent mandatory document categories. The additive migration is deployed; backend compilation and targeted Dart analysis pass. Browser release bundles are being refreshed.

### Persisted estate invoice drafts (13 November 2026)

Added estate invoice draft persistence and manager endpoints for listing and creating drafts from active charge versions. Creation requires an idempotency key, validates the recurring billing window, property charge scope and an active payer account with an approved occupancy, tenancy or verified ownership relationship covering the period. The server snapshots the charge description and exact amount, computes the due date, blocks duplicate payer/property/charge-period drafts and records an audit event in the same serializable transaction. The Flutter charge register now offers a Draft invoice action and displays the resulting invoice draft list. These records remain DRAFT: no invoice is issued and no payment or balance is asserted. Schema validation/client generation, migration deployment, Nest build, targeted Dart analysis and Flutter admin web build completed.

### Facility catalogue and booking review (13 November 2026)

Added persisted estate facilities, resident booking requests, append-only status history and an additive migration. Active estate membership and property relationships are checked when residents request a slot; the API calculates Africa/Lagos availability from facility hours and confirmed bookings, enforces duration/capacity/lead-time/current-policy constraints, and requires an idempotency key. Requests remain pending and do not hold a slot indefinitely. Staff confirmation locks and rechecks the facility, resident relationship, booking window and overlap. Residents may cancel pending or future confirmed bookings; cancellation is an idempotent audited transition that releases the slot and never asserts a refund. The Flutter manager dashboard configures facilities and reviews requests; the resident API app checks live slots, submits requests, shows status and cancels eligible bookings. No facility fee, invoice or payment is implied. Prisma validation/client generation, migration deployment, Nest build and targeted Dart analysis completed. The resident app is served at `/web/` and manager app at `/admin/`; both pages return HTTP 200 and the resident release bundle includes cancellation.

### Versioned estate charge configuration (13 November 2026)

Added persisted estate charge definitions and effective-dated versions with exact decimal amounts, recurrence, applicability, due/grace rules, draft creation, explicit activation and transactional audit events. Estate administrators, managers and finance managers can manage only their active estate. The Flutter manager dashboard now opens a live charge register where staff can create drafts, revise charges and activate versions; activating a future version closes the prior overlapping version the day before its effective date. Drafts do not issue invoices or claim payment. Invoice generation, balances, settlement destinations and verified payments remain later billing work. Prisma schema validation/client generation, the additive migration deployment, Nest build and Flutter admin web build completed.

### Connected property archive lifecycle (13 November 2026)

The estate-scoped `POST /api/v1/estate/estates/:estateId/properties/:propertyId/archive` route now runs the archive domain use case in a serializable transaction, locks the property row, and checks active ownership/occupancy, pending or active tenancy, pending resident requests, open maintenance, unexpired visitor passes, currently checked-in visitors, and active single-property charge versions. Eligible records are archived without deletion and an audit event is committed atomically. The API-backed Flutter property register now exposes a confirmation action that calls this route and refreshes its list; rejected archives surface the backend's relationship conflict. Property invoice/payment, property-document and facility-booking persistence are not implemented yet, so their relationship guards must be added alongside those services.

### Connected estate structure and gate administration (13 November 2026)

The authenticated estate-manager dashboard now loads persisted structure nodes and supports creating zones, streets, buildings and floors with same-estate parent selections, plus non-destructive archive requests. The backend enforces hierarchy and linked-property/child constraints and audits the changes. Gate administration now loads active estate security memberships, creates estate gates and assigns officers through estate-scoped manager routes; the security staff Flutter page continues to handle check-in, current visits and check-out. Flutter admin and Nest builds complete, and the refreshed admin target is served at `/admin/`. Property register creation and structure edit controls are separate follow-up work; local access to non-demo data still requires an authorized manager account and configured database.

### Maintenance request API and resident submission (12 November 2026)

Added Prisma persistence and migration for estate maintenance requests, status history, resident-visible/internal updates, idempotency claims and a notice outbox. The authenticated API supports resident submission/history and an estate-manager queue/review flow. Submissions require an active property occupancy, tenancy or verified ownership relationship; request, audit, history and outbox writes commit together. The Flutter resident entry submits and lists requests for the user's active tenancy property; the manager dashboard now loads the queue and supports authorized status review, assignment and separated resident/internal notes. Attachments/private file access and outbox delivery remain unconnected.

### Connected landlord maintenance read (13 November 2026)

Added `GET /api/v1/landlord/properties/maintenance` with bounded pagination. It requires an active landlord membership and intersects that estate scope with the actor's current verified ownership links before listing requests; rows are rechecked against the same ownership set, and only resident-visible updates are projected. Ownership verification now grants the landlord membership in the same transaction when no landlord membership exists and appends a separate audit event; suspended or revoked memberships are not reactivated. The authenticated landlord portfolio now displays these live requests. Payment, private documents and request-changing landlord actions remain separate work.

### Estate expense decisions preview and use-case seam (7 November 2026)

The admin expense detail now enables Approve/Reject only for records whose authorized projection supplies those commands. Rejection requires a reason; preview decisions update only the in-session request state and decision note. Approval never changes verified payment totals. `backend/modules/finance/decide-expense-request.js` wraps the policy planner in an atomic host transaction, reloads the current approval policy, checks the configured stage permission, enforces self-approval/threshold rules through the domain planner, locks and recalculates the budget on final approval, verifies the payment destination, and commits the decision effects, audit event and requester notice together. Production routes/adapters remain pending.

### Announcement draft creation seam (6 November 2026)

Added `create-announcement-draft.js` as a transaction-backed use-case boundary over the announcement domain rules. It resolves the actor's estate announcement policy, validates audience targets, channels, emergency permission and private attachment references, then persists a draft and audit event atomically. Host authorization, persistence, audit, file and route adapters remain to be supplied from the Zvend repository.

The admin communications composer now saves through `EstateAdminRepository` and reloads the announcement list after creation. The current repository implementation keeps drafts in preview memory and labels that behavior; the screen no longer owns a separate draft list or implies a delivery occurred.

The same timeline can schedule a normal draft for a future Africa/Lagos time in the preview, with a clear notice that no delivery occurs. `schedule-announcement.js` adds the host use-case seam: it checks estate permission and timezone, locks and compare-updates the draft, writes an idempotent notification job and audit event in the same transaction, and recognizes retries of the same scheduled instant. Production scheduler, repository, outbox, route and notification adapters remain pending.

Drafts now also expose a confirmed **Send now** action; emergency drafts require a separate confirmation and cannot be scheduled. The preview moves an item only to `sending` and explicitly states no notification was delivered. `dispatch-announcement.js` adds the backend seam to recheck estate and emergency permissions, resolve eligible recipients server-side into a restricted snapshot, then atomically begin dispatch, enqueue an idempotent notification request and write the audit event. The later notification-service acceptance transition is still required before status may become `published`.

`accept-announcement-dispatch.js` now defines that acceptance boundary. It accepts only a receipt returned by a trusted notification adapter, locks the matching announcement, checks the original dispatch key and queued recipient count, then commits the receipt, Published transition and audit event together. Duplicate callbacks replay the recorded result; mismatched receipts cannot publish an announcement. A real signed callback/notification adapter and persisted receipt store remain host integration work.

`fail-announcement-dispatch.js` handles trusted notification failure receipts, storing a bounded failure code and audit event while retaining the original dispatch key and audience snapshot. `retry-announcement-dispatch.js` requires estate permission, verifies those original dispatch details, and re-enqueues with the same idempotency key. The communications view now includes failed-delivery counts/filtering and a preview retry action; retries only return to “Awaiting delivery” and do not imply success.

Failure callback idempotency uses a distinct trusted notification receipt ID in addition to the stable dispatch idempotency key. This allows separate failure events across retries, makes duplicate callbacks replay the same result, and prevents an old callback from rolling a newer announcement state backward. The persistence adapter must store receipts under a unique `(estate, announcement, receipt ID)` constraint and serialize changes on the announcement record.

The resident Community notices feed now updates its unread marker when a notice is opened and the repository confirms the read operation. `list-my-announcements.js` defines a paginated actor-scoped read over published announcements already delivered to the user's active estate memberships, returning only safe message fields and per-recipient read state. `mark-my-announcement-read.js` resolves the actor's exact delivered notification and delegates read receipt storage to Zvend's existing notification service. Neither seam accepts a client-supplied estate or recipient identity as authorization; host identity, notification query, read receipt and route adapters remain pending.

### Landlord maintenance & repairs preview (6 November 2026)

The landlord Properties section links to a maintenance and repairs subview showing request status, property, description and resident-visible progress. No requester contact, staff notes or private attachment references are projected, and no create/update commands are enabled. The preview repository provides illustrative rows pending host connection. `backend/modules/operations/list-my-landlord-property-maintenance.js` defines the separate ownership-scoped read seam; see `Zvend_Estate_Landlord_Maintenance_Contract.md`. The existing requester-only resident query is not reused.

### Resident receipts preview (6 November 2026)

The resident Billing screen now separates invoices and verified receipts. Receipt rows are derived only from payments explicitly marked verified, with a receipt number when present; private receipt access stays disabled in preview. `backend/modules/billing/list-my-estate-receipts.js` provides the matching payer-scoped list seam and rechecks each issued receipt against a succeeded trusted payment, applied invoice allocation and payer relationship before returning display metadata. See the Billing & Payments contract; route and host adapters remain pending.

### Platform application document review preview (6 November 2026)

The application detail now lists available document metadata with category, uploaded time and review status, alongside the existing application and administrator-assignment summary. Preview records are illustrative; document content remains inaccessible until the platform reviewer session and per-open private-file authorization are connected. The projection matches `read-estate-application.js`; no review decisions are represented as persisted.

### Tenancy expiry attention filter (6 November 2026)

The admin tenancy register's Ending soon count now uses a date-only window from today through the next 60 days and excludes past end dates. The status filter now includes Ending within 60 days, so the dashboard metric can be inspected as a focused list. The sample data includes one active tenancy in that window. Renewal or termination actions remain unavailable without the authenticated tenancy command and approval policy.

The property register's desktop table rows now open the same ownership/occupancy/property detail dialog already available from mobile cards, restoring detail-view parity across breakpoints.
**Source of product requirements:** `Zvend_Estate_Management_Build_Documentation.md`  
**Prepared:** 4 November 2026

### Product direction clarification

The product owner confirmed this is a standalone greenfield estate-management application, not an add-on to an existing Zvend platform. Implement the services this product needs inside this repository. Earlier statements that authentication, database, API, private-file storage, payments, notifications, or audit must be supplied by an external Zvend host are superseded. Keep the backend-first order and written product requirements; use the supplied NestJS/PostgreSQL/Prisma references as the greenfield baseline, reconciling them with the existing JavaScript domain core as implementation begins.

The detailed Phase 0 workspace findings and required source-repository inputs are recorded in `Zvend_Estate_Phase0_Repository_Audit.md`.

### Repository static-analysis checkpoint (6 November 2026)

`dart analyze` reports no issues across the complete Flutter client. `node --check` reports no syntax errors across all 106 backend JavaScript files. These checks confirm source syntax and analyzer health only; backend use-case adapters, routes, persistence and authenticated Zvend host integration are still pending.

### Platform plan catalog preview (6 November 2026)

The platform Plans navigation now opens a catalog screen describing Draft → Published → Retired version history and required commercial/entitlement fields. It deliberately renders no fabricated plan prices or limits while the catalog adapter is disconnected. `backend/modules/subscriptions/list-estate-plan-versions.js` defines the permission-scoped catalog read seam with validation of exact configured currency precision, entitlement limits and plan versions. Creating/publishing plan mutations remain unavailable until platform policy, approval, persistence and audit adapters are connected.

### Resident multiple-property relationships (6 November 2026)

The resident My property view now includes an estate/property selector for accounts with multiple authorized relationships. The preview demonstrates a tenant relationship in one estate and verified ownership in another, under one user account. `backend/modules/properties/list-my-property-details.js` adds a bounded actor-scoped list seam across estates and reuses the property detail relationship-safe projection for every row. The adapter must scope current ownership/occupancy links before pagination; host route integration remains pending.

### Estate dashboard source coverage (6 November 2026)

The admin overview now exposes an expandable source-coverage panel for each available dashboard section. It shows complete, partial, reconciliation-pending or unavailable status, plus current/stale/delayed/unavailable freshness and each source's `asOf` timestamp. Sample timestamps are explicitly labelled illustrative, extending the existing finance freshness cue across the overview.

### Resident visitor pass lifecycle clarity (6 November 2026)

The visitor pass list now filters active, exhausted and ended passes by status and visitor/reference search. The sample one-use pass is marked exhausted after its sole entry is used; gate check-in is a visit state, not a pass state. This aligns the resident preview with `list-my-visitor-passes.js` and keeps visitor credentials out of the list. Creation and revocation still require the connected authorized commands.

### Resident map confidence clarity (6 November 2026)

The resident map uses the selected estate name rather than a fixed label, clears selected details when a layer filter changes, and labels the schematic as illustrative and not to scale. Selected asset details emphasize its individual verified/approximate/unverified/unmapped confidence, with a matching status color. No resident or device location is collected.

### Resident facility booking lifecycle preview (6 November 2026)

My bookings now filters upcoming, needs-action, confirmed, past or all records. Status labels and colors reflect the operations lifecycle, including requested, pending review/payment, confirmed, declined, expired, cancelled and completed. Time-past records are kept out of upcoming filters, while payment-required remains distinct from confirmed; no booking or payment command is enabled in preview.

## 1. Current repository evidence

This workspace is the product repository. It contains the written estate-operations requirements, two Homely property-discovery reference images, an older static HTML preview, the Flutter application in `client/`, and a standalone NestJS API in `backend/`. The API owns authentication and sessions, platform and estate access, PostgreSQL persistence, migrations, application review, property and people workflows, finance, operations and audit. Prisma schema and deployable migrations live in `backend/prisma/`; local setup and route coverage are documented in `backend/README.md`.

The earlier Phase 0 audit correctly recorded that no host application was available. That finding does not block this product: the user confirmed it is being built independently. `backend/ARCHITECTURE.md` is the current stack and boundary decision. The older framework-independent domain helpers remain business-rule references; the NestJS modules and Flutter API repositories are the connected implementation.

The original JavaScript domain planners retain the validation and state-transition rules. The connected runtime now consists of NestJS services/controllers, PostgreSQL persistence and migrations, authenticated Flutter API clients, and estate-scoped write workflows. Current feature groups include onboarding and platform review, estate/property structure, membership and tenancy, visitor/gate security, billing and manual settlement, budgets and expenses, maintenance, incidents, facilities, announcements and in-app notifications. Treat the dated entries below as change history, not as a claim that these areas remain sample-only.

## 2. Product interpretation

The product is a standalone multi-estate management platform. Its primary web experience is the estate administration dashboard; resident, landlord and security tasks use responsive Flutter experiences. The supplied Homely screenshots depict property discovery and are not the product brief. Use their restrained green palette, property photography and clear card layouts as visual references. Venco is a public community-management reference; implement the written requirements and do not claim to reproduce its private design or workflows.

The two supplied screenshots depict the Homely property marketplace: buy/rent discovery, saved properties, agent contact and map search. The written estate-management requirements define a different product. Reuse only general visual cues such as a green palette, property photography, clear cards and mobile layouts. Venco is a public functional reference; its private workflows and brand are not copied.

## 3. Backend module boundaries

Implement as a modular feature inside the current backend (modular monolith unless repository evidence supports another pattern). Keep domain rules in services/use cases, with HTTP controllers limited to request parsing, validation and response mapping.

| Module | Owns | Initial dependencies |
|---|---|---|
| Estate onboarding | Applications, review decisions, estate status and joining code | Existing user identity, private file storage, audit log |
| Estate access | Estate membership, role assignment, permission evaluation and active estate context | Existing authentication and user model |
| Estate structure | Zones, streets/buildings and properties/units | Estate access |
| People and occupancy | Ownership interests, resident memberships, household links, tenancies and their history | Existing users, estate structure, private files |
| Visitor access | Invitations, verification, check-in/out and immutable access events | Estate access, property/resident links, notifications |
| Billing and rent | Configured charges, invoices, invoice adjustments and rent schedules | Estate structure, people/tenancies, existing payment service |
| Payment integration | Payment initiation references, verified provider events, allocations and receipts | Existing Zvend payment/wallet infrastructure |
| Estate operations | Maintenance, incidents, facilities, announcements and expenses | Estate access, property, notifications, files |
| Reporting | Estate-scoped operational and financial read models | Domain modules; must reconcile to source records |
| Audit | Actor, scope, action, target, outcome and timestamp for privileged changes | Existing logging conventions, all write modules |

Do not create duplicate users, authentication, wallet balances, payment rails, notification delivery or file storage if Zvend already supplies them.

## 4. Core relationship model

```text
Existing Zvend User
  â”œâ”€â”€ Estate Membership â”€â”€ Estate (platform tenant)
  â”œâ”€â”€ Ownership Interest â”€â”€ Property â”€â”€ Estate
  â”œâ”€â”€ Resident Membership â”€â”€ Estate / optional Property
  â””â”€â”€ Tenancy â”€â”€ Property â”€â”€ Estate
                   â”œâ”€â”€ Tenant (existing user)
                   â””â”€â”€ one or more owners / authorized payees

Estate + Property/Party â†’ Charges or Rent Schedule â†’ Invoice â†’
Verified Zvend Payment Reference â†’ Payment Allocation â†’ Receipt

Resident/Authorized User â†’ Visitor Invitation â†’ Access Events
Resident/Authorized User â†’ Maintenance Request â†’ Assignment/Updates
```

Ownership and occupancy are separate, time-bounded relationships. Preserve history rather than overwriting prior owners, tenants or residents. A person can hold multiple roles and belong to multiple estates through the existing identity.

## 5. Data and isolation rules

Apply these rules to every estate-owned record and query:

1. Resolve the authenticated actor from the existing auth/session mechanism.
2. Resolve an active estate context from memberships the actor is allowed to use. Never trust a client-supplied estate ID by itself.
3. Enforce role/permission and record-level relationships on the server for every read and write.
4. Scope database queries by the authorized estate and, where relevant, owned property, active tenancy, assigned gate or assigned work item.
5. Use estate-scoped unique keys where business rules require uniqueness (for example property code and invoice number).
6. Use fixed-precision monetary values, explicit currency, UTC timestamps and the estate/user timezone only for presentation.
7. Preserve posted invoices, payments, receipts and access events. Correct financial history through audited adjustment, credit, refund or reversal records.
8. Store sensitive documents privately with an authorization check and short-lived access URLs; do not expose permanent public links.
9. Record actor, estate scope, target, action, outcome and timestamp for status transitions and financially/security-sensitive changes.
10. Make payment webhook processing idempotent using the provider event/transaction reference and the existing Zvend verification contract.

An estate status guard should prevent normal operations when the estate is not active, while still allowing the explicitly authorized onboarding/review and support actions.

## 6. Proposed API groups

Use the existing API prefix, versioning, pagination, validation and error conventions once discovered. The paths below follow the supplied specification and are provisional.

| Group | Initial operations |
|---|---|
| Estate applications | Create/update draft, submit, list/review, approve/reject/request changes, suspend/deactivate |
| Estate context and memberships | List accessible estates, select context, list/invite staff, assign/revoke permissions |
| Estate structure | Manage zones/buildings/units and property register; archive rather than destructive delete |
| People and tenancies | Resident join requests/review, ownership, tenants, tenancy create/renew/terminate |
| Visitor access | Create/revoke invitation, verify pass, check in/out, expected/current visitor list |
| Billing and rent | Configure charges/schedules, generate/issue invoice, list/detail, dispute/cancel via audited workflow |
| Payments | Initiate using existing provider service, read payment state, verified webhook, receipt retrieval |
| Operations | Maintenance request/update/assignment/resolve, incidents, facility booking, announcement |
| Reports | Dashboard summary, rent/collections/outstanding/expenses with estate scope and date filters |
| Platform subscriptions | Versioned plan catalog, estate agreements, effective entitlements, renewals and platform billing state |

Keep transitions explicit endpoints or commands (approve, reject, terminate, check-in, resolve) rather than allowing callers to patch status fields arbitrarily.

## 7. Backend-first delivery order

### Phase 0 â€” Repository audit (required before application code)

Inspect the actual Zvend backend, frontend/mobile repositories, ORM/schema/migrations, authentication and permission patterns, payment/webhook flow, notifications, private file storage, API conventions, environment variable names (without printing values), deployment and existing build/lint/test commands. Deliver confirmed integration points and a change list.

### Phase 1 â€” Foundation

Estate application/status lifecycle, estate memberships and permission model, estate-context resolution, server-side isolation, audit events and initial administrator assignment. Access, settings and reporting rules are detailed in `Zvend_Estate_Access_Reports_Contract.md`. Add the smallest persistence/API slice consistent with current conventions.

### Phase 2 â€” Properties and people

Estate hierarchy, property register, ownership history, resident approval, tenancy and occupant history. Property mapping and location rules are detailed in `Zvend_Estate_Property_Mapping_Contract.md`. Add administrator screens only after the contracts and authorization rules are established.

### Phase 3 â€” Visitors and security

Unpredictable invitation token/PIN, server-side verification, rate limits, revocation, check-in/out event history and a mobile-first gate workflow. The detailed proposed lifecycle, data concepts, authorization rules, API operations, privacy requirements and repository integration gates are in `Zvend_Estate_Visitor_Security_Contract.md`.

### Phase 4 â€” Charges, rent and payments

Configurable charge/rent schedules, immutable issued invoices, payment provider integration, verified idempotent events, allocations, receipts and reconciliation. Proposed lifecycle, settlement, API and acceptance behavior is detailed in `Zvend_Estate_Billing_Payments_Contract.md`.

### Phase 5 â€” Estate operations

Maintenance, incidents, facilities, announcements, expenses and reporting. Proposed maintenance and facility lifecycle/API behavior is in `Zvend_Estate_Operations_Contract.md`; incidents and expenses have separate `Zvend_Estate_Visitor_Security_Contract.md` and `Zvend_Estate_Finance_Contract.md` contracts; reporting behavior is in `Zvend_Estate_Access_Reports_Contract.md`.

### Phase 6 â€” Hardening and rollout

Cross-estate access review, integration and workflow validation, operational monitoring, backup/restore checks and deployment through the existing pipeline.

The supplied specification requires phase review before proceeding to the next phase.

## 8. UI structure after backend contracts

The UI should communicate the operating product, not the implementation technology. Do not show AI/model language or AI-generated-product claims.

### Estate administration web navigation

- Overview
- Properties
- Residents and landlords
- Tenancies
- Billing and rent
- Visitors and security
- Maintenance
- Facilities
- Announcements
- Finance and reports
- Staff and permissions
- Estate settings and documents

### Initial screen sequence

1. **Estate onboarding/review** â€” applicant-guided estate/operator/location/structure form and document selection, followed by application status, missing items and reviewer actions. Production file upload and application creation must use the existing Zvend identity and private-storage services.
2. **Estate dashboard** â€” property occupancy, resident count, invoices due/overdue, visitor activity and open maintenance, all with clear date/context.
3. **Property register** â€” searchable/filterable units with occupancy, owner and tenancy summary; detail view shows property code/type/location, ownership shares/effective dates, separate operational status and occupancy, lifecycle history, and document/charge entry points according to permission.
4. **Resident/tenancy workflow** â€” pending join requests, person/property relationship, approval history and tenancy dates.
5. **Resident operations workflow** â€” request lists filter by open/resolved state, details expose only resident-visible updates, and allowed resolution confirmation/reopen actions require a connected policy-checked service. Estate staff review uses explicit allowed transitions, assignment history, reasoned resolution/rejection, resident-visible updates, and separately stored private notes.
6. **Visitor workflow** â€” issue/revoke invitations and a separate minimal gate verification/check-in experience.
7. **Billing workflow** â€” configurable charges, invoice lifecycle, payment status and receipt/reconciliation views.
8. **Landlord workspace** â€” switch into property-owner context within the same account; show authorized portfolio, tenants, rent status/history, property charges and agreement/document entry points. Tenant and landlord data must be derived from verified property relationships, not client-selected IDs.

### Platform administration navigation

- Estate applications and lifecycle review
- Plans and estate subscriptions
- Platform staff and permissions
- Platform financial reporting, audit and support operations

Use the image references for restrained green accents, property imagery and readable mobile cards. Keep the admin dashboard information-dense but scannable, with responsive layouts and clear empty, loading, error and success states. Do not turn the estate app into a property marketplace unless that is separately confirmed as a product requirement.

## 9. Repository audit checklist and likely integration targets

The exact file list depends on the source tree. During the audit identify:

- Backend module/route registration and auth guards/middleware.
- User, role, permission and estate-context conventions.
- Database schema and additive migration location.
- Payment initiation, webhook signature verification, transaction records and receipts.
- Notification dispatch and private file/document service.
- Frontend route/layout/menu registration and reusable components.
- Mobile navigation entry points for resident/landlord/security flows.
- Existing environment/deployment configuration and scripts.

Likely additions after confirmation: an estate domain module, additive schema migration, scoped authorization helper/guard, API validation and transition handlers, audit integration, and dashboard routes/components. Avoid naming exact files until repository conventions are known.

## 10. Open items to resolve from source or product owner

- Is this workspace meant to be the Zvend application repository, or should its source be added/selected?
- Which existing payment destinations and settlement models are supported for estate fees versus landlord rent?
- What current user profile fields and identity verification can be reused?
- Which staff roles/permissions are configurable, and who may approve an estate's first administrator?
- Which estate types and property hierarchy levels are enabled for the first release?
- Which document storage provider and retention/access rules are already in use?

## 11. Evidence required before implementation claims

For each phase, report the concrete files/schema/API/UI changed and the existing project commands used for validation. At minimum, demonstrate the phase acceptance criteria in the provided specification, especially cross-estate isolation, privileged status changes, visitor pass expiry/revocation and payment idempotency before those modules are described as complete.

## 12. Current UI preview artifacts

### Estate applicant onboarding preview

`client/lib/onboarding_main.dart` now provides a responsive, three-step estate application draft form for estate identity/location, applicant relationship and management contacts, and property structure. Required values, email format and positive unit count are validated against the editable application draft shape in `backend/modules/onboarding/application-lifecycle.js`. The preview can save a partial draft in memory for the current session; it does not persist to a service, upload documents or submit. The final action explains the existing Zvend identity, private storage, trusted submission policy and audit integration required for production. `dart analyze lib/onboarding_main.dart lib/features/onboarding` reports no issues, and the release build is served at `http://127.0.0.1:8765/onboarding/`.

### Landlord rent invoice preview

The landlord portal now includes a separate Rent view for issued rent invoice summaries, due dates, tenant/property labels, verified allocated amounts, outstanding counts and overdue status. The illustrative data uses an adapter distinct from estate administration billing. The backend composition seam `list-my-landlord-rent-invoices.js` calls the existing relationship-aware invoice list with a server-configured rent category and rejects other categories or non-issued states. The connected resolver/query must verify current payee or ownership rights and scope rows before pagination, while balances continue to derive from verified allocations. No payment command, private receipt file or agreement download is implied. Focused Dart analysis reports no issues, and the landlord release bundle is served at `http://127.0.0.1:8765/landlord/`.

The landlord portal also includes a separate Charges tab for issued property charge invoices, with payment status, due dates and outstanding/paid/overdue filters. `list-estate-invoices.js` accepts a bounded server-configured category list and applies it alongside actor relationship scope before pagination; `list-my-landlord-property-charge-invoices.js` rejects results outside that allowlist or outside issued payment states. These are backend use-case seams only; the preview rows are illustrative and no payment action is enabled.

The landlord Properties area now links to a searchable/category-filtered document library with safe property/name/type/date summaries and an explicit secure-viewer-unavailable preview state. `Zvend_Estate_Property_Documents_Contract.md` defines the ownership-scoped metadata list and per-open reauthorization/private-file grant. The new backend list/access seams never return storage references or permanent URLs; file access is audited and grants are capped at five minutes. Preview rows do not link to real files. A connected private-file adapter and host routes remain to be integrated.

### Resident estate map preview

The resident Community area now has an Estate map entry with building/shared-space filters, selectable place cards, a current-home marker, location confidence labels and an explicit unmapped list. A separate Flutter entry point at `lib/estate_map_main.dart` makes the same screen directly reviewable at `http://127.0.0.1:8765/map/`. The Flutter drawing is an illustrative schematic, not a live map or surveyed geometry; no device location is requested. `backend/modules/properties/list-estate-map-assets.js` validates actor/estate map permission, bounded per-asset results, safe label projections and WGS 84 coordinate/confidence consistency. A production map provider and actor-specific asset query remain to be connected. Focused Dart analysis reports no issues; the resident and standalone map web targets are built and served locally.

### Product reference interpretation

The supplied screenshots were inspected: they depict Homely property discovery (sale/rent listings, saved homes, maps, agent contact and profile screens), not estate operations. The dashboard therefore keeps the written Zvend scope and adopts only a restrained green palette and responsive card treatment. `estate-dashboard/brand.css` layers the brand treatment over the existing dashboard stylesheet, and `estate-dashboard/README.md` records the boundary. No Venco branding or unverified private workflow has been copied. The workspace still contains no Zvend host source or runtime manifest, so all backend modules and UI service adapters remain provisional integration seams; API routes and persistence are not connected to an actual application.

The `estate-dashboard/` folder is a disconnected HTML/CSS/JavaScript design preview. The web dashboard includes the estate overview, property register with schematic map/list views, resident approval list, tenancy register, visitor passes, a separate gate operations screen with local entry/exit examples and incident follow-up, billing list, finance/budget/expense approvals, maintenance triage, facility booking review, announcement targeting/composer, reports, estate team and settings, plus separate platform estate-application and plans/subscriptions screens. Estate application approval includes a first-administrator selection step consistent with the proposed onboarding contract. `resident.html` previews the existing Zvend app's proposed resident experience for home/property, an entry point to the existing Zvend electricity-vending service, an asset-only schematic estate map with selectable home, gate and shared facility markers, invoice details and payment handoff, maintenance request entry, facility booking requests, visitor passes, household access and community notices. The electricity action is a placeholder for integration with Zvend's existing service and must not create a parallel meter or wallet system. The resident map deliberately contains no resident/device location or surveyed coordinates. Local request, booking, settings and decision controls only update preview state; document controls are explanatory placeholders. The property map is schematic and contains no real coordinates. These screens are not authenticated Zvend interfaces and must not be treated as connected or production-ready. Replace sample records and local actions only after the Phase 0 repository audit identifies the real API, authorization and data contracts.

`Zvend_Estate_Backend_Contract.md` defines the proposed Phase 1 application, activation, membership, authorization and audit behavior, with endpoint shapes and UI-to-service mappings. It is an integration contract for review, not a confirmed Zvend API or database schema.

`Zvend_Estate_Phase2_Contract.md` extends the proposed backend boundaries to estate hierarchy, properties, ownership/occupancy history, resident approval and tenancy lifecycle. It is likewise a design contract, not an executable migration or implementation.

`Zvend_Estate_Communications_Contract.md` describes the proposed announcement lifecycle, audience authorization, scheduling, delivery idempotency and reuse of Zvend's existing notification service. It is a design contract, not evidence that those services have been inspected or implemented.

`Zvend_Estate_Finance_Contract.md` defines the proposed budget, expense approval, verified payment allocation and reconciliation boundary. Approval is distinct from payment; this contract is not an executable migration or a confirmed Zvend accounting API.

`Zvend_Estate_Visitor_Security_Contract.md` defines the proposed visitor credential lifecycle, gate authorization, append-only access events, incident workflow and privacy controls. It is not an executable migration or a confirmed Zvend security API.

`Zvend_Estate_Billing_Payments_Contract.md` defines the proposed charge, rent, invoice, payment confirmation, allocation, receipt and reconciliation boundaries. It is not an executable migration or a confirmed Zvend payment API.

`Zvend_Estate_Operations_Contract.md` defines the proposed maintenance request history, staff assignment, facility availability, booking conflict and cancellation behavior. It is not an executable migration or a confirmed Zvend operations API.

`Zvend_Estate_Access_Reports_Contract.md` defines proposed estate-scoped staff access, permission delegation, settings versioning, report filtering and private exports. It is not a confirmed Zvend RBAC or reporting API.

`Zvend_Estate_Property_Mapping_Contract.md` defines proposed asset-only mapping, coordinate validation, layer permissions and location privacy boundaries. It is not a live map integration or confirmed GIS schema.

`Zvend_Estate_Platform_Subscriptions_Contract.md` defines the proposed versioned plan catalog, estate agreements, entitlements and platform billing separation. It is not a connected subscription or platform payment service.

### Gate check-in increment (5 November 2026)

The gate workflow now has a framework-independent check-in use case and a connected-mode credential entry form in `estate-dashboard/gate-visitors-live.js`. The command verifies and consumes the pass in one transaction, creates a checked-in visit, and appends entry and audit records. A scoped `Idempotency-Key` hash binds retries to the same actor, estate, gate and credential so a lost response can return the original result without a second entry. It resolves assigned-gate access before throttling and rechecks access before commit; invalid credentials share one generic failure and denied-attempt records omit the credential and pass reference. The manual-admission increment adds the matching audited path: an explicitly authorized gate staff member, enabled estate policy, in-estate property resolution, visitor name and reason produce a passless active visit, which then appears in the same live list and can be checked out normally. Its separate scoped idempotency record protects retries. The `visitor.override` form is shown only when host context and endpoint configuration are present; backend authorization is still required. `Zvend_Estate_Visitor_Security_Contract.md`, `backend/README.md`, and `estate-dashboard/README.md` describe the route and injected adapter boundary. JavaScript syntax was checked; no route, database, rate-limit adapter, authentication integration or runtime host exists in this workspace, so the flow remains an integration seam and has not been presented as live production behavior.

### Resident facility booking command increment (5 November 2026)

`backend/modules/operations/create-facility-booking.js` now provides the proposed resident booking command. It resolves the resident's facility/property scope, locks the facility, loads server-computed opening/blackout and conflict data, validates the accepted facility policy version and capacity, and atomically creates the booking, links any fee invoice through the billing adapter, writes audit/outbox records and completes a scoped idempotency result. `list-resident-facilities.js`, `read-facility-availability.js` and `list-my-facility-bookings.js` define source-bound resident reads. The resident screen has a connected-mode picker in `estate-dashboard/resident-facilities-live.js`: it replaces sample cards with returned facility data, loads date-specific server slots, captures policy acceptance and submits exact slot times with an idempotency key. Without host configuration it remains an explicit local preview. These are still injected seams; the actual Zvend routes, persistence, transaction, authentication and billing adapters are absent from this workspace.

### Resident incident reporting hardening increment (5 November 2026)

`backend/modules/operations/list-my-incidents.js` now validates the resident incident list as a bounded, source-bound allowlist projection, rejects duplicate/out-of-scope records, and omits attachment references and internal fields. `estate-dashboard/resident-incidents-live.js` now enforces same-origin service URLs, validates response shape and timestamps before rendering with text nodes, avoids surfacing raw service errors, and discards results when the selected estate changes during a request. Syntax checks passed. API route, authentication, persistence, attachment storage and notification adapters remain unconnected because the Zvend host application is not present in this workspace.

### Resident maintenance list hardening increment (5 November 2026)

`backend/modules/operations/list-my-maintenance-requests.js` now requires canonical timestamps and bounded display labels while keeping resident-visible updates separate from internal notes. The connected resident maintenance UI enforces same-origin requests, checks paginated response metadata and each safe request/update field, rejects cross-estate or duplicate results and uses generic request errors. JavaScript syntax checks passed. The configured Zvend routes and runtime remain integration points because the host application source is absent here.

Maintenance submission now requires `Idempotency-Key`. The use case scopes hashed claims to the authenticated resident and estate, binds each key to the normalized property/category/priority/description/attachment payload, and stores its safe result in the request transaction so retries return the original result and conflicting reuse fails. The resident form retains a cryptographically random key for unchanged retries and creates a new key when the request changes. Host routes must provide unique idempotency persistence and pass request headers through their authenticated API adapter.

`backend/modules/operations/read-my-maintenance-request.js` adds a resident-only detail read using the same allowlisted projection as the request list. `resident-operations-live.js` now fetches scoped detail history when a request opens, discards responses after estate changes or panel close, and presents a safe retry message if the detail read fails. The host must bind the existing `GET /api/estate/maintenance/requests/:requestId` route to this use case or configure a detail URL template.

The connected estate maintenance queue in `estate-dashboard/maintenance-live.js` now requires same-origin service URLs, validates each bounded queue row, visible update, permitted command, assignee and capability before using the response, and displays generic errors. Backend transitions remain the final permission and state boundary; the host must still bind these UI calls to the existing review use case and audit/outbox services.

### Flutter client direction (5 November 2026)

The user has explicitly requested Dart and Flutter for the frontend. `client/` is now a Flutter app targeting Android, iOS and web, with a responsive resident shell and repository interface. `PreviewResidentEstateRepository` is deliberately sample-only; it does not create a parallel identity, payment or notification service. The supplied Homely screenshots inform green styling and card layout only, not property-marketplace features. The original product blueprint describes a resident experience inside the existing Zvend app and a separate admin web dashboard; because the Zvend host repository is absent, both remain integration-ready previews. The product document's earlier JavaScript coding preference is superseded for new frontend work by the user's current explicit Flutter direction.

Flutter verification: flutter analyze reports no issues, and flutter build web --release succeeds. The generated bundle is in client/build/web; web, Android and iOS app labels use Zvend Estate and the web/Android icons use the project house mark. Flutter's release build prints a Cupertino icon font notice inherited from the generated scaffold, but it completes successfully; no Cupertino icon is referenced by the app.

### Resident maintenance request UI increment (6 November 2026)

The Flutter resident Requests surface now supports opening a maintenance request form, validating the contract's categories, priorities and 700-character description limit, and reviewing request details with resident-visible updates only. The form holds one cryptographically random idempotency key stable across an unchanged retry and rotates it if request contents change after a failed submission. The preview repository validates the same field envelope, replays an identical key/payload and rejects changed payload reuse, then retains the request in session memory only. Urgent priority displays the contract's emergency-dispatch disclaimer. Private file upload remains unimplemented until the client can call Zvend's existing authenticated private-file adapter. `flutter analyze` reports no issues and `flutter build web --release` succeeds for this increment.

### Estate administration Flutter web increment (6 November 2026)

The Flutter client now has a separate `lib/admin_main.dart` web entry point for the estate administration dashboard, plus a responsive app surface linked from the resident preview for review. Its navigation reflects the 18 estate modules in the product brief. The overview model follows `backend/modules/reporting/dashboard-summary.js`: it carries per-section availability and source freshness, displays only supplied metric sections, and separates property occupancy, active tenancy, visitor activity, maintenance and verified finance summaries. The maintenance queue is a safe sample preview with a request detail dialog; assignment and state-changing review commands remain unavailable without the authenticated host adapter. Other unconnected modules explain their unavailable state. Both resident and admin Flutter targets pass `flutter analyze`; `flutter build web --release` succeeds for `build/web`, and `flutter build web --release --target lib/admin_main.dart --output build/admin` succeeds for the separate admin target. Sample preview identity and data remain illustrative; no Zvend session, capability resolver, database or API is present in this workspace.

### Resident membership review Flutter increment (6 November 2026)

The admin Residents module now reads a preview queue model aligned to `list-resident-join-requests.js` and opens a separate detail model aligned to `read-resident-join-request.js`. The screen supports submitted/approved/rejected/withdrawn status, relationship and applicant/property search filters. Detail shows the applicant note, safe property/relationship labels, document counts/categories and an existing decision reason without exposing private file references. Approve/reject controls are visible but disabled until a connected host adapter can run the permission-checked transaction in `decide-resident-join-request.js`. The property register and estate structure screens added alongside remain sample-only. `flutter analyze` reports no issues, both `build/web` and `build/admin` release bundles rebuild successfully, and the local admin preview responds with HTTP 200 for its page and JS bundle.

### Visitor access Flutter dashboard increment (6 November 2026)

The Visitors module now has a responsive Flutter screen with active/expired/revoked/checked-in pass filters, visitor/host/property search, a current-visitor gate view, entry-use summaries and explicit manual-admission labeling. Its projections omit visitor credentials, credential hashes, pass IDs from the gate list, and private storage references. Commands such as pass creation, gate verification, revocation and check-out remain unavailable until the Zvend host supplies authenticated, estate/gate-scoped services. The implementation follows the safe summary fields in `Zvend_Estate_Visitor_Security_Contract.md` and remains sample data. `flutter analyze` reports no issues; the admin web release target rebuilt successfully and the local preview is available at `http://127.0.0.1:8766/`.

### Resident facilities Flutter increment (6 November 2026)

The resident Community > Facilities entry now opens a responsive facility catalogue and a My bookings view. Facility cards show category, location, opening hours, capacity, slot duration, approval mode and configured fee labels. Booking summaries show the resident-facing status, time, attendee count and reference. The repository interface is ready for authenticated facility/booking reads; `PreviewResidentEstateRepository` supplies illustrative data only. Booking submission remains disabled until the host can load current availability, enforce policy and reserve the slot transactionally. `flutter analyze` reports no issues, `flutter build web --release` succeeds, and the resident preview is served at `http://127.0.0.1:8765/web/`.

### Resident visitor pass Flutter increment (6 November 2026)

### Resident visitor pass Flutter increment (6 November 2026)

The resident Community > Visitor passes entry now opens a pass history view for active, checked-in and expired guest invitations, with validity, use count and optional vehicle summary. Credential/PIN data is deliberately absent from the model and UI. Creating or revoking a pass remains unavailable until the authenticated Zvend access adapter can return a newly issued credential once and enforce host/property access. lutter analyze reports no issues; the resident web release target rebuilds successfully and is served at `http://127.0.0.1:8765/web/`.




### Resident community notices Flutter increment (6 November 2026)

The resident Community > Community notices entry now opens a feed of audience-scoped announcement summaries and expands to show the message body, category, issue date and important-update treatment. It contains no recipient/contact lists or delivery metrics. The preview repository provides sample announcements; the connected adapter must query the authenticated resident's eligible notices and use Zvend notification/read-receipt services. `flutter analyze` reports no issues, `flutter build web --release` succeeds, and the resident preview is served at `http://127.0.0.1:8765/web/`.

### Resident invoice and payment history Flutter increment (6 November 2026)

The resident invoice entry and home payment summary now open an invoice list with expandable line items, due dates, current balance, payment history and receipt references. The model contains only verified-payment summaries and safe receipt IDs; provider references and storage keys are excluded. Payment and private receipt access remain disabled until the existing authenticated Zvend billing/payment adapter is connected. `flutter analyze` reports no issues, `flutter build web --release` succeeds, and the resident preview is served at `http://127.0.0.1:8765/web/`.



### Platform application review Flutter web increment (6 November 2026)

A separate `lib/platform_admin_main.dart` entry now builds the platform operator application review dashboard, separate from the estate staff dashboard. It provides a reviewer queue with status filters and search, summary counts, applicant/estate details, safe document-review counts, applicant review message, and the initial estate administrator eligibility step required for approval. Review decisions and private document access remain disabled until platform authorization, existing-user lookup, private-file access and the atomic Zvend approval service are connected. `flutter analyze` reports no issues; `flutter build web --release --target lib/platform_admin_main.dart --output build/platform --base-href /platform/` succeeds. The platform preview is served at `http://127.0.0.1:8765/platform/`.

### Estate finance and expense-review Flutter increment (6 November 2026)

The estate Finance and expenses section now provides an approved-budget overview and a searchable expense-request queue with status filters and detail summaries. Budget rows separate allocated, committed, verified paid and available amounts. Expense details distinguish approval from payment and expose only safe payment allocation summaries; payee account data and provider references are not shown. Request, approve, reject and payment controls remain unavailable until the authenticated estate finance and existing payment services are connected. `flutter analyze` reports no issues, and the separate estate admin web target builds successfully at `build/admin`.

### Estate facility booking review Flutter increment (6 November 2026)

The estate Facilities and bookings module now shows a searchable, status-filtered booking queue and request detail with resident/property, slot, attendee count, policy version, fee, payment state and decision note. Confirmation and decline controls remain disabled until the authenticated estate approval service can transactionally recheck capacity/conflicts and append the decision. Fees remain distinct from approval and payment is displayed only from verified status. `flutter analyze` reports no issues and the separate estate admin web release target rebuilt successfully.

### Security incident queue Flutter and backend projection increment (6 November 2026)

The estate Security and incidents page now shows the bounded queue fields for category, priority, status, observed/reported time, safe location, authorized reporter display name and gate label. Filtering is local to the loaded preview rows. Incident descriptions, investigation details and private attachment references are absent from the queue; state changes remain disabled pending the authenticated audited incident service. The backend `list-estate-incidents.js` safe projection now binds priority to the source incident and returns it as bounded display text. `node --check` and `flutter analyze` pass; the admin web release target rebuilds successfully.

### Estate team and permissions Flutter increment (6 November 2026)

The Staff and permissions dashboard section now lists active estate memberships and invited/suspended/revoked/expired records, with status/search filters and safe profile, role label, scope label, invitation expiry and last-active fields. Role names are display groupings; the UI does not treat them as authorization. Invite, role-change and membership lifecycle controls remain disabled until connected to Zvend delegation policy, identity, audit and access-invalidation services. The read model follows `list-estate-team.js` safe projections. `flutter analyze` reports no issues and the admin web release target rebuilt successfully.

### Estate reports dashboard Flutter increment (6 November 2026)

The Reports and analytics section now renders only dashboard snapshot sections available to the actor. It displays period/as-of time, source freshness and per-section availability, then shows the corresponding estate, tenancy, visitor, maintenance or finance summary fields. Incomplete, delayed or unreconciled sections stay explicitly labelled; no trend or export data is invented. Export remains unavailable until a permission-scoped report/export service is connected. `flutter analyze` reports no issues, and the estate admin web release target rebuilt successfully.

### Estate tenancy register Flutter increment (6 November 2026)

The estate Tenants and tenancies section now lists bounded actor-authorized summaries for property, tenant, optional landlord, rent frequency/amount, term dates, next due date and lifecycle status, with search and status filters. Its model mirrors the allowlist in `list-estate-tenancies.js`; the connected service must apply estate and relationship authorization before filtering or pagination. Create and lifecycle commands remain unavailable until connected to authenticated tenancy command services. `flutter analyze` reports no issues. The release web rebuild was attempted, but the compiler stalled before producing a fresh bundle, so the visible browser preview may still show the previous build.

### Landlord portfolio Flutter increment (6 November 2026)

The Landlords module now presents the authenticated actor's verified ownership property summaries with estate, operational state, occupancy, tenant and current tenancy context where authorized. Search and occupancy filters operate on the returned portfolio. Contract rent is labelled as contract rent and is not shown as received rent or outstanding balance. The projection follows `list-my-landlord-portfolio.js`, which requires verified active ownership and a bounded estate-scoped portfolio. `flutter analyze` reports no issues; the estate admin preview web bundle was refreshed after this screen was added. Preview rows remain illustrative and export remains disabled until a permission-scoped host report service exists.

### Estate billing register Flutter increment (6 November 2026)

The Billing and notices module now lists invoice summaries with payer/property, category, due date, total, balance, status and dispute marker, with search and status/dispute filters. The model follows `list-estate-invoices.js`; balances are derived by that service from authorized allocation history. The screen does not expose provider references, payout destinations or private receipt storage keys. Create invoice remains disabled pending the existing authenticated billing and payment services. `flutter analyze` reports no issues. Web compilation was attempted for both release and debug targets, but the Flutter compiler stalled before replacing the preview bundle; the code is ready but the browser preview has not yet been refreshed.

### Estate announcements workspace Flutter increment (6 November 2026)

The Communications section now has a resident announcement composer layout, audience and channel selections, emergency permission context, and a filterable lifecycle timeline for sample draft, scheduled and published updates. All mutation controls are disabled because the workspace has announcement domain transition rules but no list use case, notification adapter, persistence or authenticated host route. No client state is represented as sent. `flutter analyze` reports no issues; the Flutter web compiler produced a JavaScript bundle in its build cache, which was copied into the served admin preview and verified over HTTP (2.83 MB bundle with the composer text present).

### Rent schedule management Flutter increment (6 November 2026)

The Rent management module now lists active tenancy rent terms and next due dates, with search, month filters and a missing-date indicator. It derives no collection totals and clearly directs invoice balance/collection status to Billing's verified allocation projection. The billing contract defines schedule terms as originating from approved tenancies and invoice generation as idempotent; no standalone schedule service exists in this workspace. Invoice generation therefore remains disabled pending the authenticated command adapter. `flutter analyze` reports no issues; the new release bundle was copied from Flutter's completed compiler cache and verified through the running admin preview over HTTP.

### Administrative charge register Flutter increment (6 November 2026)

The Administrative charges module now shows charge definitions with category, exact decimal amount/currency, recurrence, applicability scope, due rule, active/draft status and effective period, plus search and status filters. It reflects the Billing contract's versioned effective-dated model and states that changes apply only to future invoice generation; issued invoices remain immutable. Create/edit/version history controls remain disabled because no backend charge configuration use case or authenticated route exists yet. `flutter analyze` reports no issues; Flutter's completed JavaScript compiler artifact was copied into the served admin preview and verified over HTTP with the new module string present.

### Estate settings summary Flutter increment (6 November 2026)

The Estate settings module now displays the allowlisted operational estate summary: name/type/status, estate code, address, LGA/state, configured timezone and currency. It calls out that estate document storage, payment destination management and notifications use separate authorized Zvend integrations, and platform subscription terms belong to platform operations. It does not expose private onboarding documents or provide unbacked edit controls. `flutter analyze` reports no issues; the admin web bundle was refreshed from the completed Flutter cache artifact and verified over HTTP with the settings screen included. The current repository has no estate settings mutation or estate document library service.

### Resident My Property and estate charges increment (6 November 2026)

The resident Community menu now includes a My Property detail view for property identity and actor-authorized ownership/occupancy records, plus an Estate charges view for charge rules applicable to the resident's property. Charge rules are labelled separately from invoices and balances. Property detail follows `read-property-detail.js`; the new resident-safe `list-my-applicable-charges.js` backend seam resolves property and resident role first, filters effective active definitions against server-owned applicability, validates exact decimal amounts and dates, and returns a limited display projection without destination/policy internals. `dart analyze` reports no issues for the touched resident files and `node --check` passes for the new backend seam. The resident preview bundle still needs a web rebuild before these screens are visible in the browser.

### Resident My Rent Flutter increment (6 November 2026)

The Community menu now includes My Rent when the authorized tenancy read returns an active tenancy summary. It shows the property, landlord, agreed rent, term and next due date, and links to the resident invoice/payment history. The no-active-tenancy response gets a clear empty state. The screen explicitly does not treat agreed rent as paid or outstanding balance. `dart analyze` reports no issues; the resident release bundle was refreshed with `/web/` base path and verified at the running preview: page and JS return HTTP 200, and the bundle contains My Rent, no-active-tenancy, My Property and Estate charges entries.

### Security gate Flutter web preview (6 November 2026)

A separate `lib/security_main.dart` target now presents assigned-gate context, shift and staff assignment, expected visitors, current check-ins, pass/manual admission labels and emergency contacts in a mobile-first layout. Search and visitor-list tabs are available. QR/PIN verification, check-out and contact actions stay disabled because they require host identity, gate assignment, visitor commands and trusted contacts. Gate data is illustrative and uses its own `SecurityRepository`; it does not grant estate-admin access. `dart analyze` reports no issues. The security release target was built to `build/security` with `/security/` base and verified on the local preview server: page and JS return HTTP 200 and the bundle contains the gate, emergency and pass-scanner UI.

### Ownership verification queue Flutter increment (6 November 2026)

The property register now links to an ownership verification queue showing only owner display name, property code/structure, share, effective date, relationship status and evidence category. The page separates the ownership verification state from estate membership or staff role. Evidence access and verify/reject actions remain disabled until the host uses the private file access flow and `ownership.verify` command with permission checks, reason and audit. `dart analyze` reports no issues; the estate admin release bundle was refreshed from Flutter's compiled output and verified at the local preview (HTTP 200 with ownership queue strings present).

### Facility booking review increment (7 November 2026)

The estate admin facility booking dialog now supports confirming and declining pending review requests. Declines require a reason and confirming is blocked in the preview while payment is pending. Preview outcomes are session-local and clearly identified as non-persistent sample behavior. `backend/modules/operations/decide-facility-booking.js` composes the domain planner with `booking.approve`, locked same-estate records, fresh availability/policy checks, verified billing state, transaction commit, audit and notification outbox adapters. Concurrent confirmations still require host-level serialization for the relevant facility/time scope. Flutter analysis and Node syntax checks pass; the refreshed admin web bundle is served at `http://127.0.0.1:8765/admin/`.

### Resident facility request form Flutter increment (7 November 2026)

Resident Community > Facilities now lets a resident prepare a request draft with start time, attendee count, optional purpose and an explicit acceptance checkbox for the sample facility policy version. The draft appears under My bookings and is labeled “Draft · preview only”; the page states that availability is unchecked and no slot, invoice or booking is created. The connected command remains `backend/modules/operations/create-facility-booking.js`, which must load current server-side availability and policy, enforce actor/property scope and idempotency, and create any fee invoice via Billing. `flutter analyze` reports no issues; the resident web build is served at `http://127.0.0.1:8765/web/` and its page and JS return HTTP 200 with the new form copy present.

The facility draft action now writes through `PreviewResidentEstateRepository.createFacilityBookingDraft` rather than remaining only in widget state. The repository checks the sample facility/policy, future start time and attendee capacity, and its session-backed in-memory list makes drafts available again after leaving and reopening Facilities during the running app. It is still not persisted across app reloads or sent to the estate service. Flutter analysis remains clean; the refreshed resident bundle returns HTTP 200 and includes the draft action.

### Resident home quick-service navigation (7 November 2026)

The resident home shortcuts now route Visitors to Visitor passes, Facilities directly to the facility catalogue, and Bills to Billing. Previously Visitors and Bills displayed obsolete “not available” messages and Facilities only opened the generic Community page. These shortcuts reuse the existing resident shell routes, preserving the Community back path and payment preview boundary. `flutter analyze` reports no issues; the refreshed `/web/` page and JS return HTTP 200, and the obsolete messages are absent from the served bundle.

### Resident join-request decision preview (7 November 2026)

The estate admin join-request detail sheet now supports local approve/reject decisions. Approval has a confirmation step that explains its production membership/occupancy effect; rejection requires a reason, limited to 500 characters. The preview repository updates the request and decision history in session memory, and the queue reloads after the sheet closes. The sheet states that connected decisions need authorization and atomic membership/occupancy/audit updates; this preview does not grant access or inspect private files. It follows the existing backend command `backend/modules/people/decide-resident-join-request.js`. `flutter analyze` reports no issues; the refreshed `/admin/` page and JS return HTTP 200 and include both actions and rejection validation.

### Facility booking cancellation backend seam (7 November 2026)

`backend/modules/operations/facility-booking.js` now includes `planBookingCancellation`, and `cancel-facility-booking.js` composes it with an estate-scoped locked lookup, requester/staff authorization, the captured policy version, verified Billing refund preparation, atomic cancellation/refund-request persistence, audit and outbox notification. The planner rejects terminal booking states and validates that any refund references the linked invoice, uses its captured fee currency/precision and does not exceed the original facility fee. Billing still owns provider refund execution; cancellation never edits a payment. `node --check` passes for both changed backend modules. The command remains an integration seam because the Zvend service, route and adapter implementation is absent from this workspace.

### Gate manual admission preview increment (7 November 2026)

The standalone Flutter security visitor tab now supports a manual admission preview form for visitor name, property reference and a reason of at least ten characters. A submitted record appears at the top of the session-local current visitor list as “Manual admission.” The screen explicitly says the preview does not resolve the property, authorize the gate actor or append a live access event. The connected domain command remains `backend/modules/visitors/create-manual-admission.js`, whose permission, estate/property resolution, idempotency, access event and audit adapters remain required. `flutter analyze` reports no issues; the `/security/` release build succeeds and the page and JS return HTTP 200 with the manual admission controls and validation present.

### Estate staff invitation preview increment (7 November 2026)

The Estate team page now opens an invitation preview form with email and a constrained estate role. The preview repository validates the address and role, checks for an existing non-revoked/non-expired team record, and adds a session-local row labeled “Preview scope.” The interface states that no account is looked up, no role is granted and no email is sent. The connected command remains `backend/modules/access/invite-estate-staff.js`, where identity lookup, estate authority, role delegation, invitation token/expiry and delivery adapters must be connected. `flutter analyze` reports no issues; the refreshed `/admin/` page and JS return HTTP 200 and the invite/no-email copy is present in the served bundle.

### Resident visitor pass draft repository increment (7 November 2026)

The resident visitor draft action now calls `ResidentEstateRepository.createVisitorPassDraft` rather than adding the row only to page state. The preview adapter validates visitor/vehicle bounds and a future validity window, then stores a clearly labeled `preview_draft` in session memory; reopening Visitor passes reloads it from the repository. It does not issue a credential, create an active pass or persist across reloads. `backend/modules/visitors/create-visitor-pass.js` remains the authenticated production command seam and must enforce host/property scope, current policy, idempotency, secure credential handling and atomic audit/outbox persistence. `flutter analyze` reports no issues; the refreshed resident page and JS return HTTP 200 and contain the draft action and no-credential notice.

### Security gate check-out preview increment (7 November 2026)

The currently-inside visitor list now offers a confirmed check-out preview action. It removes the selected visit from the preview repository's active list and refreshes the gate overview count; the confirmation and result state that no live access event was recorded. The overview visitor summary stays read-only. The connected command remains `backend/modules/visitors/check-out-gate-visit.js`, which must verify assigned-gate access, lock the active same-gate visit, commit check-out plus access event and audit atomically. `flutter analyze` reports no issues; the refreshed `/security/` page and JavaScript return HTTP 200 and include the action and preview boundary copy.

### Security incident report preview increment (7 November 2026)

The standalone Flutter gate app now includes an Incidents tab and report form for sample category/priority, optional location, observed time and description. A saved report appears in the session-local “My incident reports” list with a preview reference; the form and result state that no report, notification or audit event was submitted. The allowed categories/priorities are sample values until the estate incident policy is connected. The production seam is `backend/modules/operations/create-incident-report.js`, which resolves reporter/gate scope and current policy, validates private attachment references, and commits the incident, audit event and notice together. `flutter analyze` reports no issues; the refreshed `/security/` page and JS return HTTP 200 with the report tab, form and preview boundary present.

### Admin incident report preview increment (7 November 2026)

The estate Security and incidents page now opens a report form for sample category/priority, required location and description, and observed time. Saving adds a `reported` summary marked with a `PREVIEW-` reference; this remains session-local and does not send a notification or write an audit event. The description is held separately from the queue summary and shown only through the preview detail action. Sample options remain until the host incident policy is connected. The production command seam is `backend/modules/operations/create-incident-report.js`, which checks reporter scope and policy, validates private attachment references, and commits the report, audit event and notice together. `flutter analyze` reports no issues; the rebuilt `/admin/` page and JS return HTTP 200 with the report form, detail boundary and preview-only copy present.

### Estate tenancy creation preview increment (7 November 2026)

The Tenants and tenancies page now opens a tenancy form using repository-provided eligible property/account options, NGN rent amount and frequency, and start/optional end dates. The preview repository only offers active vacant properties with verified owner metadata, validates exact two-decimal rent strings and date ordering, and prevents a second preview tenancy for the selected property. A saved row is pending and session-local; the page states that account/payee eligibility is not checked with Zvend and no approval, occupancy or invoice is created. Production integration remains `backend/modules/people/create-tenancy.js`, whose adapters must validate existing same-estate tenant/payee identities, policy, property availability and atomic audit persistence. `flutter analyze` reports no issues; the rebuilt `/admin/` page and JS return HTTP 200 with the form, decimal amount control and preview boundary copy present.

### Admin incident lifecycle preview increment (7 November 2026)

Preview-created incident records now expose only lifecycle actions valid for their current state: acknowledge, investigate, contain, resolve, close and reopen. Containment/resolution/closure/reopening require a reason, bounded to 500 characters. The preview repository rejects actions on seeded sample records and invalid transitions, updates the session-local summary and keeps a separate local decision history for the preview detail view. Every dialog/result says this does not update a live incident or write an audit event. This follows `backend/modules/operations/incident.js` transition rules; production changes still require the authenticated status/update use case, assignment policy where applicable, atomic history/audit and notification adapters. `flutter analyze` reports no issues; the refreshed `/admin/` page and JS return HTTP 200 and include transition controls, reason validation and preview history.

### Rent schedule invoice run preview increment (7 November 2026)

Rent management now offers a billing-month preview of active tenancy schedules whose next due date falls in the selected month. The preview repository validates the month and returns a sorted, read-only schedule list; the dialog labels this as sample data and states that it creates, issues and sends no invoice. It also calls out the Billing service checks still required: approved tenancy, settlement destination and duplicate-generation keys. Production invoicing remains behind the `backend/modules/billing/create-invoice-draft.js` transactional command seam. `flutter analyze` reports no issues; the rebuilt `/admin/` HTML and JavaScript return HTTP 200.

### Estate structure node creation preview increment (7 November 2026)

The Flutter Zones and buildings screen now includes an Add structure node form for zones, streets, buildings and floors. Parent options are restricted by node type and active status; name/code bounds and same-type duplicate codes are checked in the preview repository. Added nodes remain session-local and the form states that it does not update the estate service. The production command contract is `backend/modules/properties/manage-estate-structure.js`, which resolves estate permission, loads trusted structure policy, validates same-estate parents and code availability, then commits the node and audit event in one transaction. `flutter analyze` reports no issues; the admin release build completed and `/admin/` page and JavaScript return HTTP 200 with the add form and parent validation copy present.

### Estate structure update and archive previews (7 November 2026)

The structure tree now offers preview rename/recode for active nodes and non-destructive archive for nodes with no active children and zero linked properties. The preview repository rechecks active status, field bounds, same-type code uniqueness and archive relationships before updating its session-local records. Type and parent edits stay out of the form to preserve existing hierarchy links. Production commands remain `backend/modules/properties/update-estate-structure-node.js` and `archive-estate-structure-node.js`; connected adapters must validate child/property compatibility, lock relationships and write the audit event transactionally. `flutter analyze` reports no issues; the admin release target rebuilt and `/admin/` page and JavaScript return HTTP 200 with edit, archive and relationship guard copy present.

### Estate map location update command seam (7 November 2026)

Added `backend/modules/properties/update-estate-map-asset-location.js`. The command requires a resolver that confirms both estate map-location permission and target-asset management permission, checks the locked asset belongs to the selected estate, validates WGS 84 coordinate pairs, explicit confidence, estate-allowed source and optional accuracy, then commits the location and reason-bearing before/after audit event in one transaction. Explicit unmapped state has null coordinates and accuracy. The map read projection now validates and returns bounded `accuracyMeters`. `node --check` passes for both changed backend modules. Zvend authorization, locking, persistence, audit and approved map-provider adapters remain host integration requirements; no resident/device location is accepted.

### Property map location confidence preview (10 November 2026)

The Flutter admin property detail now reports location confidence/source/known accuracy and opens a map-location form for active properties. The form validates paired WGS 84 latitude/longitude bounds, optional accuracy, reason length, and verified/approximate/unverified/unmapped state; unmapped clears coordinates. The preview repository changes only session-local sample records and the form states that no live map update or audit event occurs. It does not use a map SDK or device location. The corresponding production write boundary is `backend/modules/properties/update-estate-map-asset-location.js`, which performs asset+estate permission resolution, locked same-estate validation, configured source validation, and transactional location/audit persistence. `flutter analyze` reports no issues and the admin release build completed; the preview HTTP server stopped during the environment change and must be restarted before browser verification.

### Resident map source and accuracy details (10 November 2026)

The resident schematic map now carries optional location-source and accuracy metadata on its asset model. Selecting a place shows its source and known accuracy alongside the existing verified/approximate/unverified/unmapped state; the place list shows accuracy where present. Current values are labeled sample values, and the diagram remains illustrative and not to scale. The map continues to request no device location. `flutter analyze` reports no issues; the resident web release build completed and the refreshed `/web/` page and JavaScript return HTTP 200 with source, accuracy, sample and no-tracking copy present.

### Estate property creation preview (10 November 2026)

The Flutter property register now offers Add property. Its form captures a unique estate property code, configurable type, operational status, optional unit/house number and optional active hierarchy parent. The preview repository validates bounded fields, status, same-estate active parent and duplicate code, then adds a vacant property summary in session memory. The form makes clear that no owner, occupant, tenancy, map location or live estate record is created. This follows `backend/modules/properties/create-property.js` and `property.js`, whose host use case resolves `property.manage`, verifies active same-estate hierarchy parents and code uniqueness, then commits the property and audit event atomically. `flutter analyze` reports no issues; the admin release build completed and the served `/admin/` page and JavaScript return HTTP 200 with the form and preview boundary present.


### Property archive preview (11 November 2026)

Property details now offer a confirmed, non-destructive archive action for preview-created records only. The preview repository rejects seeded property records because their relationship state cannot be verified, rejects already archived records, and checks the new record remains vacant with no ownership or tenancy summary before changing its status to archived. The record remains in the register and its history is retained. The production boundary is `backend/modules/properties/archive-property.js`, which must lock the property, inspect all ownership, occupancy, tenancy, billing and access relationships, and commit the archive status plus audit event atomically. `flutter analyze` reports no issues; the refreshed admin release bundle returns HTTP 200 for the page and JavaScript and contains the archive confirmation and relationship guard text.

### Property address and description preview (11 November 2026)

The Add property preview now captures optional address (up to 240 characters) and description (up to 700 characters), retains them through map updates and archival, and displays both on property details. These fields align with the create-property validation and detail projection; they remain session-local preview data until connected to the authorized property command.

### Property details edit preview (11 November 2026)

Property details now open an Edit details form for non-archived records. It captures code, type, status, unit number, address and description, validates bounds and estate-local duplicate codes, and updates session preview records while retaining their occupancy, ownership, tenancy, structure label and map metadata. The Add property form's typed result now carries address and description through to preview creation. These edits do not call the production `update-property.js` command until the authenticated API adapter is connected.

Both Flutter web release targets rebuilt successfully: admin at `/admin/` and resident at `/web/`. The served page and JavaScript endpoints return HTTP 200; the admin bundle includes Edit details, Operational status and optional address fields, while the resident bundle includes the profile, community requests and household members. The updated routes are open in visible Chrome windows.

### Resident profile and community request view (11 November 2026)

The Flutter Account destination now presents a resident profile card, active estate/property context, an estate membership switch entry, and the latest resident-scoped maintenance requests. Request rows open the existing resident-safe detail sheet, and See all routes to the maintenance register. Estate switching remains a host Zvend membership action; the preview does not fabricate memberships or change estate context. The changed resident and property Dart files pass the Dart analyzer directly. The served admin preview is still the prior release because the Flutter CLI startup repeatedly attempts to rebuild its tool snapshot and Dart packages in the SDK installation outside this workspace; the preview endpoint itself responds HTTP 200.

### Property update service boundary (11 November 2026)

Added `backend/modules/properties/update-property.js` and the estate-scoped `PATCH` contract. It resolves `property.manage`, locks and verifies the selected property, prevents edits to archived records, validates an allowlist of property fields and active same-estate parents, verifies changed codes, then commits and audits the update atomically. Estate, ownership, occupancy, archive and system fields are immutable through this command. This provides the backend write boundary needed before enabling ordinary property edits in the admin register; persistence, route and host permission adapters remain unconnected pending the actual Zvend repository.

The update command now requires the locked property source to include its current parent IDs, even when hierarchy is not being edited. Missing hierarchy data fails closed instead of treating an unknown relationship as an empty parent list.

The backend contract now documents partial-update/null-clearing behavior, full replacement semantics for supplied `parentIds`, allowed operational statuses, the dedicated archive/map commands, and the required estate/property-code uniqueness constraint.

The shared property draft validator now bounds code/type to 80 characters, unit number to 80, address to 240, and description to 700, matching list/detail/UI projections.

### Resident household profile preview (11 November 2026)

The resident Account tab now loads the authenticated property projection alongside maintenance requests and shows only active `household_member` occupancy records for the active estate/property. Names and relationships come from `loadMyProperties`; the screen does not add/remove household access. Direct Dart formatting and analysis pass for the changed Flutter sources.

### Standalone account, onboarding API and platform review foundation (11 November 2026)

The product is being built as its own estate-management system. The Flutter onboarding entry now uses the workspace API for registration, sign-in and applicant-scoped application drafts; native refresh credentials use secure storage and browser credentials remain in memory. The NestJS API has a PostgreSQL schema for accounts, applications, documents, estates, memberships and audit events. A platform review API now provides a role-scoped queue, safe application/document metadata, reviewer assignment, review start, request-information/reject decisions, and approval that creates the active estate, initial administrator membership and audit records in one transaction. The backend TypeScript build succeeds. The local database still needs credentials and migrations initialized; document upload, applicant notification delivery, account verification/recovery and a live platform-review Flutter adapter are outstanding. The current onboarding web artifact predates the new API-backed login and is being rebuilt for the visible preview.

### Invoice issuing and estate transfer instructions (13 November 2026)

Estate finance managers can configure versioned bank-transfer instructions for each currency, activate a draft instruction set, and issue invoice drafts from the manager billing register. Issuing assigns the invoice number, snapshots the chosen bank, account and payment reference onto the invoice, and writes an audit event in the same database transaction. The resident billing view now reads issued invoices and displays those saved instructions. Updating active instructions does not rewrite previously issued invoice snapshots. Draft invoices remain drafts until a manager issues them. This work supports bank-transfer instructions only: it does not verify transfers, record settlements, reconcile statements, or produce receipts, so an invoice remains outstanding until a verified payment workflow is built.

### Live landlord rent schedule preview (13 November 2026)

Added authenticated `GET /api/v1/estate/estates/:estateId/rent-schedule-preview?year=YYYY&month=M` for estate finance staff and managers. The API selects active approved tenancies whose effective term overlaps the requested month, applies monthly/quarterly/annual recurrence from the tenancy start month, clamps due dates to the selected calendar month, and returns tenant, property, named rent payee, amount, currency and due date. The manager Flutter dashboard opens this data for the current or next month. The page explicitly distinguishes landlord rent from estate charges and creates no invoice/payment record. Finance-only memberships are routed to finance pages without operational property, gate, facilities, maintenance or resident-review controls.

### Estate in-app announcements (13 November 2026)

Added persistent estate announcement drafts, publish transitions and per-resident read receipts. Estate administrators and managers can create and publish notices to the fixed `ALL_RESIDENTS` audience; emergency priority is restricted to an estate administrator. Residents and landlords can list published notices only for their active estate memberships and mark each notice read. Draft, publish and first-read actions create audit events. The manager Flutter screen provides draft composition and publish confirmation; the resident home shows published notice cards and records read state when expanded. The additive PostgreSQL migration is deployed. This first version is an in-app feed only: no push/email/SMS provider, scheduling, custom audience targeting or delivery metrics are claimed.

The resident home now loads this notice feed independently from estate, tenancy and access-request data. If the communications endpoint is unavailable, the other home sections still load and the notice panel offers an explicit retry.

### First platform administrator bootstrap (13 November 2026)

Added an operator-only CLI to grant the first platform_super_admin to a selected existing active account. The email must be supplied and echoed in an exact confirmation argument; the command is not available over HTTP and is idempotent. The grant and system-attributed platform audit event commit in one serializable transaction. The platform review app can then use the existing reviewer queue and approval API. The bootstrap command still must be executed by an operator for the intended account in each environment; no default account or credential is created.

### Estate finance dashboard invoice summary (13 November 2026)

The authenticated manager dashboard now aggregates issued invoices with no recorded settlement, grouped by currency, and displays their count and issued total. The UI labels these as unpaid issued invoices and states that the figure is not money collected. Invoice issuance copy now clarifies that the demand becomes available in resident billing but no external notification is sent and payment is not verified. Backend compilation and the Flutter admin release build succeeded; targeted Dart analysis reported no errors, with existing style infos. The updated API process was restarted and its readiness endpoint returned HTTP 200 with PostgreSQL ready. The next finance milestone remains a verified settlement workflow with authorization, duplicate handling, audit and resident receipts/history; this summary does not imply payment capture or reconciliation.

### Reconciled bank transfer settlements and resident receipts (13 November 2026)

Added the additive `estate_invoice_settlements` table and authenticated finance command to reconcile an offline bank transfer only after checking the bank record. It requires an administrator or finance-manager membership, a precise amount, reference, received date and verification note; serializable invoice locking prevents over-allocation, an estate-unique normalized bank reference prevents duplicate recording, and the invoice moves to partially paid or paid with an audit event and stable receipt number. Manager invoice registers show outstanding balances and offer the action only to administrator/finance-manager memberships. Residents can see paid invoices and their verified transfer receipt references; outstanding balances and dashboard currency totals are derived from settlement records. This does not connect a bank feed, verify a transfer automatically, or generate a receipt document. Prisma schema validation, backend compilation, migration deployment and targeted Dart analysis completed; web previews were rebuilt and checked at `/admin/` and `/web/`.

### Local presentation demo environment (13 November 2026)

The configured local PostgreSQL database was empty. Added `npm run seed:demo -- --confirm-local-demo`, which refuses production mode, non-loopback databases and a database that already has users or estates. It uses the production password hashing helper and transactionally creates a clearly named demo estate, manager and resident accounts, six properties, one active occupancy, an active service-charge definition, one published announcement and one community facility. It deliberately seeds no bank destination, invoice, payment or receipt. The command generated one-time random passwords and printed them to the local terminal. Both accounts were then authenticated against the running API; the manager dashboard read one estate, six properties, one occupied property and one resident, and the resident feed returned one announcement. Both release bundles and preview routes return HTTP 200. This verifies the local presentation slice; the broader product contracts and external production integrations remain in progress.

### Estate budgets and expense settlement (16 November 2026)

Added estate-scoped budget versions, category allocations, maker/checker submission and decisions, plus committed/paid/available projections. Approved periods cannot overlap; exact-period revisions preserve the old version and are blocked from superseding it once it has approved expense commitments. Expense requests can reference an approved budget line, and final approval locks the line and checks remaining allocation.

Added manual verified expense payment reconciliation. An administrator or finance manager records the bank reference, received date, amount and verification note after checking the external bank record. The API uses an expense row lock, exact decimal balance calculation, estate-unique normalized bank references, idempotency, partial/paid status transitions and a transactional audit event. The manager UI displays payment totals and stable receipt references. No bank feed, payment initiation, downloadable receipt, refunds or reversals are connected. The additive migrations are deployed, Prisma reports the schema up to date, Nest and Flutter builds succeed, the expense page analyzes cleanly, the API readiness endpoint returns HTTP 200 and `/admin/` serves the refreshed budget/payment bundle.

### In-app notification inbox (16 November 2026)

Added estate-scoped recipient notifications for expense stage review, final decisions, manual settlement, new incident reports and incident status changes. Notifications are inserted inside the source transaction, de-duplicated by estate/recipient/event key, and read only by their intended user while that user retains an active estate membership. Both manager and resident Flutter app bars open the same inbox and provide read state. Delivery remains in-app only; no push, email, SMS, scheduling or preferences integration is connected. The API migration is deployed and the Nest build plus schema validation succeeded; the current local manager/resident bundle refresh and route checks are recorded in `FLUTTER_PREVIEW_RECOVERY.md`.
