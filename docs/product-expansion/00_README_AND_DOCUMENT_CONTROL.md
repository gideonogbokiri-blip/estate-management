# LANCON Product Expansion — Document Control

**Document ID:** LANCON-PROD-EXP-001-README
**Version:** 1.0
**Date:** 20 November 2026
**Source:** `LANCON_Product_Expansion_Documents_v1.0/LANCON_Fintech_Estate_Product_Expansion_Specification_v1.0.md`

This directory is the authoritative product-expansion documentation set. The umbrella specification (document 01) is the source of product requirements; the numbered subdocuments record how each workstream is implemented in this repository. These documents supplement, and do not replace, the existing contracts in the repository root.

## Before production

The following are explicitly unconfirmed and must stay behind feature flags:
- Paystack merchant/DVA/refund/payout arrangement and Nigerian regulatory sign-off.
- KYC level and identity provider.
- Utility/airtime/data/water providers.
- Direct landlord rent settlement versus estate collection as agent.
- Approval thresholds, household access rules, owner/tenant charge responsibility, billing calendar and refund policy.

Financial demo mode (`FINANCIAL_DEMO_MODE=true`) is the current hosted setting. All demo balances, vouchers and payouts are labelled and are not real money.

## Dashboard structure

The three role dashboards follow the reference screen at `docs/product-expansion/reference-resident-dashboard.jpg`:

| Element | Resident | Estate management | Landlord |
| --- | --- | --- | --- |
| Greeting header | Welcome, Resident + estate/property | Welcome, Manager + estate | Welcome, Landlord + estate |
| Hero card | MY WALLET BALANCE + Add Money / Pay Bills / History | ESTATE COLLECTIONS + Record expense / Approvals / Generate levies | RENT ENTITLEMENT + Rent schedule / Receipts / Statements |
| 12-tile quick services | Levies, Rent, utilities, gate pass, maintenance, documents | Properties, residents, tenancies, levies, payouts, expenses, map, services, security, notices, staff, settings | Portfolio, occupancy, tenancies, rent, arrears, receipts, statements, maintenance, documents, notices, safety, more |
| Lists below grid | Outstanding Payments | Treasury, approvals, reconciliation, audit trail | Properties, maintenance |

Shared implementation: `client/lib/core/design/dashboard_design.dart`.

## Document index

- `01_FINTECH_ESTATE_PRODUCT_EXPANSION_SPECIFICATION.md` — umbrella specification (v1.0).
- `02_WALLET_AND_LEDGER_DESIGN.md` — wallet, ledger and demo funding.
- `03_PAYSTACK_AND_SETTLEMENT_INTEGRATION.md` — provider boundary and deferred activation.
- `04_BILLING_RENT_AND_LEVY_RULES.md` — charges, invoices, rent and levies.
- `05_IDENTITY_HOUSEHOLD_AND_ONBOARDING.md` — join requests, household, identity.
- `06_PROPERTY_GPS_AND_VERIFICATION.md` — pin capture and verification.
- `07_SERVICE_CATALOGUE_AND_VENDING.md` — services and demo fulfilment.
- `08_TREASURY_APPROVALS_AND_RECONCILIATION.md` — treasury, payouts, statements.
- `09_SECURITY_PRIVACY_AND_COMPLIANCE.md` — controls and compliance gates.
- `10_IMPLEMENTATION_TRACEABILITY_MATRIX.md` — requirement → code → test → release status.

## Change control

Changes to financial ownership, wallet behaviour, provider settlement, rent destination, identity data collection or authorisation must be recorded here as dated decisions with a link to the relevant backend capability, Flutter screen, migration, tests and release status.
