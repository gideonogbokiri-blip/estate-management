# LANCON — Fintech Estate Management Product Expansion Specification

**Document ID:** LANCON-PROD-EXP-001  
**Version:** 1.0  
**Status:** Proposed product and engineering baseline — review before implementation  
**Date:** 19 November 2026

> This document supplements the existing LANCON project. It does not authorize replacing existing modules, creating a parallel wallet/ledger, or changing production data without a separate approved implementation plan.

## 1. Executive summary

LANCON is to be expanded into a multi-estate digital operations and financial services platform. Residents, tenants, landlords, estate management and authorized staff use one coordinated application to manage property relationships, estate obligations, wallet-funded payments, visitor access and optional estate services.

The five pillars are:
1. Estate operations: properties, ownership, tenancy, occupancy, household members and staff.
2. Resident financial experience: wallet balance, funding, invoices, levies, rent and transaction history.
3. Estate treasury: collections, financial categories, expenses, approval workflows and settlement reporting.
4. Community access and services: visitor PIN/QR passes, utilities, airtime/data and configurable services.
5. Identity and location: consent-based identity checks and property GPS mapping.

## 2. Existing project baseline and integration principles

The supplied archives show a Flutter client, NestJS backend, PostgreSQL/Prisma, estate/property/tenancy workflows, charge definitions and versions, invoice-draft concepts, finance/expense workflows, visitor-pass and gate-visit workflows, and property latitude/longitude fields.

The existing Billing & Payments Contract says to reuse existing payment, wallet, transaction, notification and receipt services where suitable, and not to introduce a new wallet, gateway or accounting ledger without reconciling the repository first.

The backend schema includes `EstateWallet` and `EstateWalletTransaction` concepts. The supplied source snapshot does not establish that a complete production wallet service, provider integration, verified top-up lifecycle or end-to-end wallet payment flow is already implemented. These require a source audit and implementation verification.

**Integration rules**
- Extend and reconcile existing wallet/payment concepts; do not create a competing subsystem.
- Reuse existing estate, property, user, membership, ownership, tenancy, charge-version, invoice-draft, expense, visitor-pass and audit concepts where suitable.
- A model or screen does not prove its complete workflow is production-ready.
- Prefer additive migrations and backward-compatible API changes.
- Enforce estate scope and relationship permissions on every operation.
- Keep platform-level finances separate from estate finances.
- Financial mutations must be server-authoritative, transactional, idempotent and auditable.
- Never silently rewrite or delete issued invoices, confirmed payments, receipts or posted financial records.

## 3. Actors and account relationships

Actors: Platform Super Administrator; Estate Administrator/Manager; Estate Finance Officer; Treasurer/Chairman/Approver; Resident/Owner-occupier; Tenant; Landlord/Property Owner; Security Officer; approved Service Operator.

A person has one platform identity but may have multiple estate memberships and property relationships. Do not force a single global role where a person may be a landlord in one estate and tenant in another.

Household members are distinct from account owners. Support adult household members, dependants/children and restricted household profiles. Children do not automatically receive independent login or financial privileges.

Authorization must be enforced by role and relationship. Resolve estate/property/tenancy/ownership scope on the server; never trust client-submitted estate IDs, destinations or account references.

## 4. Wallet and financial architecture

### 4.1 Recommended model

Use an internal, server-authoritative wallet/ledger experience with funding and settlement through an approved regulated payment arrangement. The word “wallet” in the UI must not imply that LANCON independently holds deposits or provides an unregulated e-money service.

Recommended initial baseline: **closed-loop estate payment wallet with controlled refunds and exceptional withdrawals**, subject to written confirmation from Paystack and qualified Nigerian regulatory counsel. Do not enable unrestricted transfers, cash withdrawals or general-purpose stored value until the operating model is confirmed.

### 4.2 Account categories

