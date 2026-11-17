# Zvend Estate — Access, Settings and Reporting Contract

**Status:** Proposed contract; reconcile with Zvend RBAC, audit and reporting conventions before implementation  
**Product baseline:** `Zvend_Estate_Management_Build_Documentation.md`  
**Scope:** Estate staff membership, role/permission assignment, estate operational settings and estate-scoped reports

This contract defines proposed backend behavior for staff access, settings and reporting. It does not assert that Zvend uses any specific RBAC library, database schema, report engine or export store. Reuse the existing identity, authorization, audit, analytics, private file and plan/subscription services after repository inspection.

## 1. Authorization model

### Permission grants

- Resolve the actor from Zvend's authenticated session/token and identify an active estate context from server-validated membership. Never rely on a role, estate ID or permission list sent by the browser.
- Separate platform permissions from estate permissions. Platform support does not silently grant estate finance or resident-detail access.
- A person may have separate roles in multiple estates and multiple roles within one estate. Effective permissions are derived server-side from active grants plus property/gate/work relationships and any explicit deny/suspension policy.
- Use permission capabilities as the authorization unit (for example `property.view`, `resident.review`, `finance.reconcile`, `visitor.verify`, `maintenance.assign`, `facility.manage`, `report.financial.view`). Role names are configurable groupings, not the sole security check.
- Deny by default. Every service operation checks authorization and record relationship; a hidden/disabled UI control is never considered enforcement.
- Prevent privilege escalation: a manager may grant only permissions they are authorized to delegate, cannot grant platform privileges from estate scope, and cannot change their own effective grant unless an explicitly approved process allows it.
- Revocation/suspension takes effect on the next authorization check and invalidates/refreshes any cached grants according to the existing session strategy.

### Membership and staff lifecycle

Staff access uses the existing Zvend user identity. Invitation may target a verified existing account or approved account-creation flow. Membership is estate-scoped and records inviter, invitee, assigned role/grants, status, expiry/acceptance and revocation reason/history. Do not create a duplicate user identity for an estate role.

Suggested states: `invited`, `active`, `suspended`, `revoked`, `expired`. Role/grant changes and status changes append audit events. A suspended/revoked member cannot use ordinary estate operations, while access to their historical audit trail remains available to authorized reviewers.

## 2. Estate settings

Estate settings cover non-secret configuration needed by domain modules: public identity/contact details, estate timezone and presentation preferences, supported currency (subject to Zvend payment support), enabled property types/structure, resident application policy, visitor validity/use policy, maintenance categories/priority rules, facility policy defaults and communication preferences.

- Settings are estate-scoped, permission-checked, validated against available Zvend capabilities and versioned for changes that affect future invoices, bookings, passes or workflow behavior.
- Changing a setting never silently changes issued invoices, active visitor passes, confirmed bookings, prior decisions or other historical records. Existing records preserve the effective setting/policy version used at creation.
- Currency and settlement destination settings must align with the payment contract and any platform restrictions. Do not store payment credentials in the general settings record.
- Store secrets only through an existing dedicated secret/integration service. UI may show configured/not configured and a masked hint; it must not return secret values.
- Record actor, estate, changed setting keys, old/new safe values, effective date and reason where required. Exclude credentials, tokens and unnecessary personal data from audit metadata.
- Estate settings cannot change the estate's platform lifecycle or override platform plan limits. Platform-level and estate-level settings remain distinct.

## 3. Reporting model

- Reports are projections over authoritative domain records, not independently edited totals. Financial metrics reconcile to issued invoices, verified payments, allocations, expenses and reversal/adjustment records under the billing and finance contracts.
- Every report request applies actor permission, estate scope, property/group relationship and date/category filters before search, counts, aggregation or export generation.
- Financial, resident, visitor, incident and access-log reports have separate capabilities; general report access does not imply access to sensitive rows.
- Interpret user-selected date ranges in the configured estate timezone, convert boundaries consistently for UTC storage, and label the range/timezone in results.
- Distinguish unavailable, incomplete, pending-reconciliation and zero-value results. Do not fill missing source data with plausible totals.
- A dashboard summary identifies its as-of time and source freshness. Cached read models must be rebuildable from source records and reconcile within a documented tolerance.
- Exports are server generated from the same authorized query, bounded by date/row limits, private, time-limited and logged. An export link is not a permanent public URL.
- Avoid including unnecessary personal data by default. Apply field-level permission and masking to resident, landlord, payment and visitor fields.

