# Zvend Estate — Billing, Rent and Payment Contract

**Status:** Proposed contract; confirm against Zvend's existing ledger and payment APIs before implementation  
**Product baseline:** `Zvend_Estate_Management_Build_Documentation.md`  
**Scope:** Estate charge configuration, rent schedules, invoices, payment initiation, verified settlement, receipts and reconciliation

This contract defines the Phase 4 service boundary. It does not propose a new wallet, payment gateway or accounting ledger. Reuse the existing Zvend payment, wallet, transaction, notification and receipt services where their capabilities fit. Route paths and record concepts below are provisional until the source repository audit.

## 1. Financial ownership and invariants

- Estate fees, landlord rent and Zvend subscription charges are distinct financial products with separate payers, payees, settlement destinations and reports.
- A rent invoice must identify the authorized settlement model: landlord-designated destination, estate collection on behalf of a landlord, or another explicitly configured arrangement. Never infer that rent belongs to the estate.
- An issued invoice is a dated demand with a snapshot of its payer, property/tenancy, line descriptions, amounts, currency, due date and destination policy. Editing a charge definition or tenancy later does not rewrite issued invoices.
- Payment initiation is not payment. A browser redirect, user assertion or unverified provider callback cannot mark an invoice paid.
- A successful payment is confirmed only by the existing trusted Zvend payment service or an authenticated/reconciled settlement source. Validate reference, amount, currency, destination, status and invoice eligibility.
- Apply verified payments to invoice balances transactionally. Preserve provider transactions and invoice allocations as separate records so one payment can be allocated across permitted lines/invoices and a partially paid invoice can receive further payments.
- Posted invoices, verified payments, allocations, receipts and refunds are never silently edited or deleted. Correct them through credit notes, allocation reversals, refunds or adjustments with audit history.
- Use fixed-precision monetary values and explicit currency. Match Zvend's established precision and rounding behavior; do not use binary floating point for authoritative amounts.

## 2. Actors and authorization

| Actor | Permitted view/action, subject to configured permissions |
|---|---|
| Tenant/resident | View invoices and receipts linked to their active or historical authorized property/tenancy; initiate payment for eligible balance |
| Landlord/property owner | View rent and property charges for authorized properties; initiate or review payment where policy allows |
| Estate finance staff | Configure estate charges and rent collection policy; issue invoices; view collections and reconcile according to assigned permissions |
| Estate accountant/authorized collector | Record approved offline settlement evidence or reconcile external transaction only if policy grants it |
| Platform finance/support | Access platform-level subscription/settlement records in explicit platform scope; estate financial access must be separately granted and audited |

Apply estate and relationship scoping before searching, counting, aggregating or calculating balances. The payer, landlord, property owner and estate staff see only the fields allowed by their relationship and permission. The client never chooses a trusted destination by submitting arbitrary account details.

## 3. Charge configuration and rent schedules

### Charge definition

An estate-scoped charge definition includes name, description, category, fixed-precision amount, currency, one-time/recurring behavior, effective period, recurrence, due/grace rules, applicable estate/property/property-type/party scope, late-fee policy if enabled, approval policy and active status. Preserve revisions and effective dates. Fee changes apply only to future invoice generation unless an explicit adjustment workflow is used.

Configuration must prevent accidental duplicate generation for the same estate, charge, billing period, payer/property and schedule. Draft previews may be recalculated; issued invoices may not.

### Rent schedule

Rent terms originate from an approved tenancy: amount/currency, frequency, period boundaries, due date, partial-payment policy, deposit/other separately identified charges and a versioned settlement destination arrangement. A renewal creates a linked schedule/version; it does not overwrite prior rent history. The landlord and tenant receive access according to the tenancy and estate relationship policy.

### Invoice snapshot

An invoice stores estate ID, unique estate-scoped invoice number, payer, optional property and tenancy, category, issue/due dates, currency, immutable line-item snapshots, subtotal, configured fees/adjustments, total, balance derived from verified allocations and lifecycle timestamps. Invoice downloads and receipts use private authorized storage or generated, access-controlled documents.

## 4. Invoice, payment and receipt lifecycle

```text
Invoice: Draft → Issued → Partially paid → Paid
                    ├── Overdue (derived when due date passes with balance)
                    ├── Disputed (dispute flag/history; balance is retained)
                    └── Cancelled (authorized pre-settlement or via correction policy)

Payment attempt: Created → Pending → Succeeded | Failed | Expired
                                      └→ Reversed / Refunded (trusted event)
```

