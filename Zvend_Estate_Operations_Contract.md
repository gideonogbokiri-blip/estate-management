# Zvend Estate — Maintenance and Facility Operations Contract

**Status:** Proposed contract; reconcile with Zvend identity, files, billing and notifications before implementation  
**Product baseline:** `Zvend_Estate_Management_Build_Documentation.md`  
**Scope:** Resident maintenance/complaint requests, staff assignment and resolution, facility availability and bookings

This contract describes the estate-operations slice. It is not a confirmed Zvend API or database schema. Reuse existing Zvend identity, private file storage, payment/invoice, notification and audit facilities where suitable.

## 1. Shared service rules

- Resolve estate scope and actor permissions on the server. Validate the actor's current property/tenancy relationship for resident requests and the estate membership/assigned work scope for staff actions.
- Keep service/use-case rules independent from controllers; validate ownership and state transitions inside the service operation, not only in UI controls.
- Append status and assignment history rather than overwriting it. Record actor, action, timestamp, reason and estate scope for privileged transitions.
- Store uploads using Zvend's existing private-file workflow. Authorize every read/download and never expose permanent public URLs or storage keys.
- Notifications are emitted through the existing service after successful state changes. Make delivery retryable/idempotent without rolling back the committed request/booking.
- Keep internal staff notes separate from resident-visible updates; never leak internal notes in resident APIs, notification previews, or exported records.

## 2. Maintenance and complaints

### Record and visibility

A request links to one estate and property and contains requester identity, category, description, priority, optional preferred contact/time and private attachment references. The requester may be an authorized resident/landlord/occupant under estate policy. Staff and contractor visibility is limited to assigned estate/work scope and necessary property details.

Each request has a stable reference, created/submitted timestamps, status, assigned staff/contractor, target date, resident-visible updates, internal notes, and (when authorized) estimated/actual cost and materials. Cost records should link to the finance/expense service; a maintenance request must not create a paid expense by itself.

### Lifecycle

```text
Submitted → Under review → Assigned → In progress → Resolved → Closed
                 ├───────────────→ Rejected (reason required)
                 └── Awaiting parts/approval ↔ In progress
Resolved → Reopened (resident confirmation or authorized staff action, policy-bound)
```

- Only server-authorized commands can change state; clients cannot patch arbitrary status, assignee, cost, or reviewer fields.
- Every transition validates allowed prior state, actor capability, assignment and required data. Reject/close requires a reason or resolution summary according to policy.
- Request creation requires a scoped idempotency key. Persist its key hash, normalized payload hash and safe result atomically with the request, audit event and outbox notice. Reusing the key with different request details must fail; concurrent claims must serialize under a unique `(actorUserId, estateId, idempotencyKeyHash)` constraint.
- Record assignment changes and due-date/priority changes in history.
- Residents see only public updates and their own authorized requests. Internal notes are returned only to roles with the relevant permission.
- Let residents comment or confirm/reopen resolution only while policy and current state allow it.
- Urgent/emergency categories may require a separate contact instruction and fast notification path; submission must not be presented as emergency dispatch unless a real service exists.

### Proposed operations

| Method and path | Permission | Behavior |
|---|---|---|
| `POST /api/estate/maintenance/requests` | Authorized property resident/occupant | Require a scoped `Idempotency-Key`; create and submit a request with validated category, description, priority and private attachments, returning the original result for an exact retry |
| `GET /api/estate/maintenance/requests/mine` | Authenticated resident | Paginated list of requests visible through the actor's active estate/property relationship, including resident-visible updates only; internal notes are excluded |
| `GET /api/landlord/properties/maintenance` | Landlord with property-maintenance view permission | Paginated requests for the actor's currently active, verified property ownership links. Scope properties before filtering/counting/pagination, recheck ownership on each read, return resident-visible updates only, and exclude requester contact details, internal notes, private attachment references and storage locations. |
| `GET /api/landlord/properties/maintenance` | Landlord with property-maintenance view permission | Paginated requests for the actor's currently active, verified property ownership links. Scope properties before filtering/counting/pagination, recheck ownership on each read, return resident-visible updates only, and exclude requester contact details, internal notes, private attachment references and storage locations. |
| `GET /api/estate/maintenance/requests` | Estate maintenance view | Paginated assigned/estate queue with bounded status-set, priority, property and date filters; scope before filtering/counting/pagination. Return totals and page metadata for that filtered result, and allowlist the summary fields and actor-allowed commands. Bind every projected property/status/category/priority/assignee to the scoped request record; include resident-visible updates only, never internal notes. |
| `GET /api/estate/maintenance/requests/:requestId` | Requester or scoped staff | Return role-filtered request detail and visible history; a resident lookup must be constrained to the authenticated actor's current estate/property relationship and exclude internal notes/private attachment references |
| `POST /api/estate/maintenance/requests/:requestId/review` | Scoped maintenance staff | Atomically apply a permitted transition, assignment and/or resident-visible update; internal notes require separate permission |
| `POST /api/estate/maintenance/requests/:requestId/assign` | Work assignment permission | Assign an estate staff member/approved contractor and record history |
| `POST /api/estate/maintenance/requests/:requestId/updates` | Requester or authorized staff | Append resident-visible update or separately stored internal note |
| `POST /api/estate/maintenance/requests/:requestId/transition` | Role/state-qualified actor | Apply one explicitly allowed transition with required reason/resolution data |
| `POST /api/estate/maintenance/requests/:requestId/costs` | Finance/maintenance cost permission | Link estimate/materials/actual cost to authorized finance records; no implied payment |

