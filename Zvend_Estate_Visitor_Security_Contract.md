# Zvend Estate — Visitor Access and Security Contract

**Status:** Proposed contract; reconcile with the Zvend source repository before implementation  
**Product baseline:** `Zvend_Estate_Management_Build_Documentation.md`  
**Scope:** Visitor invitations, gate verification, access events and incident follow-up

This contract defines the Phase 3 backend behavior for visitor access and estate security. It is a design proposal, not a confirmed Zvend API, schema or security-staff login implementation. Reuse Zvend identity, authorization, notification, file storage and audit services after inspecting them.

## 1. Domain boundaries

- A visitor invitation is a revocable, time-bounded credential associated with one estate, host, property and visitor visit.
- Verification credentials contain no visitor name, phone, property or other personal data. Store only a hash of a sufficiently random token/PIN where practical; return the clear credential once to the authorized host.
- Gate staff receive only the minimum fields needed to confirm a valid visit. They cannot search the resident directory or browse unrelated properties.
- Access events are append-only facts. Check-in, check-out and exceptional manual admission create events; they do not rewrite or delete earlier events.
- Incident reports are a separate workflow from pass verification and must have their own access policy, status history and private attachment handling.

## 2. Actors and scope

| Actor | Allowed operations |
|---|---|
| Resident/landlord host | Create a pass for a property they may use; list/revoke their authorized passes; view access history permitted by estate policy |
| Estate administrator | View estate-scoped passes, access events and incidents; manage gates and authorized staff; investigate incidents |
| Gate/security staff | Verify a credential and record entry/exit only for assigned estate/gates; see minimal visit details; report incidents |
| Incident assignee | View and update incidents assigned to them within estate scope |
| Platform support | Explicit, audited support access only; no default access to visitor details |

Resolve the actor and active estate/gate assignment server-side on every request. A supplied estate, property or gate ID is only a requested context, never proof of access.

## 3. Invitation lifecycle

```text
Created → Active → Checked in → Checked out
             ├── Expired (derived from validity window)
             ├── Revoked
             └── Exhausted (single/multi-use policy reached)
```

- Creation validates that the host is authorized for the property, the property belongs to the active estate, and the validity window is allowed by estate policy.
- Pass creation accepts a random `Idempotency-Key` scoped to actor and estate. The create transaction claims the key, creates the pass, appends audit, enqueues the credential-free host notice and completes the key atomically. A retry cannot create a second pass. The clear credential is returned only from the initial committed command and is never stored in the idempotency record; a completed retry returns a conflict directing the host to inspect the pass list and revoke/reissue if the credential was not received.
- The issuer chooses a single-use or policy-approved multi-use limit. Do not allow arbitrary unlimited uses by default.
- Revocation takes effect immediately for future checks; it cannot erase prior verification or access events.
- The verifier evaluates status, estate, gate assignment, property, `validFrom`, `validUntil`, use limit, revocation, and current check-in state atomically.
- Concurrent checks must not consume a single-use pass twice. Verification and entry recording need a transaction/locking strategy appropriate to the existing database.
- Check-in accepts a random `Idempotency-Key` header. Store a hash unique to `(actor, estate, gate, key)` and bind the record to the credential hash. A retry with the same credential returns the original committed response; reuse with another credential conflicts. Claim, pass-use consumption, visit creation, access event, audit and completion of the idempotency record commit or roll back together. A uniqueness constraint and conflict-safe claim operation must serialize concurrent requests even when they use different passes.
- Keep only the minimum successful response needed for retry, with an expiry that follows the configured retry window and visitor-data retention policy. Never store the clear key or credential, and redact the header/body from request logs.
- Rate-limit invalid PIN/token attempts by gate/device and credential fingerprint. Return generic failure messages that do not enable credential enumeration.
- A manual/emergency admission requires an explicit reason, staff identity, gate, time and audit event. It must not silently create a normal pass.
- A manual admission also creates a passless checked-in visit with `admissionType: manual`; it appears in the assigned gate's current-visitor list and can be checked out through the normal visit command. It requires the `visitor.override` capability and an enabled estate policy.
- Check-out is attributable to a gate staff action or an explicitly defined estate reconciliation process. Repeated check-out requests are idempotent or return a clear conflict without duplicating the event.

## 4. Logical records

These are domain concepts, not migration names. Match the existing ORM, key and audit conventions before persistence work.

### Visitor invitation

- ID and estate ID; property ID; host user/membership ID; visitor display name and minimum contact fields required by policy.
- Credential hash/fingerprint, credential type, validity window, allowed uses, use count and status/revocation metadata.
- Optional vehicle details only when the estate enables collection and the host supplies them.
- Created/updated timestamps and actor; do not store unneeded identity documents or sensitive data in QR payloads.

