# LANCON fintech expansion — source audit and phased implementation plan

Date: 20 November 2026
Blueprint: `LANCON_Fintech_Estate_Product_Expansion_Specification_v1.0.md`

## 1. Audit method

Reviewed Prisma models, NestJS controllers/services, Flutter entry points and connected screens, API routes, local/hosted verification results and the current repository state. The supplied specification is treated as the source of truth for target behaviour, but existing modules are not replaced.

## 2. What is already implemented

| Capability | Evidence in current code | Status |
|---|---|---|
| Multi-estate identity, memberships, roles | `User`, `EstateMembership`, `PlatformRoleGrant`, estate-scoped guards | Implemented |
| Properties, ownership, occupancy, tenancies, household-adjacent data | `EstateProperty`, `EstateOwnershipInterest`, `PropertyOccupancy`, `EstateTenancy` | Implemented; household profiles and consent-based identity checks absent |
| Charge definitions/versions, invoice drafts, settlement policies, manual settlements | `EstateChargeDefinition`, `EstateChargeVersion`, `EstateInvoiceDraft`, `EstateSettlementPolicy`, `EstateInvoiceSettlement`, charges controller/service | Connected base; recurring generation, applicability preview, credit notes and landlord rent payable ledger absent |
| Expenses, budgets, approval policies and audit | `EstateExpenseRequest`, `EstateBudget`, decision models, audit events | Implemented |
| Visitor passes, gate assignments, check-in/out, manual admission, access events | `EstateVisitorPass`, `EstateGate*`, `EstateVisitorVisit`, gate controller/service | Implemented; QR/PIN issuer lifecycle partially implemented |
| Notifications | `EstateNotification` + delivery outbox, in-app page, SMTP-ready command | In-app implemented; external delivery configured by operator |
| Wallet account and transaction records | `EstateWallet`, `EstateWalletTransaction`, `wallets.service.ts`, resident money UI | Initially implemented, but single-entry; Phase 1 must reconcile to the spec's double-entry ledger |
| Paystack provider adapter | Dedicated virtual account provisioning, signed webhook verification, rent payment from wallet | Wired but inactive until `PAYSTACK_SECRET_KEY` is supplied; no funding intent or provider-event record yet |
| Estate manager UI | Side menu, finance card, operational pages | Connected |
| Platform admin UI | Application review, estates, team, balances, audit | Connected |

## 3. Gaps and conflicts against the specification

1. **Ledger invariants (P0)** — current wallet transactions are single-entry (credit/debit). The spec requires one authoritative double-entry journal with balanced postings, immutable entries, unique references, source IDs and explicit currency.
2. **Funding lifecycle (P0)** — a verified webhook credits the wallet directly. Missing: funding intent, pending state that never increases spendable balance, provider-event replay store, amount/currency/recipient matching and quarantine path.
3. **Concurrency (P0)** — rent payment checks balance with an aggregate query; it needs a serializable transaction and wallet row lock to prevent overspend.
4. **Provider confirmation (P0)** — production cannot be enabled without Paystack/KYB/KYC and regulatory confirmation; keys are not available. Keep behind an explicit configuration gate.
5. **Treasury/payouts (P1)** — no fund-category sub-ledgers, payout request/approval/execution, beneficiary verification, threshold rules or reconciliation exceptions.
6. **Rent engine (P1)** — rent is shown as tenancy terms but not generated deterministically from approved tenancies; no landlord payable/settlement ledger or arrears view.
7. **Registration/identity/household (P2)** — self-registration exists; management approval lifecycle, household profiles/dependants and identity-provider verification do not.
8. **Property GPS (P2)** — latitude/longitude fields exist; capture method, accuracy, verification status and correction workflow do not.
9. **Services catalogue (P3)** — optional services are hard-coded shortcuts; no enabled/eligible/pricing/fulfilment/reconciliation model.
10. **Visitor QR/PIN (P3)** — pass generation and gate verification exist; short-lived QR payload design and revocation UI need review against spec.

## 4. Phased plan

- **Phase 1 — P0 foundation:** reconcile wallet with ledger architecture. Add journal/entry structures, funding intents, provider webhook events, concurrency-safe posting, replacement/compensating reversal primitives, automated financial-integrity tests and finish the bank-style resident UI.
- **Phase 2 — P1 estate payments:** treasury fund categories, collections/pending settlement views, payout initiation/approval/execution, charge applicability preview, deterministic recurring invoice generation, rent schedule generation, landlord entitlement ledger and arrears.
- **Phase 3 — P2 identity/property:** self-registration approval lifecycle, management invitations, household relationships with restricted profiles, consent-based identity verification, property GPS capture/verification/correction.
- **Phase 4 — P3 services/access:** configurable service catalogue, eligibility and pricing, provider integrations for utilities/airtime/data, verified fulfilment and reconciliation, enhanced QR/PIN passes.
- **Phase 5 — P4 hardening:** statements, reconciliation operations, advanced approvals, monitoring, incident response, penalty/rate-limit review, MFA/step-up for sensitive financial actions, full acceptance testing.