## 3. Facilities and bookings

### Facility configuration and availability

A facility belongs to one estate and has a type/name/location, active/bookable state, opening hours, capacity, booking slot/duration rules, lead time, blackout periods, eligible resident groups, guest limits, cancellation rules, fee/deposit policy and approval mode. Configuration revisions preserve the policy used by existing bookings.

Availability is computed by the backend from the effective facility policy, confirmed/pending booking holds, capacity/resource rules, blackout periods and current estate time zone. A client calendar or list of suggested slots is advisory only.

Resident reads return only facilities the authenticated estate member may use. `GET /api/estate/facilities` returns `{ estateId, items }`; each safe facility summary exposes facility ID, display name, safe location/description, capacity, booking duration/window rules, current policy version and fee terms. `GET /api/estate/facilities/:facilityId/availability?date=YYYY-MM-DD` uses the estate timezone and returns `{ estateId, facilityId, date, timezone, policyVersion, asOf, items }`. Each slot exposes only `startsAt`, `endsAt`, `remainingCapacity`, `policyVersion` and fee terms; it contains no other resident's booking identity, purpose or booking ID. The UI must display the fee/booking policy and record acceptance of the exact policy version when submitting.

### Booking request and conflict prevention

A booking records estate/facility, authorized requester/property, start/end time, attendee/guest count, purpose where required, status, fee/deposit invoice reference, acceptance of the policy version, and history. Enforce facility scope, opening hours, lead time, duration, attendee capacity, blackout rules, user/estate booking limits and fee eligibility server-side.

- Recheck availability at the moment of request and again at confirmation. Use a transaction and database-level constraint/locking strategy so concurrent requests cannot both reserve the same exclusive time/resource.
- If an estate uses manual approval, pending bookings may either reserve a short configurable hold or remain non-blocking; document this policy and expire holds explicitly. Do not let stale pending requests block a space indefinitely.
- Confirmed bookings cannot overlap on an exclusive facility/resource. Capacity-based facilities may accept concurrent bookings only within configured capacity and staffing/resource rules.
- A confirmation must capture the facility-policy version and fee terms presented to the resident.
- If a fee/deposit applies, create/link an invoice through the billing service. Booking approval alone does not mark it paid; payment/refund status comes from verified Zvend records.
- Cancellation/refund follows the captured policy, current status and payment provider capabilities. Preserve the original booking and record cancellation/refund events.
- Record actual usage/check-in only if the estate enables it. Do not infer attendance solely from elapsed time.

### Booking lifecycle

```text
Requested → Pending review → Confirmed → Completed
                ├→ Declined (reason)
                └→ Expired (hold/policy timeout)
Requested/Pending/Confirmed → Cancelled (policy and state dependent)
Confirmed → Rescheduled through linked change/cancel-and-rebook history
```

### Proposed operations

| Method and path | Permission | Behavior |
|---|---|---|
| `GET /api/estate/facilities` | Authorized estate member | List facilities and policy-safe details in active estate scope |
| `GET /api/estate/facilities/:facilityId/availability` | Authorized resident/staff | Return server-calculated slots for bounded date range and group scope |
| `POST /api/estate/facilities` | Facility management | Create draft facility and booking policy |
| `POST /api/estate/facilities/:facilityId/versions` | Facility management/approval | Revise operating hours, capacity, fees or rules without changing existing bookings |
| `POST /api/estate/facilities/:facilityId/bookings` | Eligible resident | Require `Idempotency-Key`; recheck availability and policy transactionally, create request/hold, link any fee invoice, append audit/outbox records, and return current status |
| `GET /api/estate/facility-bookings/mine` | Authenticated resident | List actor-authorized bookings and allowed history |
| `GET /api/estate/facility-bookings` | Booking manager | Estate-scoped paginated review and calendar source |
| `POST /api/estate/facility-bookings/:bookingId/confirm` | Booking approval permission or policy service | Recheck conflict/capacity and payment/approval policy; confirm atomically |
| `POST /api/estate/facility-bookings/:bookingId/decline` | Booking approval permission | Require reason, release hold and notify requester |
| `POST /api/estate/facility-bookings/:bookingId/cancel` | Requester or staff per policy | Apply cancellation terms and create linked refund request if eligible |
| `POST /api/estate/facility-bookings/:bookingId/usage` | Facility staff/check-in permission | Append usage/check-in event when enabled |

