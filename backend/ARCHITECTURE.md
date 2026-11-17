# Standalone backend architecture

## Decision

Build this product as a standalone modular monolith. The backend owns authentication and account sessions, platform and estate authorization, PostgreSQL persistence, HTTP APIs, audit history, private document access, notifications, and payment orchestration. Feature modules call these shared services through explicit interfaces. No external Zvend application is required.

## Runtime and framework

- Node.js 24 LTS for local development and deployment.
- NestJS for HTTP composition, dependency injection, validation, guards, and feature modules.
- PostgreSQL for transactional estate and operational data.
- Prisma ORM 7 stable for schema and migrations. Avoid adopting Prisma 8 while it is a release candidate.
- Keep the existing framework-independent JavaScript domain planners during the first vertical slice. Add the NestJS/TypeScript service layer around them, then migrate domain modules only when the integration gains type safety without changing business rules.
- Flutter remains the resident, landlord, security, and administration client.

This is a project decision based on the supplied product plan and existing JavaScript domain core. Confirm the exact deployment host and PostgreSQL provider before production rollout; local development must work against ordinary PostgreSQL.

## Security and data boundaries

- Store password hashes using the current scrypt implementation with per-password random salt and constant-time verification; review migration to a maintained Argon2id implementation before public launch. Never write password recovery or token secrets to logs.
- Use short-lived access tokens and opaque, rotated refresh sessions whose stored values are hashed and revocable. Do not implement cryptographic primitives in product code.
- Resolve the actor from the authenticated session. Platform permissions and estate permissions are separate. Scope every estate record by a server-authorized membership and estate context.
- Keep document objects private. Persist only internal object keys; authorize each read and issue short-lived access grants.
- Write audit events in the same database transaction as privileged decisions and membership changes.
- Use an outbox for notifications and payment-provider events. Treat provider callbacks as untrusted until signature and idempotency checks pass.

## First vertical slice

1. Runtime, configuration validation, health endpoint, PostgreSQL connection and first migration.
2. Accounts, sessions, platform roles/permissions, audit log and private file metadata foundations.
3. Estate application draft create/update, submit and applicant-scoped read.
4. Platform review queue/detail, reviewer assignment, request-information, reject and approval. Approval, estate activation, initial administrator membership and audit events commit atomically.
5. Flutter onboarding and platform review clients use the authenticated API; remove preview repositories only after the API workflow is connected and visible.

## Phase progression

After the onboarding and access foundation, add property/people/tenancy, then visitors/security, billing/payments, estate operations, reporting and subscriptions, following the acceptance rules in the product specification. Do not enable a client command before its server permission, state transition, audit and persistence behavior exists.

## Official references

- [NestJS first steps](https://docs.nestjs.com/first-steps)
- [Prisma ORM](https://www.prisma.io/docs/orm)
- [Prisma PostgreSQL support](https://www.prisma.io/docs/orm/v7/core-concepts/supported-databases/postgresql)
- [Node.js release schedule](https://nodejs.org/en/about/previous-releases)
