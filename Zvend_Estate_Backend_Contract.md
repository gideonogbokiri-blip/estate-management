# Zvend Estate — Phase 1 Backend Contract

**Status:** Proposed contract; requires reconciliation with the Zvend source repository  
**Product baseline:** `Zvend_Estate_Management_Build_Documentation.md`  
**Scope:** Estate applications, activation, estate memberships, authorization context and audit events

This contract turns the first backend phase into reviewable API and data behavior. It does not assert that these routes, tables, or response conventions already exist in Zvend. Confirm the current API prefix, identity model, primary-key format, ORM and error envelope during repository audit before implementation.

## 1. Phase 1 outcome

An authenticated Zvend user can submit an estate application. An authorized platform reviewer can review it, request missing information, reject it with a reason, or approve it. Approval activates an estate and assigns an initial estate administrator. Estate staff then resolve an active estate context from their memberships; estate-owned reads and writes enforce that context server-side. Each privileged status or membership change creates an audit event.

Phase 1 does **not** implement properties, resident access, visitor management, charges or payments. Those depend on the same estate identity and access foundation.

## 2. Actors and authorization

| Actor | Allowed Phase 1 actions |
|---|---|
| Authenticated applicant | Create and edit own draft; submit; view own application and reviewer requests |
| Platform Operations/Review Administrator | View applications within assigned review scope; assign reviewer if permitted; request information; record decision |
| Platform Super Administrator | All platform application decisions; approve/reject; assign initial estate administrator; audit cross-estate access |
| Estate Owner/Administrator | View own active estate, memberships and settings allowed by assigned permissions |
| Other authenticated user | No access to another user's application or an estate they do not belong to |

Use Zvend's existing identity and authorization services. Platform permissions and estate permissions are separate scopes. Do not infer a platform reviewer role from an estate role.

## 3. State transitions

### Application

```text
Draft → Submitted → Under review → Approved
                         ├──────→ More information required → Submitted
                         └──────→ Rejected
```

- Applicant may edit only a Draft or an application returned for more information.
- Submit and decision operations record actor and timestamp.
- A rejected application is terminal for this application record; a new attempt creates a new application with a link to the prior record if Zvend policy allows.
- Requesting information requires a reason/message visible to the applicant.
- Approval requires an eligible existing Zvend user as initial administrator and creates/activates the estate and corresponding membership atomically. The eligibility adapter must return the same user ID requested by the reviewer; a mismatched adapter result is rejected.
- Only an authorized platform actor may move an application into Under review, Approved, More information required or Rejected.

### Estate

The estate lifecycle in the product specification is `Draft`, `Pending`, `Under Review`, `Active`, `Rejected`, `Suspended`, `Deactivated`. The application lifecycle is distinct from the operational estate lifecycle. The provisional backend mapping treats application `draft` as estate `draft`, `submitted` and `more_information_required` as estate `pending`, `under_review` as estate `under_review`, and approval/rejection as estate `active`/`rejected`. Confirm these mapping choices with Zvend's source and product policy. Only Active estates may use normal estate operations; do not accept arbitrary status patches from the client. Suspension, reactivation and deactivation are explicit platform lifecycle commands with reason, policy checks, audit and access invalidation.

## 4. Logical records

Reconcile these with current Zvend user, role, file and audit records before creating tables.

### `estate_applications`

- `id` — existing project key convention
- `applicant_user_id` — reference to existing Zvend user
- `proposed_name`, `estate_type`
- `address`, `state`, `lga`, optional coordinates
- `management_entity_name` and applicant contact fields where not reusable from user profile
- `status`, `submitted_at`, `assigned_reviewer_user_id`
- `decision_reason`, `decided_by_user_id`, `decided_at`
- `created_at`, `updated_at`

### `estate_application_documents`

- `id`, `application_id`, private-storage object reference, document category
- uploader user ID, created time, review status and reviewer metadata where required
- Do not store public file URLs or expose raw storage keys in responses.

### `estates`

- `id`, unique estate code, approved name/type/address and optional map coordinates
- `status`, `approved_application_id`, `approved_at`, `approved_by_user_id`
- configured timezone/currency only when selected according to product policy
- created/updated metadata

### `estate_memberships`

- `id`, `estate_id`, existing `user_id`, membership status, created/updated metadata
- estate-scoped uniqueness for an active user membership according to Zvend schema conventions
- role assignment should use the existing RBAC tables where practical; otherwise use an estate-scoped role relation rather than a global role flag.

### `audit_logs` (reuse existing facility)

