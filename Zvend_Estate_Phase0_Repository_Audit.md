# Zvend Estate — Phase 0 Repository Audit

**Date:** 4 November 2026  
**Direction update:** The product owner confirmed this is a standalone greenfield estate-management system, not a feature integrated into another Zvend application. The absence of a separate Zvend host repository is not a blocker. Build the product's own identity, authorization, database, API, audit, private-file, payment and notification services here. Historical findings below inventory the original workspace and do not constrain the product architecture; this update supersedes the earlier request to wait for an external source repository.  
**Scope inspected:** Current workspace `LANCON`  
**Status:** Workspace inventory complete; external-host integration audit is not applicable to the standalone product

**Current workspace state:** Since the initial audit, the local dashboard preview has gained ownership-interest create, evidence-review and end-date interactions, and the provisional `backend/modules/properties/` domain/use-case layer has gained ownership create, review and end transitions. The onboarding layer also now has an approved-estate aggregate and transactional estate/initial-administrator commit seam under `backend/modules/estates/`. These are still unconnected scaffolding; they do not establish Zvend's database schema, identity lookup, authorization, document verification, API or audit-service behavior.

## Executive finding

The earlier expectation to connect to an existing Zvend host was incorrect for the product direction. Treat this repository as the product source and build the required application services here. The original workspace inventory remains useful for identifying which backend/API/runtime pieces still need to be created.

This workspace is a product/design handoff, not the Zvend application repository. It contains the product build document, proposed backend contracts, a static dashboard/resident preview, and two Homely-branded property marketplace mockups. It contains no application backend or mobile/web application source. There is no package manifest, database schema or migration history, authentication implementation, RBAC implementation, payment or wallet integration, notification service, private-file storage integration, or deployment configuration to inspect.

The supplied build document explicitly requires auditing those existing integrations before writing application code. Creating a standalone API or database schema in this workspace would invent the interfaces that the estate module is required to reuse. Framework-independent domain rules and injected application-submission, application-approval and estate-context use-case seams have since been scaffolded under `backend/`; they define adapter requirements for authorization, scoped row locking, trusted document checks, transactional state changes and audit writes, but do not claim to be connected application services or an API. The contracts and scaffold remain provisional until checked against the source repository.

## Evidence collected

| Area | Finding |
|---|---|
| Workspace root | Product documents, two JPEG references, and `estate-dashboard/` static preview only |
| Source files | No backend or mobile/web application source tree found |
| Runtime manifests | No `package.json`, `pyproject.toml`, `go.mod`, or `Cargo.toml` found |
| Persistence | No ORM schema, database migrations, or database configuration found |
| Identity and authorization | No authentication, session/token, user, role, permission, or membership implementation found |
| Integrations | No payment, wallet, notification, file-storage, or map-provider implementation found |
| Operations | No CI, deployment, environment template, or application run scripts found |
| Existing UI | `estate-dashboard/` is plain HTML/CSS/JavaScript with sample records and browser-local interactions; its README explicitly says no API or services are connected |

These are findings about this workspace only. They do not establish what exists in another Zvend repository or deployed environment.

## Product and reference-image interpretation

The build document describes a multi-estate operations product: estate onboarding, property and occupancy records, resident/landlord/tenant workflows, charges and rent, visitor/security operations, maintenance, facilities, communications, finance, reporting, and platform subscriptions. It calls for an estate administration web dashboard and estate services inside the existing Zvend mobile app.

The two supplied images show Homely-branded property discovery screens. They include buy/rent/project search, listing detail, map/list exploration, filters, saved properties, agent contact, and profile screens. The images depict Lahore, Pakistan and Lagos, Nigeria. They are marketplace visual references, not estate-management workflow specifications. The build document explicitly says Venco is a functional reference and its private implementation must not be assumed. Therefore, use the images only as broad visual direction (green-led palette, property cards, mobile-friendly layouts) and use the written requirements for product behavior. Do not reproduce Homely branding or add marketplace flows to the estate operations product based on the images alone.

### Public Venco capability reference checked 4 November 2026

Venco's public pages describe useful workflow categories for comparison: facility managers see community activity, receivables, visitors, billing/collections, issues, reports and resident communications; residents use property information, bill payments, visitor booking, issue reporting and amenity scheduling; security workflows cover visitor/resident identification and gate validation. These public descriptions support the written Zvend scope's module groupings, but they do not establish Venco's private data model, integration mechanisms, authorization design or exact UI. They should inform workflow coverage only, not copied branding or implementation assumptions.