### Gate assignment

- Estate ID, gate ID, existing staff/membership identity, active assignment window and permissions.
- Gate assignments do not grant general estate-administration access.

### Check-in idempotency record

- Actor, estate and gate scope; one-way idempotency-key hash; one-way credential hash; state; minimal committed check-in response; creation and expiry timestamps.
- Enforce uniqueness across actor, estate, gate and key hash. Only completed records are visible to replay; an uncommitted claim is part of the check-in transaction and must roll back if any visit/access/audit write fails.
- The replay query rechecks current gate assignment and requires the same credential hash. A key does not grant access to a visit by itself.

### Manual-admission idempotency record

- Actor, estate and gate scope; one-way idempotency-key hash; keyed digest of the normalized visitor name, property reference and reason; state; minimal committed visit summary; creation and expiry timestamps.
- Enforce uniqueness across actor, estate, gate and key hash. Claim, passless visit creation, access event, audit event and completion commit in the same transaction. A retry with the same payload returns the stored summary; reuse with changed details conflicts. Never persist the clear idempotency key.

### Visitor-pass creation idempotency record

- Actor and estate scope; one-way idempotency-key hash; keyed digest of property, visitor name, validity window and vehicle summary; state; created pass ID; creation and expiry timestamps.
- Enforce uniqueness across actor, estate and key hash. Claim, pass creation, audit event, credential-free outbox notice and completion commit in one transaction. Store no credential or credential hash in this record. The initial command returns the credential once; a completed retry returns a conflict and never returns or regenerates the credential.

### Visitor visit

- Estate, property, gate, checked-in/check-out status and timestamps, with the staff actor for each transition.
- A pass-backed visit references its visitor invitation. A manual visit has `passId: null`, `admissionType: manual`, and a bounded visitor display name; its property and gate are still resolved and validated server-side.
- Current-gate queries include both forms. Manual entries expose no host or vehicle details, and check-out appends an exit event with a null invitation reference.

### Access event

- ID, estate, invitation (nullable for a denied unknown credential or documented manual admission), property, gate and staff IDs.
- Event kind (`verified`, `entry`, `exit`, `denied`, `manual_admission`), timestamp, outcome/reason code and safe metadata.
- Append-only semantics. Avoid copying full visitor contact data into logs; use authorized joins when an investigation requires details.

### Security incident

- ID, estate, category, location/property when applicable, observed time, description, reporter, priority and status.
- Assignee, resolution details and timestamps; private attachment references; separate append-only status/comment history.
- Do not include credentials or unnecessary personal details in notification payloads or audit metadata.

## 5. Proposed API operations

Adapt paths, verbs, pagination and response envelopes to the existing Zvend conventions.

| Method and path | Permission | Behavior |
|---|---|---|
| `POST /api/estate/estates/:estateId/visitor-passes` | Authorized property host | Create pass; validate property relationship and policy; require scoped `Idempotency-Key`; return credential once |
| `GET /api/estate/estates/:estateId/visitor-passes/mine` | Authorized host | List only passes the actor may view, with status and limited visitor summary |
| `POST /api/estate/estates/:estateId/visitor-passes/:passId/revoke` | Host or permitted estate staff | Revoke future use and audit actor/reason |
| `POST /api/estate/security/gates/:gateId/check-in` | Assigned gate staff | Validate credential, consume one use, create the checked-in visit, append entry event and audit atomically; rate-limit attempts |
| `POST /api/estate/security/visits/:visitId/check-out` | Assigned gate staff | Lock and close the active visit, then append its exit event and audit record atomically |
| `POST /api/estate/security/gates/:gateId/manual-admissions` | Assigned gate staff with `visitor.override` and enabled estate policy | Resolve an estate property reference, require visitor name and reason, then atomically create a passless checked-in visit and audited manual-admission event; accept a scoped `Idempotency-Key` |
| `GET /api/estate/security/gates/:gateId/visitors/current` | Staff assigned to gate | List currently checked-in visitors with minimum operational details |
| `GET /api/estate/estates/:estateId/access-events` | Estate security/audit permission | Filtered, paginated event history; gate staff see only assigned scope |
| `POST /api/estate/estates/:estateId/incidents` | Estate member or assigned security staff per policy | Report incident; private attachment references; audit creation |
| `GET /api/estate/estates/:estateId/incidents/mine` | Authenticated reporter | List only incidents reported by the actor within this estate |
| `GET /api/estate/estates/:estateId/incidents` | Estate incident-view permission | Filter by status/category/date/assignee inside estate scope |
| `POST /api/estate/estates/:estateId/incidents/:incidentId/updates` | Incident assignee or manager | Append status/comment update; preserve history |
| `POST /api/estate/estates/:estateId/incidents/:incidentId/assign` | Incident assignment permission | Assign staff within the same estate and audit change |