- Resident wallet: funds attributable to a resident account.
- Landlord entitlement/payable: track amounts owed to landlords; a spendable landlord wallet only if approved.
- Estate treasury: logical sub-ledgers for estate collections and disbursements.
- Third-party service clearing/payables.
- Platform revenue/fees, where contractually and legally permitted.
- Provider settlement/clearing.
- Refund, reversal and suspense accounts.

Logical treasury categories are not automatically separate bank accounts. Actual bank accounts and provider settlement destinations must be independently configured and verified.

### 4.3 Double-entry ledger

Use one authoritative double-entry ledger. Every posted event has balanced debit and credit entries in the same currency. Balances derive from posted ledger entries; they are not independently editable fields.

Required controls: immutable posted journal entries; unique transaction and idempotency references; explicit currency; exact decimal/minor-unit arithmetic; source type/ID; actor and timestamps; compensating reversals; transactional posting; concurrency-safe balance checks; reconciliation state.

Pending payment attempts never increase spendable balance. Only verified funding events credit a wallet.

### 4.4 Resident wallet

Resident dashboard displays available balance, Add Money, Pay Bills/Levies, transaction history, outstanding invoices, due dates and recent activity.

Users can fund through approved Paystack methods, pay eligible invoices from wallet, view receipts and transaction details, report issues and request refunds/exceptional withdrawals where policy permits. Do not include unrestricted peer-to-peer transfers in the initial scope.

### 4.5 Estate treasury

Management dashboard displays collections, cleared/available amounts by fund category, pending settlements, outstanding invoices, approved/pending expenses, payout requests and reconciliation exceptions.

Management does not automatically receive unrestricted withdrawal rights. Initiation, approval and execution permissions are separable.

### 4.6 Payout controls

Default workflow: finance officer initiates; a separately authorized treasurer/chairman approves; two approvals are required above configured thresholds; self-approval is prevented where policy requires; beneficiary details are verified; limits and cleared-funds checks apply; provider confirmation is required before marking paid. Every action is audited.

## 5. Paystack and payment-provider integration

Paystack is a payment/processing provider, not the LANCON internal wallet ledger. The backend remains responsible for invoice eligibility, account ownership, ledger posting, allocation, audit and reconciliation.

Before implementation, confirm with Paystack the approved merchant/product arrangement, Dedicated Virtual Account suitability, supported funding and payout channels, settlement timing, fees/limits, refunds/reversals, webhook events and signature rules, KYC/KYB and any subaccount/split-settlement requirements.

A DVA is a collection mechanism; do not assume it is a resident-owned bank account or a stored-value wallet.

**Funding flow**
1. User requests wallet funding.
2. Backend resolves user, wallet, estate relationship and currency.
3. Backend creates a unique funding intent/idempotency reference.
4. Backend initiates approved provider checkout or supplies an assigned DVA.
5. Provider processes payment.
6. Backend receives authenticated webhook and/or verifies status server-to-server.
7. Backend validates authenticity, reference, amount, currency, recipient, status and duplicate state.
8. Backend posts one balanced ledger journal.
9. Balance is recalculated from posted entries.
10. Receipt/notification is issued and records are reconciled.

A browser redirect or client assertion is never proof of payment. Webhooks must be idempotent, replay-safe and resilient to delayed/out-of-order delivery.

**Wallet invoice payment:** verify payer and relationship, invoice eligibility, balance and currency; create idempotent payment instruction; atomically post wallet debit, collection credit and invoice allocation; generate receipt from the confirmed ledger transaction.

Direct Paystack invoice payment and wallet funding/payment may coexist if both feed one invoice allocation model. Prevent double-crediting a wallet when a direct invoice payment arrives.

## 6. Billing, levies and rent engine

Charge categories may include estate service charge, security levy, waste, water, electricity/common-area power, facility charges, development levy and other approved fees.

Each charge definition supports name/code/description/category, amount/currency, one-time or recurring schedule, effective dates and versions, due/grace rules, applicability, mandatory/optional status, partial payment, approval, late-fee policy and fund category.