Record actor, platform/estate scope, action, target type/ID, outcome, timestamp, reason and safe metadata for submission, review assignment, request-information, approve, reject, suspend/deactivate and administrator assignment. Never include credentials, payment secrets or full sensitive document content.

## 5. API contract

The paths follow the product spec's proposed `/api/estate` prefix. Adapt the prefix, version, response envelope and pagination to the actual Zvend conventions.

### Applicant operations

| Method and path | Permission | Behavior |
|---|---|---|
| `POST /api/estate/applications` | Authenticated user | Create a Draft application for the current actor |
| `GET /api/estate/applications/mine` | Authenticated user | List only applications submitted by the current actor |
| `GET /api/estate/applications/:applicationId` | Applicant or assigned platform reviewer | Read application summary and authorized document metadata |
| `GET /api/estate/applications/:applicationId/documents/:documentAccessId/access` | Applicant or authorized reviewer | Recheck access and redirect to a private-file link expiring within the configured short TTL; audit access |
| `PATCH /api/estate/applications/:applicationId` | Applicant; Draft or More information required only | Update allowed application fields; cannot change reviewer decision fields |
| `POST /api/estate/applications/:applicationId/submit` | Applicant | Validate required fields/documents, transition to Submitted |

The applicant form saves canonical allowlisted draft fields through the create and patch routes. Its host may connect the existing private-file service through `uploadApplicationDocument({ applicationId, file, category, idempotencyKey })`; the browser submits only returned document IDs. The server must derive the actor from authentication and verify each document is uploaded, attached to the locked applicant-owned application, and eligible under server-owned category policy. Category labels shown by the client are guidance only. Do not add a raw file-storage route or accept client-provided verification/category evidence without inspecting the actual source file-service contract.

On approval, the application remains an onboarding record and a separate operational estate record is created in the same transaction as the initial active `estate_administrator` membership and audit events. The estate code must be generated and uniqueness-enforced by the source persistence layer. Approved estate name, type, address and coordinates come from the locked reviewed application; timezone/currency are set only when selected through confirmed product policy. Normal estate operations require the persisted estate to be Active and to match the authenticated actor's authorized context.

### Platform review operations

| Method and path | Permission | Behavior |
|---|---|---|
| `GET /api/estate/platform/applications` | Platform review permission | Paginated/filterable review queue, limited to reviewer scope; return applicant/estate summary and document counts only |
| `POST /api/estate/platform/applications/:applicationId/start-review` | Assigned reviewer or platform review permission | Move a submitted application into review and record reviewer/timestamp |
| `POST /api/estate/platform/applications/:applicationId/assign` | Platform operations permission | Assign an authorized reviewer; audit assignment |
| `POST /api/estate/platform/applications/:applicationId/request-information` | Assigned reviewer or Super Admin | Require message; transition to More information required; notify applicant through existing notification service |
| `POST /api/estate/platform/applications/:applicationId/reject` | Assigned reviewer or Super Admin | Require reason; transition to Rejected; notify applicant |
| `POST /api/estate/platform/applications/:applicationId/approve` | Super Admin or explicitly authorized approver | Require initial administrator identity; atomically create Active estate and Active membership with the mapped `estate_administrator` role; audit both approval and assignment |

### Estate context and membership operations

| Method and path | Permission | Behavior |
|---|---|---|
| `GET /api/estate/estates` | Authenticated user | List estates available through the actor's current active memberships; return only estate ID, name, code and safe location label |
| `GET /api/estate/estates/:estateId` | Active estate member with `estate.view` | Return allowlisted estate identity, location and configured timezone/currency after membership and status checks; exclude applicant contact details |
| `GET /api/estate/estates/:estateId/properties` | Estate member with `property.view` | Return paginated, estate-scoped property summaries with occupancy derived from effective relationships |
| `GET /api/estate/estates/:estateId/properties/:propertyId` | Estate staff with `property.view` or verified property relationship | Return actor-authorized property details and safe ownership/occupancy summary |
| `POST /api/estate/estates/:estateId/properties` | Estate member with `property.manage` | Create a property after validating active same-estate hierarchy parents and estate-scoped code uniqueness |
| `PATCH /api/estate/estates/:estateId/properties/:propertyId` | Estate member with `property.manage` | Lock and update allowlisted property fields/hierarchy; preserve estate, relationship and archive history, then audit atomically |
| `GET /api/estate/estates/:estateId/members` | Estate membership-management permission | List only members of the authorized estate |
| `POST /api/estate/estates/:estateId/members` | Estate membership-management permission | Invite/assign an existing Zvend user with an estate-scoped role |
| `PATCH /api/estate/estates/:estateId/members/:membershipId` | Estate membership-management permission | Change estate-scoped role/status with audit event |