- [Venco public overview](https://venco.africa/)
- [Venco facility manager overview](https://www.venco.africa/admin)
- [Venco resident overview](https://www.venco.africa/residents)
- [Venco security overview](https://www.venco.africa/security)

## Confirmed from the supplied specification

- Estate features belong inside the existing Zvend ecosystem; do not rebuild Zvend.
- Use JavaScript if that matches the existing repository; do not introduce TypeScript into a JavaScript codebase.
- Reuse the existing database, ORM, authentication, user identity, RBAC, payment/wallet, notifications and file storage where suitable.
- A modular monolith is the proposed default, subject to the actual backend architecture.
- Every estate-owned query must enforce server-side estate scope and record-level authorization.
- Property mapping is permitted; continuous resident tracking is prohibited.
- The onboarding contract requires an initial administrator assignment to be committed atomically with estate approval.

## Not yet confirmed

- Backend framework and module/plugin conventions (NestJS is only a hypothesis in the build document).
- Database engine, ORM, key types, migration strategy and transaction conventions (PostgreSQL/Prisma are proposed baselines only).
- API prefix/versioning, request validation, pagination, response/error envelope and logging conventions.
- Identity provider, authenticated actor shape, platform roles, estate roles, permission grants and active-estate context.
- Existing audit-log facility and exact audit metadata policy.
- Private document upload/storage and authorization flow.
- Payment/wallet initiation, provider verification, webhook signatures, settlement and idempotency mechanism.
- Notification dispatch and delivery tracking.
- Dashboard and mobile application frameworks, navigation, design system and integration routes.
- Deployment model, environment variable names, CI and available lint/build/test commands.
- Whether Super Admin approval and the initial administrator-selection rule are approved business policy or configurable defaults.

## Integration material already prepared

The following documents provide proposed behavior, not confirmed implementation details:

- `Zvend_Estate_Backend_Contract.md` — application review, estate activation, first administrator membership, access context and audit requirements.
- `Zvend_Estate_Phase2_Contract.md` — property, resident, ownership and tenancy model.
- `Zvend_Estate_Visitor_Security_Contract.md` — visitor credentials, gate access and event history.
- `Zvend_Estate_Billing_Payments_Contract.md` and `Zvend_Estate_Finance_Contract.md` — invoices, payment verification, allocations, budgets and expenses.
- `Zvend_Estate_Communications_Contract.md` and `Zvend_Estate_Operations_Contract.md` — announcements, maintenance, incidents and facilities.
- `Zvend_Estate_Access_Reports_Contract.md`, `Zvend_Estate_Property_Mapping_Contract.md`, and `Zvend_Estate_Platform_Subscriptions_Contract.md` — permissions, reporting, mapping and subscriptions.
- `estate-dashboard/` — disconnected browser preview; all records and actions are local examples.

## Repository material required to proceed with the backend

Provide or open the actual Zvend source repository, including (or pointing to) its backend and relevant mobile/web projects. The audit should then inspect:

1. Backend source tree, manifest, framework version and existing feature-module conventions.
2. User/identity tables and authentication guards/middleware.
3. Existing roles, permissions, tenant/organization scoping and audit service.
4. Database/ORM schema, migration history, key types and transaction usage.
5. Payment/wallet APIs and verified webhook handling.
6. Notification, private file-storage and map integrations.
7. Frontend/mobile frameworks, routing, shared components and API client.
8. Environment templates, CI/deployment setup and project validation commands.

Do not share production secrets. Redacted configuration and schema/source are sufficient for this inspection.

## Proposed implementation sequence after source inspection

1. Reconcile the proposed contracts with the actual identity, persistence, permissions and integration services.
2. Add the smallest onboarding foundation using repository conventions: application lifecycle, authorized review actions, transactionally created estate plus first membership, and audit events.
3. Add estate context and isolation checks, then verify cross-estate denial paths using the repository's test conventions.
4. Build property and people workflows, followed by visitor/security, billing/payments, operations and reporting.
5. Replace the static UI preview with authenticated API-backed screens using the actual frontend and mobile architecture.

The existing dashboard preview remains a design artifact until these integration points are confirmed; it must not be represented as production functionality.