The booking request body contains `startsAt`, `endsAt`, `attendeeCount`, optional `purpose` and `acceptedPolicyVersion` matching the version returned by facility/availability reads; the actor and any property relationship come from authenticated estate context. Return the stable booking reference, current status, times, attendee count and invoice reference/fee summary where applicable. `GET /api/estate/facility-bookings/mine` returns only the authenticated resident's safe booking summaries, including facility timezone for date display. A retry with the same actor/estate key and normalized payload returns the same safe result; reuse with changed details conflicts.

## 4. Errors, privacy and reliability

Align error shape with Zvend conventions. Return distinct validation (`422`), unauthorized/hidden scope (`403`/`404`), invalid transition or booking conflict (`409`) and rate-limit (`429`) outcomes without exposing other residents' requests or booking details.

- Apply authorization before filtering, counting and exporting.
- Bound list date ranges, pagination and attachment sizes/types.
- Make create/submit/transition commands safe to retry with idempotency where clients or jobs may retry. Booking creation scopes the key to actor and estate, binds it to the normalized facility/time/attendee/policy payload, and atomically records the booking result with invoice linkage, audit and notification outbox writes.
- Use database transactions for assignment/status history, facility confirmation and any linked invoice creation. If cross-service atomicity is unavailable, use an outbox/saga pattern consistent with the existing architecture and expose pending state honestly.
- Preserve history on reopen, reschedule, decline, cancellation and refund.
- Keep resident-facing exports and notifications free of internal notes, other properties' details and private contact information.

## 5. UI mapping

| Preview surface | Integrated service behavior |
|---|---|
| Resident request form | Submit scoped request and private files; return stable reference and status |
| Resident request timeline | Return requester-visible state history and public updates only |
| Staff maintenance queue | Estate/assignment-scoped filtering, assignment and explicit transitions |
| Facility list and slot picker | Read server-calculated availability and the effective facility policy |
| Booking request form | Recheck slot/capacity and policy server-side; show pending/confirmed/declined state |
| Staff booking review | Confirm/decline command; transactional conflict recheck and auditable reason |
| Facility charge | Invoice through billing service; show payment only from verified transaction state |

The current static preview must not be treated as a reservation, emergency dispatch, work assignment, private file service or payment record.

## 6. Acceptance evidence and integration gates

Before production claims, demonstrate:

1. Cross-estate and property relationship isolation for requests, assignments, attachments and bookings.
2. Resident responses never include internal staff notes or another household's data.
3. Invalid maintenance transitions are rejected and all accepted transitions appear in history.
4. Simultaneous requests for an exclusive time slot cannot both become confirmed; capacity-based bookings cannot exceed limits.
5. Stale approval holds expire according to policy and stop blocking availability.
6. Booking fees create invoices through the billing contract and never mark payment successful from booking approval.
7. Cancellation, refund, reschedule, reopen and notification failures preserve authoritative history and can be retried safely.

Confirm existing Zvend file access, notification queue, identity/property scope, role permissions, date/time-zone policy, payment/refund interface, audit service, deployment/database transaction conventions and contractor access policy before migrations or controller implementation.

`backend/modules/operations/decide-facility-booking.js` composes the booking domain planner with the transactional review boundary. Its host adapters must authorize `booking.approve`, lock the same-estate booking and facility, reload facility policy and conflict/capacity data for confirmations, verify a linked fee invoice using billing's authoritative paid projection, commit the status/history/hold release atomically, append audit events and enqueue a requester notice through the outbox. Declines require a reason. The availability adapter must serialize overlapping confirmation decisions at the facility/resource and time scope so two concurrent confirmations cannot both pass against the same stale conflict set. A confirmation never marks an invoice paid.

`backend/modules/operations/cancel-facility-booking.js` is the transactional cancellation seam. Its locked booking lookup must include the authorized estate; the access adapter may permit the authenticated requester under current relationship rules or staff with the specific cancellation permission. Load the immutable cancellation terms captured by the booking's policy version. The billing adapter must calculate any refund eligibility/amount only from verified allocations and provider policy; cancellation itself never reverses a payment. The domain checks that a planned refund matches the booking, estate, linked invoice, captured currency and precision, and does not exceed the captured fee. Commit booking cancellation, any pending Billing refund request, audit and retryable notices atomically; provider refund execution belongs to Billing's outbox/workflow. Keep the original invoice/payment/allocation records unchanged.