- `Overdue` is derived from due date and outstanding balance; do not independently mutate it in a way that can contradict payment allocation.
- A partial payment leaves a positive invoice balance and yields `Partially paid`; a fully allocated verified payment yields `Paid` only after the transactional balance calculation.
- A dispute does not erase or alter the invoice balance. Record dispute details and resolution separately.
- Do not cancel or rewrite an invoice with settled value. Use credit note/reissue or authorized reversal/refund flows, retaining links to the original invoice/payment.
- Generate a receipt only for a confirmed payment or explicitly reconciled offline receipt. Receipt records reference the trusted transaction and allocation; they are not created from payment initiation.
- A provider event may arrive late, more than once or out of order. Store its provider event identity and processing outcome, and make state application idempotent. A later verified reversal/refund updates current balances through compensating entries without erasing the original success.

## 5. Payment initiation and confirmation

1. Client requests payment for an issued, eligible invoice.
2. Backend resolves authenticated payer and estate/property relationship; recalculates current balance and rejects zero, cancelled, disputed-if-policy-blocked or otherwise ineligible invoices.
3. Backend selects the configured payment category and trusted destination based on invoice/tenancy settlement policy. It never takes an untrusted destination from the browser.
4. Backend creates an idempotent payment request through the existing Zvend payment service using server-controlled invoice, payer, amount, currency, destination and metadata.
5. The client receives only the existing provider's supported next-action data and a local payment attempt identifier.
6. The service confirms payment through the existing verified webhook or trusted server-to-server status query. Validate signature/authenticity, provider reference, amount, currency, intended destination and state transition.
7. In one transaction, record/associate the verified payment event, allocate available value to eligible invoice balance, update derived invoice status/balance, record receipt eligibility and enqueue notifications.
8. Receipt generation and payer/landlord/estate notifications are retriable and idempotent; failure to send does not roll back a confirmed financial transaction.

Handle amount mismatches, duplicate payment, overpayment, partial settlement, chargeback/reversal, stale invoice balance and wrong destination through explicit exception/reconciliation workflows. Never silently allocate excess value or post a fabricated balance.

## 6. Logical record concepts

Reconcile these concepts with Zvend's real payment tables before adding schema. Prefer references to existing user, payment, wallet, ledger and document records.

### Payment intent/attempt reference

Estate/invoice/payer scope; existing Zvend payment request or transaction reference; category; expected amount/currency/destination; idempotency key; attempt state; created/updated timestamps. Store no payment credentials or card/bank secrets in the estate module.

### Verified payment event

Trusted provider event/transaction identity, source, authenticated processing result, amount/currency/destination, event time, received time and safe failure metadata. Enforce uniqueness on the provider's stable event identity where supported. Retain raw payload only if existing Zvend policy requires it, securely and with strict access; never include secrets in logs.

### Payment allocation

Existing transaction ID, invoice and optionally invoice-line references, allocated amount/currency, state and creation metadata. One transaction may have multiple allocations; allocation totals may not exceed verified settled amount less valid reversals.

### Credit note, refund or reversal

Link original invoice/payment/allocation, reason, amount/currency, actor, approval/reconciliation metadata and timestamps. Preserve original records and link compensating entries rather than deleting or mutating them.

### Receipt

Stable receipt number/reference, payer/payee context, invoice/payment/allocation references, settled amount/currency/time and authorized document reference. Receipt contents must reflect verified settlement and be downloadable only by authorized parties.

## 7. Proposed API operations

Use the existing API prefix, validation, response and idempotency conventions after audit. These operations are examples, not confirmed routes.

