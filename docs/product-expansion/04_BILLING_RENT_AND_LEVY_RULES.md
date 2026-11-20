# 04 — Billing, Rent and Levy Rules

Status: implemented.

## Charges and levies

`EstateChargeDefinition` → versioned `EstateChargeVersion` (amount, currency, recurrence, effective dates, due day, grace days, scope ESTATE/PROPERTY/PROPERTY_TYPE). `EstateInvoiceDraft` carries an immutable snapshot and follows `DRAFT → ISSUED → PARTIALLY_PAID → PAID`; overdue is derived from due date and balance.

- `GET .../charges/versions/:versionId/applicability` previews targeted properties and payers with relationship reasons before activation.
- `GET .../charges/recurring/preview` shows deterministic calendar periods and recipient counts.
- `POST .../charges/recurring/generate` creates and issues invoices with deterministic idempotency keys. Replay returns the same invoices; a manually created invoice for the same business tuple is treated as a replay. No issued invoice is rewritten.

## Rent

`RentSchedule` is generated from `ACTIVE` tenancies (`MONTHLY`, `QUARTERLY`, `ANNUALLY`) with deterministic idempotency keys. `RentPayment` records receipts. `GET .../rent/landlord-summary` reports entitlement, collected and outstanding by payee. Rent never enters estate treasury: payments post to `LANDLORD_PAYABLE:<userId>`.

## Routes

`POST|GET /api/v1/estate/estates/:estateId/rent/generate|schedule|landlord-summary`, `POST /api/v1/estate/wallets/pay-rent-schedule`, `GET|POST /api/v1/estate/estates/:estateId/charges`, `GET .../charges/recurring/preview`, `POST .../charges/recurring/generate`.

## Tests

`backend/tests/rent.test.js`, `levies.test.js`.
