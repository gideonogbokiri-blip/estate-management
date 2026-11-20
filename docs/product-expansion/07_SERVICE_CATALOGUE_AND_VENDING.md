# 07 — Service Catalogue and Vending

Status: implemented in demo mode; real aggregator deferred.

`EstateServiceDefinition` stores code, name, description, category, provider, price, currency, demo flag and ACTIVE/INACTIVE state. `EstateServiceOrder` stores the server-priced amount, status, provider reference, fulfilment code, idempotency hash and payload hash.

Residents order from their fund account. The server re-reads the active price, locks the wallet row, recomputes the balance, posts a balanced journal to `PROVIDER_CLEARING:<provider>:<currency>`, records the wallet debit and fulfils immediately with a `DEMO-VOUCHER-…` code. Duplicate idempotency keys replay the same order; provider vending, input validation, quote/fees, fulfillment verification and reconciliation require an approved aggregator and remain unconfirmed. Core account and security capabilities are not part of optional service configuration.

Routes: `GET|POST /api/v1/estate/estates/:estateId/services`, `PATCH .../services/:serviceId/status`, `GET .../services/orders`, `POST .../services/:serviceId/orders` (requires `Idempotency-Key`). The resident and manager dashboards expose these as the 12-tile Quick Services grid.

Tests: `backend/tests/services.test.js`.