| Method and path | Permission | Behavior |
|---|---|---|
| `GET /api/estate/charges` | Charge view | List effective estate charge definitions in authorized scope |
| `POST /api/estate/charges` | Charge management | Create draft/configured charge with validated scope and effective dates |
| `POST /api/estate/charges/:chargeId/versions` | Charge management/approval | Version amount, recurrence or applicability without mutating prior invoices |
| `POST /api/estate/invoices/preview` | Billing management | Preview eligible invoice generation without posting demands |
| `POST /api/estate/invoices/generate` | Billing management | Idempotently generate due invoices from approved schedules and immutable line snapshots |
| `POST /api/estate/invoices/:invoiceId/issue` | Invoice issue permission | Validate payer, property, total, due date and destination policy, then issue immutably |
| `GET /api/estate/invoices` | Invoice view | Return relationship-scoped, paginated invoices with derived balance/status |
| `GET /api/estate/invoices/:invoiceId` | Authorized payer/landlord/estate finance | Return permitted invoice lines, payment history and balance |
| `POST /api/estate/invoices/:invoiceId/payments` | Authorized payer | Recalculate balance and initiate via existing Zvend payment service with idempotency key |
| `GET /api/estate/payments/:attemptId` | Authorized payer/finance role | Read server-confirmed attempt/payment status; no browser assertion accepted |
| `POST /api/estate/payments/provider-events` | Existing trusted provider integration only | Authenticate event; process idempotently; validate transaction against intent and allocate value |
| `POST /api/estate/invoices/:invoiceId/disputes` | Authorized payer | Record dispute and reason; notify configured finance roles |
| `POST /api/estate/invoices/:invoiceId/credit-notes` | Finance permission/approval | Create immutable adjustment linked to original issued invoice |
| `POST /api/estate/payments/:paymentId/refunds` | Refund permission and existing payment service | Request refund under provider policy; reflect only verified refund result |
| `GET /api/estate/receipts/:receiptId` | Authorized payer/payee | Retrieve receipt metadata or short-lived protected download after authorization |
| `GET /api/estate/receipts/mine` | Authenticated payer with current/historical estate relationship | List only issued receipts whose allocations reconcile to trusted verified payments and invoices in the payer's authorized scope; apply relationship scope before counting/pagination. Return display metadata only; private receipt opening is separately authorized. |
| `GET /api/estate/finance/reconciliation` | Finance reconcile | List unmatched/mismatched provider or bank events in authorized estate scope |
| `POST /api/estate/finance/reconciliation/:itemId/resolve` | Finance reconcile | Record linked transaction/allocation or reasoned exception with audit history |

Rent schedule CRUD/renewal must validate active tenancy and settlement model. Estate subscription billing remains under the platform billing domain, not resident invoices.

## 8. Errors and concurrency

Use Zvend's established error envelope. Relevant domain outcomes include unauthenticated (`401`), unauthorized/relationship mismatch (`403` or deliberately hidden `404`), stale/ineligible state or duplicate settlement (`409`), validation/amount/currency error (`422`) and provider throttling (`429`/retryable service response).

- Invoice issue and payment allocation need transactional balance checks to prevent simultaneous requests from over-allocating.
- Unique invoice-generation keys prevent duplicate scheduled runs from creating duplicate invoices.
- Payment initiation retries reuse the original idempotency key and return the same attempt where supported.
- Provider event deduplication uses a stable provider event/transaction reference, not arrival time or a generated client ID.
- Out-of-order events cannot transition a refunded/reversed payment back to a successful settled state.
- Reports derive from invoice and trusted transaction/allocation records; cached totals must be rebuildable and reconcile to those records.

## 9. UI mapping

| UI surface | Integrated behavior |
|---|---|
| Charge settings | Estate-scoped, permission-checked charge versions and effective dates |
| Rent schedule | Terms from approved tenancy, owner/tenant visibility and explicit settlement destination |
| Invoice list/detail | Scoped invoice snapshots, derived amount due, payment history and dispute state |
| Pay invoice | Server-created payment attempt routed through the existing Zvend payment flow |
| Payment result | Poll/read server-confirmed status; browser return displays pending until trusted confirmation |
| Receipt download | Authorized short-lived receipt retrieval based on verified settlement |
| Finance/reconciliation | Provider/bank exceptions resolved by explicit audited finance action |

The current dashboard and resident screens are static previews. Their sample paid invoices do not represent actual Zvend payment records.

## 10. Acceptance evidence and integration gates

Before calling this phase implemented, demonstrate:

1. Cross-estate and relationship-scoped invoice reads, payment initiation, receipt access and reports.
2. Rent settlement to the configured landlord/estate destination without confusing ownership of funds.
3. No payment success from redirect or client request; signature/server verification, amount/currency/destination checks and duplicate-event idempotency.
4. Partial payment, concurrent allocation, overpayment, refund/reversal, cancellation, credit-note and dispute behavior with preserved history.
5. Recurring invoice generation is idempotent and charge/tenancy changes do not alter issued invoices.
6. Receipts and notifications are generated only from verified state and safely retried.
7. Ledger/payment, invoice, allocation, reconciliation and collection reports reconcile to the same authoritative transaction records.

