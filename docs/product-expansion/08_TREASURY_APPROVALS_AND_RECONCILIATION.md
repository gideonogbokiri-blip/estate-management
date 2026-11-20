# 08 — Treasury, Approvals and Reconciliation

Status: implemented; bank-statement import and distributed monitoring deferred.

## Treasury

`GET /api/v1/estate/estates/:estateId/treasury/summary` reports collections, wallet balances, outstanding invoices, pending settlements, expenses and reconciliation exceptions. Estate treasury is separate from rent (`LANDLORD_PAYABLE`) and platform finance.

## Approvals

- Expenses: policy-driven multi-stage approvals with requester-exclusion and distinct-approver rules.
- Payouts: verified beneficiaries, threshold policy, self-approval prevention, distinct approvals, cleared-funds checks, idempotent demo execution and full audit.
- Other single-step decisions: tenancy, household, ownership, incidents, budgets, identity.

## Estate manager reports

`GET /api/v1/estate/estates/:estateId/reports/summary` is management-scoped and aggregates invoice counts/billed amount, rent entitlement/collected/outstanding, expense and payout totals, and the audit-event count. The estate manager dashboard shows these as a Reports panel with CSV export buttons for wallet, ledger and audit statements.

## Statements and audit

- `GET .../statements/wallet` — opening/closing balances and a running balance per entry; `?format=csv` exports.
- `GET .../statements/ledger` — posted journals and entries; CSV export.
- `GET .../audit` — management-scoped query over `AuditEvent` with action/actor/outcome/date filters and CSV export.

## Reconciliation

Invoice and expense settlements are matched against normalized bank references with receipts and audit events. Quarantined provider webhook events surface as reconciliation exceptions. A bank-statement import and exception-resolution workbench remain a gap.

## Baseline rate limiting

`RateLimitGuard` is wired into both the local bootstrap and the Vercel serverless wrapper. It is a per-instance sliding-window control, not a distributed quota; a shared store is required before treating it as a hard limit.

Tests: `backend/tests/payouts.test.js`, `hardening.test.js`.
