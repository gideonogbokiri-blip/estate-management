# Zvend Estate — Finance and Expense Approval Contract

**Status:** Proposed contract; reconcile with Zvend ledger/payment services before implementation  
**Product baseline:** `Zvend_Estate_Management_Build_Documentation.md`  
**Scope:** Estate budgets, expense requests, approvals, payees, payment references and reconciliation

## 1. Core financial boundary

An expense request, an approval decision and a verified payment are different states and different records. Approving a request authorizes spend under the estate's configured policy; it does not create a payment or mark an expense as paid. Only a trusted Zvend payment/ledger transaction or reconciled external bank transaction can establish payment status.

Posted financial transactions are never deleted or silently overwritten. Correct mistakes with an auditable reversal, refund or adjustment according to the existing Zvend finance model.

## 2. Logical records

Reuse Zvend users, payment/ledger transactions, receipt storage, audit service and any existing accounting modules.

### Budgets and categories

- estate-scoped budget period, currency, approval state and approver metadata
- budget lines linked to configurable expense categories and allocated amount
- budget revisions preserve prior approved values, actor, reason and effective date
- actuals are derived from approved/posted finance records according to a documented policy; do not keep a client-editable total

### Expense request

- ID, estate ID, request code, requester user ID
- description, category, payee/vendor reference or entered payee pending verification
- requested amount as fixed precision decimal and explicit currency
- requested/needed-by date, notes and private attachment references
- budget line/reference if applicable
- state (`draft`, `pending_approval`, `approved`, `rejected`, `cancelled`, `partially_paid`, `paid`)
- created/submitted/updated actors and timestamps

### Approval history

Immutable decision entries with request ID, actor, decision, amount limit/policy result, optional note/reason and timestamp. Multi-step approvals must be represented as separate approval stages where policy requires more than one approver.

### Payment and reconciliation link

Link an approved expense to one or more existing verified Zvend transaction IDs/payment references. Store allocated amount and reconciliation metadata; never copy credentials or accept frontend assertions as payment proof. Refunds/reversals link back to original transactions and preserve history.

## 3. Authorization and approval policy

- Derive estate scope from authenticated membership; validate every budget, request, vendor, attachment and payment reference belongs to that estate.
- Separate `expense.request`, `expense.view`, `expense.approve`, `budget.manage`, `expense.pay`/payment initiation and `finance.reconcile` permissions.
- Enforce server-side approval thresholds and segregation-of-duties rules; a requester must not approve their own request where estate policy forbids it.
- Approval limits and multi-approver thresholds are estate-configured, versioned and audited. Do not hardcode monetary thresholds in the UI or code.
- Restrict vendor financial and personal details to authorized staff.
- Use private document storage and time-limited authorized receipt/document access.
- Record every submission, edit, approval/rejection, cancellation, payment allocation, reconciliation and reversal in the audit system.

## 4. State transitions

```text
Draft → Pending approval → Approved → Partially paid → Paid
                  ├────→ Rejected
                  └────→ Cancelled (where allowed)
Approved → Cancelled only before payment and according to policy
```

- Submitted requests are immutable to requesters except through an explicit return-for-correction workflow if the estate policy enables it.
- Approval rechecks current budget, policy, role, separation-of-duties and request state inside a transaction.
- Concurrent approval/rejection attempts must have one winner.
- Payment allocation cannot exceed the approved amount less prior valid allocations/adjustments.
- Reversals/refunds never erase original approvals or payments.

## 5. API operations

Names and response/pagination format are provisional. Align them with existing Zvend API conventions after repository audit.

| Method and path | Permission | Behavior |
|---|---|---|
| `GET /api/estate/finance/budgets` | Estate finance view | List authorized estate budgets and derived actual/remaining summaries |
| `POST /api/estate/finance/budgets` | `budget.manage` | Create a draft budget version with explicit period, currency and lines |
| `POST /api/estate/finance/budgets/:budgetId/submit` | `budget.manage` | Submit for configured approval |
| `POST /api/estate/finance/budgets/:budgetId/approve` | Budget approver | Approve a version and record immutable decision/audit history |
| `GET /api/estate/expenses` | Expense view | Estate-scoped paginated list and approval queue |
| `POST /api/estate/expenses` | `expense.request` | Create Draft request with validated decimal amount, category and payee |
| `PATCH /api/estate/expenses/:expenseId` | Requester or finance staff; Draft only | Update permitted pre-submission fields |
| `POST /api/estate/expenses/:expenseId/submit` | Requester | Validate details, budget/policy references and attachments; queue approval |
| `GET /api/estate/expenses/:expenseId` | Authorized requester/approver/finance role | Return actor-appropriate request, decision history and payment summary |
| `POST /api/estate/expenses/:expenseId/approve` | `expense.approve` | Recheck policy and budget transactionally; record approval, never payment |
| `POST /api/estate/expenses/:expenseId/reject` | `expense.approve` | Require reason and record decision/audit event |
| `POST /api/estate/expenses/:expenseId/cancel` | Requester/finance according to state | Cancel only when state/policy allows; preserve history |
| `POST /api/estate/expenses/:expenseId/payments/allocate` | Payment/reconciliation permission | Link verified payment reference and allocate within approved balance |
| `POST /api/estate/expenses/:expenseId/reconcile` | `finance.reconcile` | Reconcile against existing trusted transaction/bank record; audit result |