Inspect and confirm the existing Zvend payment/wallet/ledger service APIs, event signature verification, idempotency behavior, settlement destinations, currency precision, transaction/refund records, notification queue, receipt/document service, API conventions and audit facility before schema or controller implementation.

### Provisional invoice issue use-case adapter

`backend/modules/billing/issue-invoice.js` exposes `createInvoiceIssueUseCase` with injected `transaction`, `requireEstatePermission(actorUserId, estateId, 'invoice.issue', tx)`, `findInvoiceForUpdate(tx, { invoiceId, estateContext })`, `resolveSettlementPolicy(tx, { estateContext, invoice, settlementPolicyId })`, `commitInvoiceIssue(tx, plan, { invoice, settlementPolicy })`, and `appendAuditEvent(tx, event)` adapters. The invoice lookup must lock and scope the record to the authorized estate. The settlement adapter must resolve the persisted destination policy, never accept a destination from the caller, and verify that it is active for the invoice estate and currency. The commit must persist only the planner's issue effects and immutable line snapshots, including the trusted destination snapshot needed for later payment initiation; invoice state and audit append share the transaction. The use case verifies the returned invoice ID, estate and `issued` status before returning. The actual Zvend repository must bind this seam to its financial ledger and test transaction rollback, concurrent issue attempts, stale state and cross-estate denial before exposing a route.

`backend/modules/billing/create-invoice-draft.js` exposes `createInvoiceDraftUseCase` with injected `transaction`, `requireEstatePermission(actorUserId, estateId, 'invoice.manage', tx)`, `resolveInvoiceDraftContext(tx, { estateContext, invoiceDraft })`, `generateInvoiceNumber(tx, { estateContext })`, `createInvoiceRecord(tx, invoice, { estateContext })`, and `appendAuditEvent(tx, event)` adapters. Context resolution must return the matched existing payer, same-estate property/tenancy links, active estate settlement policy and configured currency precision. Caller-supplied payer, property and tenancy identifiers are only lookup requests; the adapter verifies their relationships and eligibility. Currency and destination policy come from the trusted resolved settlement policy. The generated number must be unique per estate under concurrent creation. Persist the validated draft and audit in one transaction; return only its safe identifier, number, state, total and currency. This command does not initiate payment or issue a demand.

`backend/modules/billing/list-estate-invoices.js` exposes `createEstateInvoiceListUseCase` with injected `transaction`, `resolveInvoiceReadAccess(tx, { actorUserId, estateId })`, `queryInvoices(tx, { access, page, pageSize, filters, sort, asOf })`, and `projectInvoiceForActor({ actorUserId, access, invoice, balance, tx })`. The access resolver must authorize estate finance staff and relationship-scoped payers/landlords using trusted memberships and property/tenancy records. The query must apply estate and relationship scope before search, counts, filters and pagination and return `{ items: [{ invoice, allocations }], total }`; every allocation list must be scoped to its invoice and sourced from verified payment-allocation history. The use case derives issued balances at a server timestamp and rejects invalid precision, over-allocation and applied allocations on unissued invoices. The actor projection may contain only `invoiceNumber`, `category`, `payerDisplayName`, `propertyCode` and `tenancyLabel`; the response is assembled from those display fields plus validated invoice and derived balance fields. It must never include provider credentials, storage keys or raw allocation records. The actual adapter must verify cross-estate isolation and payer/landlord visibility before exposing the route.

The invoice-list query accepts either one exact `category` or a bounded `categories` allowlist, never both. The repository applies the configured categories inside the authorized estate/relationship predicate before counting and pagination. This supports landlord charge-category views without making charge categories or property IDs an authorization mechanism.

`backend/modules/billing/list-my-landlord-rent-invoices.js` composes a landlord-only rent category view over that invoice use case. Configure the canonical rent category on the server; the client cannot choose a category, payer, payee, property or tenancy filter. The wrapped list service must retain the relationship-aware access resolver and apply estate/landlord scoping before pagination. The composition rejects results outside the configured rent category or issued/partially-paid/paid states. It creates no new invoice repository or payment ledger and is not a deployed route.