The UI may send an estate selector/context identifier, but the server must verify that the authenticated user belongs to that estate on every request. A Super Admin's cross-estate access must use an explicit platform permission and produce an audit event.

Property `PATCH` accepts a partial object containing only `code`, `propertyType`, `status`, `unitNumber`, `address`, `description`, and optionally `parentIds`. Omitted fields retain their locked current values; explicit `null` clears optional text fields. When provided, `parentIds` replaces the complete hierarchy link set and every ID must resolve to an active node in the selected estate. Status must be one of `active`, `under_development`, `reserved`, `under_maintenance`, or `inactive`; archive and map coordinates use their dedicated commands. The property, current hierarchy links, proposed parent nodes, estate-scoped code uniqueness and audit event must be checked/committed transactionally. Keep a database uniqueness constraint on the estate/property-code key to close races after the availability check.

## 6. Request and response examples

Examples describe domain fields only; wrap them in the existing Zvend response envelope after the audit.

### Submit application

```json
{
  "proposedName": "Greenfield Gardens",
  "estateType": "residential",
  "address": "Lekki-Epe Expressway",
  "state": "Lagos",
  "lga": "Eti-Osa",
  "managementEntityName": "Greenfield Property Services Ltd.",
  "documentIds": ["private-upload-reference-1", "private-upload-reference-2"]
}
```

### Application queue item

```json
{
  "id": "application-id",
  "applicationCode": "ZVE-1048",
  "proposedName": "Greenfield Gardens",
  "estateType": "residential",
  "location": { "state": "Lagos", "lga": "Eti-Osa" },
  "applicant": { "userId": "existing-user-id", "displayName": "Ola Williams" },
  "status": "submitted",
  "submittedAt": "2026-11-04T08:42:00Z",
  "documentSummary": { "count": 3, "pendingReview": 3 }
}
```

### Request missing information

```json
{ "message": "Please upload the signed management appointment letter." }
```

### Approve application

```json
{ "initialAdministratorUserId": "existing-zvend-user-id" }
```

Approval response should return the application decision and created estate identifier/code, not private document URLs.

### Update property

```http
PATCH /api/estate/estates/estate-id/properties/property-id
Content-Type: application/json
```

```json
{
  "code": "OAK-C-014",
  "propertyType": "Apartment",
  "unitNumber": "14",
  "address": "14 Jacaranda Drive, Block C",
  "description": "Two-bedroom apartment",
  "status": "active",
  "parentIds": ["building-c"]
}
```

The response returns the property ID, estate ID and current status. It does not return owner/occupant details or map coordinates through this mutation response; those continue to use their authorized reads.

## 7. Error behavior

Use Zvend's existing error schema after discovery. These domain cases must be distinguishable to the UI without exposing private records:

- `401` unauthenticated
- `403` authenticated but missing platform/estate permission
- `404` record not found or deliberately hidden due to scope
- `409` invalid state transition, duplicate active membership or concurrent decision
- `422` validation failure, including missing decision reason or required application data
- `429` rate limit where applicable

Concurrent approve/reject operations must not both succeed. State transitions and membership creation must be transaction-safe and idempotent where retried.

## 8. UI-to-service mapping

| Preview surface | Service operation when integrated |
|---|---|
| Estate application queue | Platform applications list with status and reviewer filters |
| Review row and document summary | Scoped application detail plus private, short-lived document access operation |
| Request information dialog | `request-information`, required reason, notification and audit event |
| Reject dialog | `reject`, required reason, notification and audit event |
| Approve estate | `approve`, initial admin selection, transactionally create estate/membership and audit |
| Estate selector | Server-authorized memberships; never client-only scope |
| Resident approval button | Resident join-request approval endpoint; membership/audit event |
| Visitor pass view | Estate-scoped pass list; verification/check-in/out handled by backend |
| Invoice status | Read verified invoice/payment allocation state; no client-side payment success mutation |
| Maintenance status control | Authorized transition command with actor, timestamp and request history |

## 9. Integration gates before writing code

The repository audit must confirm:

1. Existing user identifiers and profile/contact fields.
2. Existing platform RBAC and estate/organization scoping patterns.
3. Database, ORM, migration conventions and transaction boundary.
4. Existing upload flow and private document authorization mechanism.
5. Notification dispatch and audit-log service.
6. API prefix, validation, pagination and error response standards.
7. Whether Super Admin approval of the initial administrator is a confirmed business rule or remains configurable.

Do not add replacement auth, roles, storage or notification systems before checking those integrations.