The expense list applies estate and actor authorization before search, count and pagination. Its summary contains only the reference, description, category, requester/payee display labels, amount/currency, safe dates, derived status and actor-allowed decisions. Paid and outstanding amounts are derived from expense-scoped verified allocations; drafts/pending requests cannot carry applied allocations. Never include private file references, payee account details, internal approval notes or provider data in the list projection.

The budget overview returns up to 24 authorized approved versions, ordered with the currently effective version first. The server resolves the estate-local business date and marks effective periods where that date falls between the inclusive start and end dates. For each immutable line, derive **committed** from linked approved/partially paid/paid expense amounts and **paid** from verified applied allocations after reversals. Available budget is allocated less committed; do not subtract paid a second time. The repository must join expenses by stable budget-line ID (or the persisted category key where that is the line identity), and every expense and allocation must match the same estate, budget, line and currency. Draft/pending expenses do not consume a commitment; canceled/rejected expenses are excluded. If an approved expense is reversed or refunded, keep its commitment until the estate's explicit cancellation/adjustment workflow changes that record.

## 6. Numeric, consistency and reliability rules

- Store amounts using a fixed precision decimal type with explicit currency. Never store authoritative money as IEEE floating point.
- Define currency rounding and decimal precision using current Zvend/payment conventions.
- Use database transactions for approval state, budget reservation (if policy uses reservation) and payment allocation.
- Make payment/webhook and allocation handling idempotent using trusted transaction/event identifiers.
- Do not update expense status to Paid from a browser return URL or editable request body.
- Avoid double-counting budget actuals across approved, paid, partially paid and reversed entries; document which states consume budget and whether reversals release it.
- Use estate-scoped indexes and unique request references; paginate expense/history queries.

## 7. UI mapping

| UI surface | Backend behavior when integrated |
|---|---|
| Budget overview | Server-derived budget lines, actuals and remaining amount for authorized estate |
| Request expense form | Create and submit a request; validate category, amount, payee and private attachments |
| Approval dialog | Server-side policy evaluation, approver permission, immutable decision and audit event |
| Approved status | Approval only; do not label as paid or initiate financial settlement automatically |
| Paid status | Read from verified payment allocation/reconciliation record |
| Search/status filters | Apply after authorization and estate scoping |

The current preview only creates local request rows and local approval state. It does not persist a budget, approval, payment or audit event.

`backend/modules/finance/read-estate-expense.js` is the provisional read seam for the detail route. It resolves requester/approver access per expense, returns the policy stage and immutable approval history using actor-appropriate reviewer labels, and includes payment totals only where the actor may view them; totals are recalculated from verified allocations. The list remains a compact safe projection and does not carry the detail history.

The provisional `backend/modules/finance/decide-expense-request.js` use case implements the transaction boundary around the existing decision planner. Its host adapters must enforce the active policy stage permission, lock/recalculate a linked budget before final approval, verify the configured payee destination, commit decision/reservation effects, append audit, and enqueue the requester notice atomically. The Flutter preview exposes decision actions only when the expense projection's `allowedCommands` includes them; local preview approval must never update paid totals.

`backend/modules/finance/list-finance-activity.js` is the estate-scoped read seam for recent expense decisions and payment allocations. The host query must join immutable expense decision events and applied allocation records to their source expense/payment, apply the resolved estate and `report.financial.view` scope before filtering/counting/pagination, and return source-backed amount/currency values. Every decision row must match its immutable decision type, time and money; every payment row must be an applied allocation for a succeeded, verified payment whose allocation amount/currency matches the feed amount. The actor-specific display projector supplies only safe references/descriptions/display names. The UI must label approval separately from payment and may show only verified allocations as payment activity.

## 8. Acceptance evidence

Before finance/expense features are considered complete, demonstrate: cross-estate finance isolation; unauthorized or self-approval rejection according to policy; approval threshold enforcement; duplicate approval and payment event idempotency; correct partial allocation and balance calculations; reversals preserving original records; budget actuals reconciling to ledger entries; and no client-only path that marks an expense Paid.

## 9. Integration gates

Confirm the existing Zvend wallet/ledger/payment contracts, currency/decimal conventions, accounting/reporting facilities, settlement destination model, webhook verification, budget/accounting policy, approval limits and audit/document services before migrations or endpoint implementation.