The estate incident queue summary includes incident ID, estate ID, category, priority, status, created/observed timestamps, safe location description, authorized reporter display name and gate label where applicable. The server checks priority and status against the source incident record. Keep incident description, private attachment references and sensitive investigation details behind the authorized detail/read service; they are not part of the queue projection.

Avoid generic status patch endpoints. Each command must validate the state transition and scope in the service layer.

The resident pass list is a strict summary projection: pass ID, estate/property references, visitor display name, validity window, use counts, revocation timestamp, optional vehicle summary and derived status. Scope the query by the authenticated host and estate before applying the 100-record bound; reject repository results outside that scope. Never include the credential or its hash in list/detail responses. A response envelope may wrap the list as `{ "data": { "items": [...] } }` if that matches the host API convention.

## 6. Verification response and errors

A successful check-in returns only what gate operations need, after the visit and entry event commit:

```json
{
  "visitId": "visit-id",
  "estateId": "estate-id",
  "gateId": "gate-id",
  "status": "checked_in",
  "visitorName": "Kelechi Madu",
  "propertyLabel": "Oakwood - 01",
  "hostDisplayName": "Amara Okafor",
  "vehicleSummary": null,
  "checkedInAt": "2026-11-04T12:10:00Z",
  "validUntil": "2026-11-04T13:00:00Z"
}
```

The check-in response must not include resident phone numbers, credentials, pass hashes, unrelated household members or internal storage keys. Do not provide a separate credential-existence response that can be used to enumerate passes. Invalid, revoked, expired, exhausted and wrong-estate credentials return the same generic failure; rate limiting may return `429`. Gate authorization failures remain distinct (`403`). Use an `Idempotency-Key` header to safely replay the original committed response after a network retry; scope its hash by actor, estate and gate, bind it to the credential hash, and persist it atomically with the visit. Reusing a key with a different credential is a conflict. The route takes the requested gate from the path, the estate context from the authenticated host context, the actor from the session, the credential from the request body and the idempotency key from the header.

## 7. Audit, privacy and retention

- Audit issuance, revocation, overrides, denied verification where policy requires, entry, exit, incident assignment and resolution.
- Record actor, estate/gate scope, target, outcome, timestamp and reason where applicable.
- Enforce configurable retention for visitor contact details and access logs according to product policy and applicable law; do not infer indefinite retention.
- Keep audit/access events tamper-resistant using the existing platform facility and database controls; restrict read access separately from write access.
- Protect credentials in transit and at rest, use short validity windows, prevent replay, and keep them out of analytics, URLs, server/client request logs and notifications.
- Do not use continuous GPS or resident location tracking. Property coordinates are for mapping only.

## 8. UI-to-service mapping

| Preview control | Integrated operation |
|---|---|
| Create visitor pass | Create pass for an authorized host/property; deliver credential via existing notification/share mechanism |
| Gate verification entry | Scan or enter credential; the server verifies and records entry in one atomic operation, then returns the minimum committed visit summary |
| Record exit | Check-out command and append-only event |
| Manual admission | Explicit override command requiring reason and permission |
| Current visitors | Gate-scoped current-visitor query |
| Incident report/update | Incident create/update/assignment operations with private files and history |
| Visitor and incident history | Estate/gate-scoped paginated reads, with role-specific fields |

The manual-admission request contains only `visitorDisplayName`, `propertyReference`, and `reason`; the server derives actor and estate context, resolves the property within the estate, and returns the same safe visit summary shape as check-in with `hostDisplayName: Manual admission` and `vehicleSummary: null`. The current-visitor query includes these passless visits, and check-out accepts their visit ID.

Every action in the static preview remains local and illustrative until connected to these services.

`backend/modules/visitors/create-visitor-pass.js` is the provisional transactional creation seam. Its adapters must resolve the authenticated host's active property access and server-owned estate policy, lock the same-estate property, create a cryptographically random single-use credential while persisting only its hash, and commit the pass, audit event, credential-free outbox notice and actor/estate/payload-bound idempotency completion together. Return the plaintext credential only to the initial authorized command response through the approved delivery/share path; never include it in list projections, logs, analytics, notification payloads or idempotent replay responses. The Flutter local draft form does not call this seam or create an active credential.

## 9. Integration gates

Before implementation, inspect and confirm:

1. Existing Zvend staff authentication and permission/membership model.
2. QR/PIN generation facilities, secure randomness and rate-limit infrastructure.
3. Estate/property relationship and resident/host authorization data.
4. Transaction/locking and idempotency conventions for single-use credential consumption.
5. Existing audit/event log, notification, file upload and private-file access services.
6. Gate/device assignment and offline/emergency operating policy.
7. Visitor and security-record retention policy and incident visibility rules.
