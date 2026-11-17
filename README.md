# Estate Management

A local-first estate operations product with separate web apps for onboarding, platform review, estate management, residents, gate security and landlords.

## Start here

- **Local preview:** open `http://127.0.0.1:8765/` after starting the API and preview server.
- **Demo accounts and walkthrough:** `FLUTTER_PREVIEW_RECOVERY.md` and the project hub.
- **Hosting on GitHub + Vercel:** `HOSTING_GUIDE.md`.
- **Containers / production baseline:** `DEPLOYMENT.md`.

## Repository layout

| Path | Purpose |
|---|---|
| `backend/` | NestJS API, Prisma schema and migrations, demo seed commands |
| `client/lib/` | Flutter source for all entry points |
| `client/build/` | Prebuilt web bundles served by Vercel or the local preview server |
| `api/` | Vercel serverless wrapper around the NestJS API |
| `estate-dashboard/` | Static HTML design preview (illustrative data, not the live app) |
| `scripts/` | Web bundle build and hosting configuration helpers |

## Status

This is a working local presentation build covering estate onboarding, platform review, estate operations, resident workflows and gate security. Payment provider integration, outbound notification delivery, account recovery and several preview-only screens are still out of scope. Do not describe it as production-ready.