Applicability may be estate-wide, zone/street, building, property type, individual property, tenancy or payer relationship. Preview the target population before activation. Avoid charging owner and tenant twice for the same obligation.

Recurring invoice generation must be deterministic and idempotent. Issued invoices preserve snapshots of payer, property/tenancy, description, amount, currency, due date and settlement policy. Editing a charge does not rewrite an issued invoice.

Rent is distinct from estate levies and platform subscriptions. Rent schedules originate from approved tenancies and identify tenant, landlord, property, amount, frequency, lease period, due date, partial-payment policy and versioned settlement destination. Recommended baseline: record rent collection and landlord entitlement separately. Do not assume rent belongs to estate treasury. Use a landlord payable/settlement ledger unless an approved model supports a spendable landlord wallet.

Invoice lifecycle: `DRAFT → ISSUED → PARTIALLY_PAID → PAID`; overdue is derived from due date and balance. Corrections use credit notes, reversals, refunds or reissue, not destructive edits.

## 7. Registration, identity and household management

Support resident self-registration with management approval and management-created accounts/invitations for residents, landlords, tenants and staff.

Collect only what is needed: legal name, verified email/phone, password under existing policy, profile photograph, selected estate/property, relationship to property and required supporting documents. Identity document capture and selfie/liveness verification should use an approved provider and documented purpose/consent.

Approval lifecycle: `DRAFT → SUBMITTED → UNDER_REVIEW → APPROVED | REJECTED | NEEDS_INFORMATION`. Access state is separately pending, active, suspended or revoked. Approval establishes authorized estate membership and property/tenancy/ownership relationship.

Household profiles support adult members, children/dependants and restricted members, with relationship, effective dates, approval and access rights. Visitors should use visitor-pass functionality rather than permanent household membership.

Identity evidence must be private, encrypted, access-restricted and retained only as required. Prefer provider verification tokens/results over storing biometric templates.

## 8. GPS property mapping

Separate registration-time user location from actual property location. Registration location is consent-based and is not proof of residence.

Reuse existing property latitude/longitude fields if their semantics are adequate. Property workflow: manager selects property; app requests permission or allows map pin placement; capture latitude, longitude, accuracy, time and method; show pin for confirmation; allow correction; save verification status, verifier and reason.

Potential fields only if absent: `accuracy_meters`, `capture_method`, `captured_at`, `verification_status`, `verified_by`, `verified_at`, `correction_reason`. Do not silently track residents.

## 9. Configurable services catalogue

Core services: account access, wallet/history, notices, security access and support/reporting. Optional services: levies, rent, electricity, airtime, data, water, waste, visitor passes, facility booking, maintenance, incident/emergency, marketplace and documents.

Each service defines key/name/icon/description/category/order, enabled state, eligible roles/estates, provider reference, pricing/fees/limits, availability, required inputs, validation, timeout/retry, refund policy, reconciliation and support details.

Management can enable/disable optional services. Core account and security capabilities cannot be removed by ordinary service configuration.

Airtime/data/electricity/water require an approved aggregator. Validate inputs and quote amount/fees; use idempotent requests; verify fulfillment; reconcile provider references; show tokens/details only after confirmation. Unknown outcomes must be queried before retry to avoid duplicate vending.

## 10. Visitor access and gate management

Reuse existing visitor-pass and gate-visit domains. Residents select visitor details and time window, generate short-lived QR and numeric PIN, share securely, view status and revoke unused passes.

Security officers scan QR or enter PIN. Backend validates estate, assigned gate, status, time window, usage limits and revocation; records attempts/check-in/check-out; prevents replay and duplicate admission. Manual admission requires authorization, reason and audit.

Codes must be unpredictable, estate-scoped, time-bound and revocable. Do not put personal data directly in QR payloads.

## 11. Role-specific dashboards