## 5. Phase 1 scope and acceptance

Phase 1 will be considered complete when:

- every wallet credit/debit posts a balanced journal;
- a pending funding intent cannot increase spendable balance;
- a verified provider event credits exactly once and duplicate webhooks replay safely;
- wrong amount/currency/reference/recipient is rejected or quarantined;
- concurrent debit cannot overspend;
- reversals are compensating and never delete posted history;
- automated tests cover the above;
- resident dashboard shows balance in the green bank-style header with Add Money, Pay Bills and History actions, plus Quick Services and Settings;
- all changes remain additive and backward compatible.

## 6. Phase 1 implementation record (20 November 2026)

- Additive migration `20261120100000_ledger_and_funding_intents` adds `ledger_journals`, `ledger_entries`, `wallet_funding_intents`, `provider_webhook_events` and links existing wallet transactions to a journal.
- `LedgerService` posts exactly two balanced entries per journal and supports compensating reversals without deleting posted history.
- Wallet rent payment now runs in a serializable transaction with a wallet row lock, posts a balanced journal, then records the invoice settlement and receipt atomically.
- Funding intents are explicit: a pending intent never credits a wallet. Provider webhooks are signature-verified, stored for replay protection, matched to an intent and rejected/quarantined on wrong amount, currency, recipient or reference. Verified funding posts exactly one credited journal.
- Automated tests cover balanced postings, invalid instructions, reversals and payout authorization. 13 tests pass, 2 opt-in integration tests skipped.
- Resident dashboard now uses the bank-style green header with balance, Add Money, Pay Bills, History, Quick Services and Settings. **Add Money** creates a server-side funding intent before showing transfer details, so a client-side amount cannot credit a wallet.

## 6b. Phase 2 progress (20 November 2026)

- Added a read-only estate treasury summary endpoint backed by the ledger, wallet transactions, invoice settlements, expense requests, funding intents and quarantined provider events: `GET /api/v1/estate/estates/:estateId/treasury/summary`.
- Authorization is limited to active estate administrator, manager and finance-manager memberships. The manager dashboard now renders an Estate treasury card with collections, wallet balances, outstanding invoices, pending settlements and reconciliation exceptions.
- Payout controls added: verified beneficiaries, estate payout policy with threshold-based approvals, self-approval prevention, cleared-funds checks, idempotent initiation, separate approve/reject decisions and provider execution behind `PAYSTACK_SECRET_KEY`. The manager dashboard can request and decide payouts.
- Rent engine added: deterministic, idempotent schedule generation from active tenancies (monthly/quarterly/annual), rent receipts, landlord entitlement/arrears summary, and wallet-funded rent payment posting to a landlord payable ledger account. Rent is kept separate from estate levies and treasury.
- Charge applicability preview added: `GET /estate/estates/:estateId/charges/versions/:versionId/applicability` lists the properties and payers a version would bill, with the relationship reason, for a given billing period.
- Deterministic recurring levy generation added: `GET .../charges/recurring/preview` shows the calendar periods and recipient counts; `POST .../charges/recurring/generate` creates and issues invoices for active recurring charges with deterministic idempotency keys. Re-running returns the same invoices instead of duplicating them, and an invoice already created manually for the same business tuple is treated as a replay. All finance roles are scoped by active estate membership.

## 6c. Demo-first mode (20 November 2026)

Per product direction, Paystack is deferred to the final step. `FINANCIAL_DEMO_MODE=true` now supplies clearly labelled `DEMO-…` account numbers, an explicit **Simulate demo credit** action that posts a balanced ledger journal, and demo payout execution. All demo responses and UI states are marked `DEMO MODE · NO REAL MONEY`. Production requires `FINANCIAL_DEMO_MODE=false` plus a verified Paystack arrangement.

## 7. External dependencies still required

Paystack TEST/LIVE secret keys, approved merchant/DVA product confirmation, webhook registration, settlement/KYC/KYB and Nigerian regulatory/legal sign-off. Payout, withdrawal, transfers and third-party vending remain feature-flagged/inactive until these are confirmed.
