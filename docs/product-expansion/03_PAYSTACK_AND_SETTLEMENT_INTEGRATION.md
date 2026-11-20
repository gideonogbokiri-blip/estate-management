# 03 — Paystack and Settlement Integration

Status: **deferred intentionally**; Paystack is the final rollout step.

## Current hosted configuration

`FINANCIAL_DEMO_MODE=true`, no `PAYSTACK_SECRET_KEY`. Funding, payments and payouts are labelled `DEMO-…` and post only to internal ledger accounts.

## Required before real mode

1. Written confirmation of the approved merchant/product arrangement, DVA suitability, funding and payout channels, settlement timing, fees/limits, refunds/reversals, webhook events and signature rules.
2. KYC/KYB and subaccount/split-settlement requirements.
3. Nigerian regulatory/counsel confirmation for holding, refunds, payouts and the closed-loop wallet model.
4. `FINANCIAL_DEMO_MODE=false` plus `PAYSTACK_SECRET_KEY`, webhook registration and separate sandbox/production credentials.

## Boundary

Paystack is a processor, not the LANCON ledger. The backend remains responsible for eligibility, ownership, posting, allocation, audit and reconciliation. A browser redirect or client assertion is never proof of payment. Webhooks are idempotent and replay-safe; unknown or mismatched amount/currency/reference/status is rejected or quarantined.

## Existing integration points

- `backend/src/properties/wallets.service.ts` — DVA provision, funding intents, webhook verification, demo credit.
- `backend/src/properties/payouts.service.ts` — beneficiary verification, threshold approvals, demo/real execution.
- `GET /api/v1/estate/estates/:estateId/treasury/summary` — exposes `reconciliationExceptions` from quarantined provider events.