**Resident:** wallet, Add Money, Pay Levies, Rent, history, invoices, utilities, visitor pass, maintenance, incidents, facilities, notices, documents and emergency contacts.

**Landlord:** verified portfolio, occupancy, tenancy, rent schedule/arrears, receipts, settlement statements, maintenance and documents.

**Estate management:** treasury, collections, charge schedules, invoices, approvals, property map, services catalogue, expenses, payout/reconciliation, security and reports.

**Platform administration:** subscriptions, platform revenue and onboarding. No automatic unrestricted access to resident funds or estate finances; privileged access is explicit and audited.

## 12. Security, privacy and Nigerian compliance gates

This is not legal advice. Before enabling real-money holding, withdrawal, transfers or third-party settlement, obtain written confirmation from Paystack and qualified Nigerian payments/regulatory counsel. Review applicable CBN requirements and Nigeria Data Protection Act/NDPC guidance.

Controls: data minimization; consent where required; private encrypted documents; least privilege; audited document access; encryption in transit/at rest; secrets outside source control; webhook signature/replay protection; idempotency; rate limiting; MFA/step-up for sensitive financial actions; immutable audit; reconciliation; retention/deletion rules; incident response; separate sandbox/production credentials; no production data in demos.

## 13. Conceptual domain additions — not a schema mandate

Map before creating: FinancialAccount/WalletAccount; LedgerJournal/Entry; FundingIntent/ProviderPayment; ProviderWebhookEvent; InvoicePaymentAllocation; Refund/Reversal; PayoutRequest/Approval/Execution; BeneficiaryBankAccount; SettlementBatch/ReconciliationItem; ServiceDefinition/Configuration/Purchase; IdentityVerification; HouseholdRelationship; PropertyLocationVerification.

Do not duplicate existing `EstateWallet`, `EstateWalletTransaction`, charge definitions/versions, invoice draft/settlement records, estate/property/user/membership/tenancy, visitor-pass, expense approval or audit concepts without a documented gap analysis.

## 14. API boundaries

Define final routes only after inspecting actual NestJS controllers/services. Capability groups: wallet summary/history; funding intent; provider webhook/status; wallet invoice payment; refund; treasury summary; payout request/approval/execution; charge schedule; invoice generation/allocation; service catalogue/purchase; identity verification; household management; property location submission/verification; visitor pass/gate verification.

Financial/service commands require server-side authorization, strict DTO validation, idempotency, audit events and explicit state transitions. Provider webhooks use provider-specific signature verification and are separate from user-authenticated routes.

## 15. Rollout strategy

1. Audit current wallet, transaction, invoice, settlement, finance and payment implementation.
2. Map existing models/services/routes/screens to this specification.
3. Record gaps/conflicts in a traceability matrix.
4. Confirm accounting ownership and provider/legal model.
5. Add only missing ledger/provider-event structures.
6. Implement sandbox funding and webhook replay tests.
7. Implement wallet-funded invoice payment and reconciliation.
8. Add treasury and approval controls.
9. Extend charge schedules and rent settlement.
10. Add service catalogue and provider vending.
11. Extend onboarding, household and identity verification.
12. Complete property GPS and visitor enhancements.
13. Run financial integrity, security, regression and acceptance tests.
14. Release behind estate/provider feature flags.

Never migrate existing balances without reviewed opening-balance and reconciliation procedures.

## 16. Priority

**P0 — Foundation:** source audit, provider/legal confirmation, ledger invariants, sandbox and webhook security, wallet funding/reconciliation.

**P1 — Estate payments:** resident wallet UI, wallet invoice payment, charge schedules, rent entitlement/settlement, treasury and payout controls.

**P2 — Identity/property:** self-registration, management onboarding, approvals, household, identity provider, GPS property verification.

**P3 — Services/access:** configurable catalogue, utility/airtime/data integrations, QR/PIN enhancements, fulfillment/reconciliation.

**P4 — Hardening:** statements, advanced approvals, reconciliation operations, monitoring, incident response, performance/security review.