## 4. Proposed permission capability groups

Exact names must follow the current Zvend vocabulary. Capability groups to cover include:

| Domain | Example capabilities |
|---|---|
| Estate structure | `estate.view`, `estate.settings.manage`, `property.view`, `property.manage` |
| People | `resident.view`, `resident.review`, `membership.manage`, `tenancy.view`, `tenancy.manage` |
| Billing/finance | `invoice.view`, `invoice.issue`, `payment.view`, `expense.approve`, `budget.manage`, `finance.reconcile` |
| Gate/security | `visitor.view`, `visitor.verify`, `visitor.override`, `incident.view`, `incident.assign` |
| Operations | `maintenance.view`, `maintenance.assign`, `maintenance.resolve`, `facility.manage`, `booking.approve`, `announcement.publish` |
| Reporting | `report.operational.view`, `report.financial.view`, `report.resident.view`, `report.security.view`, `report.export` |
| Staff/audit | `staff.view`, `staff.invite`, `staff.grant`, `staff.manage`, `audit.view` |

Role templates (administrator, accountant, security personnel, facility manager, maintenance officer, etc.) are defaults that map to capabilities. Estates may configure permitted role groupings if policy allows; never grant a template more privilege than the assigning actor may delegate.

`GET /api/estate/estates/:estateId/permissions/me` returns the authenticated actor's effective estate capability identifiers after active membership, role, relationship and deny-policy resolution. It is a short-lived UI affordance/read model only; it must not issue a reusable authorization token or include platform permissions. Every command and protected read still re-evaluates permission and record scope server-side.

## 5. Proposed API operations

Adapt paths, response envelopes and pagination to Zvend's existing API convention.

| Method and path | Permission | Behavior |
|---|---|---|
| `GET /api/estate/estates/:estateId/members` | `staff.view` | List estate-scoped memberships with safe profile fields and status |
| `POST /api/estate/estates/:estateId/invitations` | `staff.invite` | Invite/link existing Zvend identity and assign only delegable grants |
| `POST /api/estate/estates/:estateId/invitations/:invitationId/accept` | Invitee | Accept their own unexpired invitation and activate membership |
| `POST /api/estate/estates/:estateId/members/:memberId/roles` | `staff.grant` | Assign a role/grant set after delegation and separation-of-duties checks |
| `POST /api/estate/estates/:estateId/members/:memberId/suspend` | `staff.manage` | Suspend membership with reason and audit event |
| `POST /api/estate/estates/:estateId/members/:memberId/revoke` | `staff.manage` | Revoke membership and invalidate access according to auth strategy |
| `GET /api/estate/estates/:estateId/roles` | `staff.view` | List permitted role templates and estate-configured roles |
| `GET /api/estate/estates/:estateId/permissions/me` | Authenticated active member | Return effective actor permissions for UI affordances only; not an authorization token |
| `GET /api/estate/estates/:estateId/settings` | `estate.view` | Return safe, versioned settings available to caller |
| `PATCH /api/estate/estates/:estateId/settings` | `estate.settings.manage` | Validate and version allowed changes; audit changed fields; never accept secrets as ordinary settings |
| `GET /api/estate/reports/dashboard` | Relevant section-specific report/estate capabilities | Return only permitted sections, a timezone-aware bounded period, server as-of time and per-source freshness/availability; financial source amounts use configured exact currency precision |
| `GET /api/estate/reports/:reportType` | Report capability for that data | Return bounded, paginated/filterable report rows or aggregate |
| `POST /api/estate/reports/exports` | `report.export` plus source report permission | Queue an authorized bounded export and audit the request |
| `GET /api/estate/reports/exports/:exportId` | Requester or permitted reviewer | Return status and short-lived authorized download when ready |
| `GET /api/estate/audit-events` | `audit.view` | Estate-scoped, paginated audit events with sensitive metadata removed |

No endpoint accepts a generic `role` or `status` patch without validating capability delegation and allowed state transition.

