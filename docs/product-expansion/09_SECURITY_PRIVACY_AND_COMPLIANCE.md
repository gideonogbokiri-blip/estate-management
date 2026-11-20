# 09 — Security, Privacy and Compliance

Status: baseline implemented; production compliance gates outstanding.

## Implemented controls

- Strict CORS from exact `APP_ORIGINS`; helmet; global `ValidationPipe` with whitelist, forbidNonWhitelisted and transform.
- JWT access/refresh sessions; role and relationship scope resolved server-side on every mutation.
- Server-authoritative, transactional, idempotent and audited financial/service mutations.
- Webhook signature verification and replay protection; `SERIALIZABLE` transactions and row locks for balance checks.
- Immutable posted ledger entries with compensating reversals.
- Private document storage (Vercel Blob private when configured); identity evidence is not stored at all.
- Baseline per-instance rate limiting; health checks; structured request logs; per-request audit events.
- Secrets read from environment only; no production data in demo flows.

## Deferred / unconfirmed

- MFA/step-up for sensitive financial actions.
- Distributed rate limiting and shared secrets manager.
- Monitoring, alerting, log aggregation and incident/on-call SLAs.
- Legal confirmation: Paystack arrangement, CBN requirements, NDPA/NDPC guidance, KYC level, fund-holding model.

All deferred capabilities are feature-flagged or explicitly documented in `00_README_AND_DOCUMENT_CONTROL.md`.