## 17. Acceptance criteria

- Pending top-up never increases spendable balance.
- Verified provider success credits exactly once; duplicate webhooks do not duplicate.
- Wrong amount/currency/reference/recipient is rejected or quarantined.
- Every posted journal balances.
- Wallet debit and invoice allocation are atomic.
- Concurrent payments cannot overspend.
- Refunds/reversals use compensating entries and preserve history.
- Provider settlements reconcile to internal records.
- Charge applicability is previewable; recurring generation is idempotent.
- Issued invoice snapshots remain unchanged after charge edits.
- Rent is attributable to the correct landlord arrangement.
- Self-registered users remain pending until approved.
- Household dependants do not automatically receive financial privileges.
- Identity evidence is private and access audited.
- Property pins can be captured, reviewed and corrected.
- Disabled services cannot be purchased; provider fulfillment is verified.
- Expired/revoked/used visitor passes cannot be replayed.

## 18. Decisions requiring confirmation before production

1. Paystack-approved model for wallet funding, DVA assignment, refunds and payouts.
2. Regulated arrangement for resident funds and settlement.
3. Direct landlord rent settlement versus estate collection as agent.
4. Estate approval thresholds and authorized approvers.
5. KYC level and identity provider.
6. Household access rules.
7. Utility/airtime/data/water service providers.
8. Owner/tenant charge responsibility.
9. Partial payment/refund/withdrawal policy by charge type.
10. Estate timezone, billing calendar and late-fee policy.

Keep unconfirmed capabilities behind feature flags. Do not represent them as production-ready.

## 19. Relationship to existing documentation

This is the umbrella product-expansion specification. It supplements, rather than replaces, existing contracts. Follow-up amendments should be made to:
- Billing & Payments Contract: wallet funding, wallet invoice payment, ledger posting and reconciliation.
- Finance Contract: estate treasury, fund categories, payouts and approvals.
- Backend Contract: integration boundaries and authorization.
- Property Mapping Contract: GPS capture and verification.
- Visitor Security Contract: QR/PIN lifecycle.
- Management Build Documentation: new role workflows.
- Implementation Plan: phased tasks and dependencies.

Do not overwrite existing contracts wholesale. Keep this as the source for expanded product requirements and amend individual contracts only where needed.

## Appendix A — Resident service shortcuts

Core: Wallet/Add Money, Pay Levies, House Rent, Transaction History, Visitor Pass, Notifications.

Optional: Electricity, Airtime, Mobile Data, Water, Waste, Facility Booking, Maintenance, Incident/Emergency, Documents/Receipts, approved Marketplace.

## Appendix B — Suggested documentation directory

```text
docs/
  product-expansion/
    00_README_AND_DOCUMENT_CONTROL.md
    01_FINTECH_ESTATE_PRODUCT_EXPANSION_SPECIFICATION.md
    02_WALLET_AND_LEDGER_DESIGN.md
    03_PAYSTACK_AND_SETTLEMENT_INTEGRATION.md
    04_BILLING_RENT_AND_LEVY_RULES.md
    05_IDENTITY_HOUSEHOLD_AND_ONBOARDING.md
    06_PROPERTY_GPS_AND_VERIFICATION.md
    07_SERVICE_CATALOGUE_AND_VENDING.md
    08_TREASURY_APPROVALS_AND_RECONCILIATION.md
    09_SECURITY_PRIVACY_AND_COMPLIANCE.md
    10_IMPLEMENTATION_TRACEABILITY_MATRIX.md
```

The umbrella document is v1.0. Create detailed subdocuments only when each workstream is ready, to avoid delaying active implementation.

## Appendix C — Change control

Changes to financial ownership, wallet behavior, provider settlement, rent destination, identity data collection or authorization must be recorded as dated decisions. Link every requirement to its backend capability, Flutter screen, migration (if any), tests and release status.

**End of document.**
