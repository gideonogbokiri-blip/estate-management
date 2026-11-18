# Deployment baseline

This repository now has a repeatable build/CI baseline and a local container stack. It is still a **local presentation build**, not a hardened production deployment. Read the gaps at the end before exposing it to real users.

## Automated checks

```powershell
# From backend/ — pure domain tests plus API integration (skipped by default)
npm test

# Run the live API workflow against a running API on 127.0.0.1:4100.
# The walkthrough gate data must be pristine first:
node dist/src/cli/seed-gate-demo.js --confirm-local-gate-demo --reset
$env:RUN_API_INTEGRATION = '1'
npm run test:integration
```

CI (`.github/workflows/ci.yml`) runs the backend tests/build and Flutter analysis plus all web bundle builds on every push and pull request. It does not run the live integration test, because that needs a database and seeded gate data.

## Container stack

```powershell
# Build the Flutter web bundles first (see FLUTTER_PREVIEW_RECOVERY.md).
# Then, from the repository root:
docker compose --env-file backend/.env up -d --build
```

- `postgres` persists data in the `pgdata` volume and listens on host port 5434.
- `api` applies migrations on start, serves HTTP on port 4100, and stores private uploads in the `privatedocs` volume.
- `web` serves `client/build` with nginx on port 8765; `nginx.conf` maps each Flutter bundle to its route and proxies `/api/` to the API.

Required environment values: `POSTGRES_PASSWORD`, `ACCESS_TOKEN_SECRET` (at least 32 random bytes), and `APP_ORIGINS` (exact public origins only). Generate a secret with a password manager or `openssl rand -base64 48`; never reuse the local demo secret.

## Notifications and account lifecycle

- In-app notices are written transactionally with their source events. Each notice also creates an outbound delivery record.
- `npm run notifications:deliver` processes pending deliveries. With `SMTP_HOST` and `SMTP_FROM` configured it sends email through SMTP; without them it records `skipped / smtp_not_configured` so the queue does not grow silently. Push and SMS are not implemented.
- Account lifecycle uses operator-issued, single-use codes valid for 30 minutes. `npm run accounts:issue-code -- <email> password_reset` (or `email_verification`) prints a code once; it is stored only as a hash. The account holder uses `/recover/` or `POST /auth/confirm-recovery`. Password reset revokes existing sessions; email verification stamps `emailVerifiedAt`. All actions are audited. Platform super admins can also issue codes via `POST /auth/accounts/:userId/recovery-codes`.

## Backups and diagnostics

- Run `powershell.exe -ExecutionPolicy Bypass -File .\scripts\backup-database.ps1` from the repo root to create a timestamped custom-format Postgres dump in `backups/` (gitignored). Requires `pg_dump` on the PATH and `DATABASE_URL`/`POSTGRES_PASSWORD` in `backend/.env`.
- Both the local and serverless API entry points log one structured line per request with method, path, status and duration. `/api/v1/health/ready` checks the database dependency.

## Production gaps that remain

1. **TLS** — the stack terminates plain HTTP. Put a TLS reverse proxy or load balancer in front and set `APP_ORIGINS` to the HTTPS origin before real use.
2. **Secrets** — `.env` files are convenient for a local demo only. Use a secret manager in any shared environment.
3. **Backups and restore** — the Postgres volume is persistent but there is no automated backup, restore drill, or point-in-time recovery.
4. **Observability** — API logs go to stdout; there is no structured logging, metrics, tracing, or alerting.
5. **Account lifecycle** — no email verification, password reset, or account recovery flow.
6. **Delivery integrations** — notifications are in-app only; no push, email, or SMS adapter exists.
7. **Payments** — manual bank-transfer reconciliation is supported; there is no payment provider, automated allocation, or receipt document.
8. **Illustrative screens** — the estate map, legacy landlord preview, older admin-shell actions, and platform plan catalog remain labelled previews. Plan pricing and limits must be configured before the Plans tab can be connected.

Closing items 1–5 is the minimum bar for a trusted internal pilot. Items 6–8 are product work and need credentials and product decisions before implementation.