`backend/modules/billing/list-my-landlord-property-charge-invoices.js` composes a landlord property-charge view over that invoice use case with a server-configured category allowlist. The underlying query applies both those categories and the verified actor/property relationship before pagination; the composition rejects categories outside the allowlist and non-issued states. Estate charge definitions remain distinct from issued invoices, and this composition does not create payment or invoice state.

`backend/modules/billing/read-estate-invoice.js` exposes `createEstateInvoiceDetailUseCase` with the same `transaction` and trusted `resolveInvoiceReadAccess` boundary, plus `findInvoiceForRead(tx, { access, invoiceId })`, `loadInvoiceAllocationsWithPayments(tx, { access, invoice })`, and `projectInvoiceForActor({ actorUserId, access, invoice, balance, tx })`. Invoice and payment reads must remain inside the actor's estate/payer/landlord relationship scope. The history adapter returns bounded `{ allocation, payment, receipt? }` rows where each payment has trusted verification evidence and matches the invoice currency/destination; each allocation belongs to the requested invoice. An optional receipt must be an issued receipt bound to that exact allocation, payment and invoice. The use case reconciles immutable line totals, derives balance from applied allocations, and returns only payment amount, currency, allocation state, timestamps and an optional public receipt ID; provider transaction IDs, storage references, and raw records stay private. Receipt detail access remains a separate authorization flow.

`backend/modules/billing/request-invoice-payment.js` exposes `createInvoicePaymentRequestUseCase` with injected `transaction`, `resolveInvoicePaymentAccess(tx, { actorUserId, estateId, invoiceId })`, `findInvoiceForUpdate(tx, { access, invoiceId })`, `loadInvoiceAllocations(tx, { access, invoice })`, `getInvoicePaymentPolicy(tx, { access, invoice })`, `findPaymentAttemptByIdempotencyKey(tx, { estateId, invoiceId, payerUserId, idempotencyKey })`, `createPaymentAttemptAndOutbox(tx, trustedAttemptInput, { access, invoice })`, and `appendAuditEvent(tx, event)`. Access must prove the authenticated actor may pay as the invoice payer under current estate/property/tenancy policy. Lock the invoice and derive outstanding value from verified applied allocations before accepting an amount; partial-payment and dispute policy are server-owned. Currency, category and destination come from the issued invoice and trusted payment policy. The create adapter must persist the attempt and durable outbox request atomically and enforce a unique estate/invoice/payer/idempotency key. Payment-service invocation happens from its outbox worker, outside this transaction; request creation returns a pending attempt only and never marks an invoice paid. A retry with the same key returns the original safe attempt even if the balance later changes; a changed amount with the same key is rejected. The command audit and attempt/outbox write commit together.

`backend/modules/billing/read-payment-attempt.js` exposes `createPaymentAttemptReadUseCase` with `transaction`, `resolvePaymentAttemptReadAccess(tx, { actorUserId, estateId, attemptId })`, and `findPaymentAttemptForRead(tx, { access, attemptId })`. The access adapter must authorize only the payer or an explicitly permitted estate finance actor and scope the attempt to its estate before returning it. Attempt state is read from Zvend's trusted payment service record, updated by its verified event/worker path; never accept browser-reported status. A succeeded attempt requires a server-verified timestamp. Return only attempt ID, invoice ID, safe state, exact amount/currency and lifecycle timestamps. Provider references, credentials and internal metadata remain private. If the existing Zvend payment service supports a client next-action payload, add a separate allowlisted adapter after its supported response schema is confirmed; do not expose a raw provider response.

`backend/modules/billing/read-estate-receipt.js` exposes `createEstateReceiptReadUseCase` with `transaction`, `resolveReceiptReadAccess(tx, { actorUserId, estateId, receiptId })`, and `findReceiptEvidence(tx, { access, receiptId })`. Authorization must prove payer, payee or explicitly permitted finance access. Evidence must bind an issued receipt to its invoice, payment and allocation in the same estate; the allocation amount/currency and receipt settlement time must match the immutable verified payment record. The response contains actor-safe receipt metadata and a verified/reversed allocation indicator, but no provider transaction ID, private document reference or permanent URL. Receipt-file access requires a separate short-lived private-storage authorization operation.
