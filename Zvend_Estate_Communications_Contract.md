# Zvend Estate — Announcements and Communications Contract

**Status:** Proposed contract; reconcile with Zvend notification, identity and storage services before implementation  
**Product baseline:** `Zvend_Estate_Management_Build_Documentation.md`  
**Scope:** Estate announcements, audience targeting, scheduled delivery, channel selection and delivery/read status

## 1. Outcome

Authorized estate staff can draft, target, schedule and publish a community announcement. Residents receive it through existing Zvend notification channels according to estate configuration and user preferences. The system records announcement state and available delivery/read outcomes without creating a second notification delivery platform.

An announcement can target all residents or an estate-scoped group such as a zone, street, property type or role. The server resolves recipients; the client cannot submit an arbitrary list of user IDs or an estate scope it is not authorized to manage.

## 2. Logical records

Reuse the current Zvend notification, user-preference, file and audit facilities where suitable.

### `announcements`

- ID and estate ID
- title, body and optional private attachment references
- priority/type (`normal`, `emergency`)
- audience criteria (all or validated estate-scoped criteria)
- chosen channels (push/email/SMS as supported by Zvend)
- lifecycle state (`draft`, `scheduled`, `sending`, `published`, `cancelled`, `failed`)
- created/updated/published/scheduled timestamps and actor IDs
- sender/display metadata and safe audit context

### Delivery linkage

Store the minimum reference needed to connect an announcement to the existing notification service's delivery job/message IDs and supported aggregate counts. If the existing notification service already stores per-recipient delivery/read receipts, reference those records instead of copying recipient data. Keep any necessary recipient snapshot estate-scoped, access-restricted and retention-limited.

### Audit events

Audit draft creation, audience/channel changes, schedule, publish, cancel, emergency designation and material edits after publication. Published content should be edited through a corrected follow-up announcement or an explicit audited revision; do not silently rewrite the message already sent.

## 3. Authorization and privacy

- Require estate-scoped `announcement.manage` permission for draft, target, schedule, publish, cancel and edit actions.
- Require an explicit `announcement.emergency` permission for emergency alerts; confirm the action and capture the actor on the server.
- Resolve the estate from authenticated membership and validate every target (zone, street, property type or role) against that estate.
- Never accept client-supplied recipient IDs as the authoritative audience.
- Honor user notification preferences, channel availability and applicable consent requirements.
- A resident may read only announcements addressed to their authorized estate/membership context.
- Do not expose recipient lists, private contact details or delivery metadata to unrelated residents.
- Secure attachment access through existing private file permissions and short-lived links.

## 4. Lifecycle and delivery behavior

```text
Draft → Scheduled → Sending → Published
  └──────────────→ Sending → Published
Scheduled → Cancelled
Sending → Failed (retry only through idempotent delivery handling)
```

- Drafts can be changed by authorized staff.
- Scheduling stores an explicit timezone-aware instant; the scheduler dispatches via a background job through the existing notification service.
- Resolve the audience on the server at dispatch time, after rechecking the announcement's estate scope and status. Record an immutable, privacy-restricted audience snapshot/reference sufficient to explain who was eligible at dispatch.
- Scheduled and immediate dispatch must be idempotent. Retried jobs must not create duplicate resident notifications.
- Delivery failures are represented per existing notification service semantics; aggregate counts must distinguish queued, delivered, failed and read where available.
- Do not show a successful send until the notification service accepts the dispatch. A frontend success state is never delivery proof.
- Emergency alerts bypass normal scheduling only through an explicit authorized operation, and use the configured emergency channels.

## 5. API operations

Adapt the exact prefix, response envelope, pagination and event/job conventions after repository inspection.

| Method and path | Permission | Behavior |
|---|---|---|
| `GET /api/estate/announcements` | Estate announcement view | List only announcements available in the actor's estate context, with status/date filters |
| `GET /api/estate/announcements/mine` | Authenticated recipient | List only published notices delivered to the actor through an active estate membership; derive estate and recipient scope server-side |
| `POST /api/estate/announcements` | `announcement.manage` | Create a Draft with validated title, body, audience criteria and channel choices |
| `GET /api/estate/announcements/:announcementId` | Scoped staff or recipient | Return authorized content and only the delivery/read detail allowed for this actor |
| `PATCH /api/estate/announcements/:announcementId` | `announcement.manage`; Draft only | Update draft fields and audience; reject edits to terminal/sending content |
| `POST /api/estate/announcements/:announcementId/schedule` | `announcement.manage` | Require a future timezone-aware send time and enqueue an idempotent job |
| `POST /api/estate/announcements/:announcementId/publish` | `announcement.manage`; emergency permission if needed | Start immediate dispatch through existing notification service |
| `POST /api/estate/announcements/:announcementId/cancel` | `announcement.manage`; Scheduled only | Cancel pending dispatch and audit the actor |
| `POST /api/estate/announcements/:announcementId/read` | Authenticated eligible recipient | Resolve the actor's delivered notification for this announcement and record its read receipt through the existing notification/read-receipt mechanism; repeated calls are idempotent |
| `GET /api/estate/announcements/:announcementId/metrics` | `announcement.metrics.view` | Return estate-scoped aggregate delivery/read metrics, never an unrestricted contact list |

Audience criteria examples:

```json
{ "type": "all_residents" }
```

```json
{ "type": "property_group", "propertyType": "apartment", "zoneId": "authorized-zone-id" }
```

The server must validate each criterion and derive the authorized estate ID from request context.

## 6. Error and concurrency behavior

Use Zvend's established error schema. Distinguish unauthorized scope (`403` or scoped `404`), invalid state transition/concurrent send (`409`), invalid target/channel/time (`422`), and rate limit (`429`) as supported by current conventions. Publish/schedule transitions must be transactional and use a stable idempotency key accepted by the notification/job service.

## 7. UI mapping

| UI control | Backend contract |
|---|---|
| Audience selector | Validated estate-scoped audience criteria; no raw recipient list |
| Channel checkboxes | Existing Zvend channel availability and resident preference rules |
| Emergency toggle | Elevated permission, confirmation, audit and configured alert dispatch |
| Save draft | Draft create/update only; no message sent |
| Publish / schedule | Explicit server transition and idempotent delivery job |
| Published/scheduled list | Estate-scoped announcement query and lifecycle status |
| Read rate | Existing notification service aggregate/read-receipt data |
| Resident updates feed | Authorized announcements for the resident's estate memberships; opening a notice updates the existing per-recipient read receipt |

The current `estate-dashboard` announcement composer only adds local preview rows and does not send or schedule notifications.

## 8. Acceptance evidence

Before calling this module complete, verify that a staff member cannot target another estate's zone/residents; scheduled notifications send once despite retries; cancelled scheduled announcements do not send; opted-out/unavailable channels follow existing rules; residents cannot read another estate's private announcements; and delivery/read metrics reconcile to the existing notification service.