The dashboard response is a projection over authoritative estate records, never editable totals. The `properties`, `residents`, `tenancies`, `finance`, `visitors` and `maintenance` sections may be omitted independently when the actor lacks the corresponding capability. Each included section reports `available`, `incomplete`, `pending_reconciliation` or `unavailable`; unavailable sections carry no metric values. Return the estate timezone and exact period boundaries, `asOf`, and a source freshness record for every included section. Financial values are non-negative decimal strings at the configured currency scale; compute net operating position with exact minor-unit arithmetic from collected income less paid expenses. If a source is incomplete or unreconciled, preserve that state instead of filling totals with zero or a plausible estimate.

The proposed summary envelope is:

```json
{
  "estateId": "estate-id",
  "asOf": "2026-11-05T12:00:00.000Z",
  "period": {
    "startAt": "2026-10-31T23:00:00.000Z",
    "endAt": "2026-11-30T23:00:00.000Z",
    "timeZone": "Africa/Lagos"
  },
  "sections": {
    "properties": {
      "status": "available",
      "totalProperties": 248,
      "occupiedProperties": 234,
      "vacantProperties": 14
    },
    "finance": {
      "status": "pending_reconciliation",
      "currency": "NGN",
      "currencyScale": 2,
      "rent": { "billed": "22500000.00", "collected": "18420000.00", "outstanding": "4080000.00" },
      "estateFees": { "billed": "0.00", "collected": "0.00", "outstanding": "0.00" },
      "otherCharges": { "billed": "0.00", "collected": "0.00", "outstanding": "0.00" },
      "expensesPaid": "900000.00",
      "netOperatingPosition": "17520000.00"
    }
  },
  "sourceFreshness": {
    "properties": { "status": "current", "sourceAsOf": "2026-11-05T11:59:50.000Z" },
    "finance": { "status": "delayed", "sourceAsOf": "2026-11-05T11:15:00.000Z" }
  }
}
```

Dates above illustrate the response shape only. The report-period adapter must derive the actual month boundaries for the estate timezone and the authenticated request; sample totals are never used as defaults.

## 6. Error handling and privacy

Use Zvend's existing error schema. Relevant outcomes include unauthenticated (`401`), missing/hidden membership or report scope (`403`/`404`), conflicting or expired invitation (`409`), validation/delegation failure (`422`) and rate-limits (`429`). Avoid explaining whether another estate contains a user, report row or membership.

Apply retention and access policy from Zvend/privacy requirements to audit, exported reports and identity attributes. Never return private documents, raw auth/session tokens, payment credentials or unrelated resident contact details in staff/report endpoints.

## 7. UI mapping

| Preview screen | Integrated behavior |
|---|---|
| Team & access | Estate-scoped member/invitation list; server-derived role templates and delegable grants |
| Role assignment | Permission-aware grant command; changes recorded in audit history |
| Settings | Safe current version and validated settings updates; no secret values displayed |
| Reports | Source-backed aggregates and authorized report filters; display as-of time and date range |
| Export report | Server-side bounded job and short-lived private download |
| Hide/disable controls | Usability affordance based on effective permissions; API remains authoritative |

The static preview can illustrate role and report layouts but is not an authorization control, does not represent real figures and does not create downloadable production exports.

## 8. Acceptance evidence and integration gates

Before implementation claims, demonstrate:

1. Same user has different estate grants without cross-estate leakage; revoked/suspended grants stop access promptly.
2. A user cannot elevate their own access or delegate capabilities they do not hold.
3. Estate staff actions cannot grant platform roles; platform support cannot read estate finance/resident data without explicit access.
4. Settings are versioned and changes do not mutate existing invoice, pass, booking or decision snapshots.
5. Report row scope, counts, aggregates and exports use the same authorization filters.
6. Financial reports reconcile to verified billing and finance source records and identify source freshness.
7. Sensitive fields are masked/omitted and exported documents are private and time-limited.
8. Audit events capture role/settings/export changes without storing secrets.

Inspect Zvend's current auth provider, RBAC model, membership lifecycle, audit log, report/read-model strategy, export/file service, time zone/currency conventions, platform plan limits and authorization test patterns before schema changes or code generation.
