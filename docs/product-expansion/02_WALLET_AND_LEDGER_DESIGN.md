# 02 — Wallet and Ledger Design

Status: implemented in demo mode; real provider activation deferred.

## Authoritative structures

- `EstateWallet`, `EstateWalletTransaction` — existing concepts, extended (not replaced).
- `LedgerJournal`, `LedgerEntry` — one double-entry ledger; balanced postings only.
- `WalletFundingIntent`, `ProviderWebhookEvent` — funding intent and replay-safe provider events.

`LedgerService.post()` is the only posting path. It rejects unbalanced or same-account instructions, records `sourceType`/`sourceId`, currency, actor and timestamp, and supports compensating reversals via `reverse()`. Wallet balances are derived from posted `EstateWalletTransaction` rows; no editable balance field exists.

Account codes: `WALLET:<id>`, `ESTATE_COLLECTION:<estate>:<currency>`, `INVOICE_RECEIVABLE:<id>`, `LANDLORD_PAYABLE:<userId>`, `PROVIDER_CLEARING:<provider>:<currency>`.

## Funding

`POST /api/v1/estate/wallets/funding-intents` creates a unique, idempotency-keyed intent. In demo mode `POST /api/v1/estate/wallets/demo-credit` posts the balanced funding journal and marks the intent completed. A pending intent never increases spendable balance. Provider webhook handling (`POST /api/v1/payments/paystack/webhook`) validates signature, replay, amount, currency, recipient and status before posting exactly once.

## Payments

- `POST /api/v1/estate/wallets/pay-rent` — wallet debit + collection credit + invoice allocation in one `SERIALIZABLE` transaction; a row lock and balance recomputation prevent overspend.
- `POST /api/v1/estate/wallets/pay-rent-schedule` — rent payment to `LANDLORD_PAYABLE`, separate from estate levies.
- `POST /api/v1/estate/estates/:estateId/services/:serviceId/orders` — wallet-funded service order, idempotent, ledger-posted.

## Acceptance evidence

`backend/tests/ledger.test.js`, `money.integration.test.js`, `services.test.js` cover balanced postings, reversals, idempotency and insufficient-balance rejection.
