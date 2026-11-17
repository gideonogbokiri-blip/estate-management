# Hosting guide (GitHub + Vercel)

## Current deployment status (17 November 2026)

Already done for you:

- GitHub repository: https://github.com/gideonogbokiri-blip/estate-management
- Vercel project: `zarox-energy/estate-management`, connected to the GitHub repo
- Environment variables `ACCESS_TOKEN_SECRET` and a placeholder `DATABASE_URL` (needed only so Prisma can generate its client during build)
- A Git-triggered production deployment is running (check with `vercel ls`)

**Two steps still need your browser login/approval:**

1. Accept the Neon marketplace terms, then I can create the hosted database:
   https://vercel.com/zarox-energy/~/integrations/accept-terms/neon?source=cli
2. Create a Vercel Blob store for private documents in the Vercel dashboard (Storage → Blob → Create Store). It automatically adds `BLOB_READ_WRITE_TOKEN`.

After you do those, tell me and I will finish the database setup, migrations, demo seeding, environment variables and a final deployment.

This project has three moving parts. That is why it feels "separated":

| Part | What it is | Where it goes |
|---|---|---|
| Website | 12 prebuilt Flutter web bundles + the project hub | Vercel (static files in `client/build`) |
| API | NestJS backend in `backend/` | Vercel serverless function in `api/` |
| Data | PostgreSQL + private upload files | Neon (database) + Vercel Blob (files) |

You do **not** need Docker for this option. `docker-compose.yml` is still there if you prefer hosting on a VPS later.

---

## Step 1 — Create the database (Neon)

1. Sign up at https://neon.tech and create a project.
2. Copy the **connection string** (it looks like `postgresql://user:pass@host.neon.tech/neondb?sslmode=require`).
3. Keep it private. Never paste it into a GitHub issue or commit it.

## Step 2 — Put the code on GitHub

In a PowerShell terminal, from the project folder:

```powershell
git init
git add .
git commit -m "Estate management app"
git branch -M main
git remote add origin https://github.com/YOUR-USERNAME/YOUR-REPO.git
git push -u origin main
```

Before committing, double-check that no secret is tracked:

```powershell
git status --short | Select-String "\.env"
```

If that prints anything, stop and remove it. `backend/.env` is ignored by `.gitignore`; it will stay on your computer only.

Create the GitHub repo first on github.com (empty, no README) and use its URL in the `git remote add` command.

## Step 3 — Import into Vercel

1. Go to https://vercel.com → **Add New → Project** → import your GitHub repo.
2. Framework preset: **Other**. Root directory: leave as the repository root.
3. Add these environment variables in Vercel (Project → Settings → Environment Variables):

| Name | Value |
|---|---|
| `DATABASE_URL` | The Neon connection string from Step 1 |
| `ACCESS_TOKEN_SECRET` | A random string of at least 32 characters |
| `APP_ORIGINS` | Your Vercel URL, e.g. `https://estate-app.vercel.app` |
| `BLOB_READ_WRITE_TOKEN` | Created in Step 4 |

4. Click **Deploy**. The build command comes from `vercel.json`; it installs backend dependencies and compiles the API automatically. The website is served from `client/build`.

## Step 4 — Private upload storage (Vercel Blob)

In your Vercel project: **Storage → Blob → Create Store**. Vercel automatically adds `BLOB_READ_WRITE_TOKEN` to the project's environment variables. Redeploy once after adding it.

Without this token, document uploads will fail on Vercel (the API still works for everything else).

## Step 5 — Prepare the database (run once from your computer)

Migrations and demo seeding are operator commands, not part of the web build. From the project folder:

```powershell
cd backend
$env:DATABASE_URL = 'postgresql://...your Neon URL...'
npm.cmd ci
npx.cmd prisma migrate deploy
npm.cmd run build
npm.cmd run seed:demo -- --confirm-local-demo --allow-remote-demo-seed
npm.cmd run seed:walkthrough-accounts -- --confirm-walkthrough-accounts --allow-remote-demo-seed
npm.cmd run seed:gate-demo -- --confirm-local-gate-demo
```

`seed:demo` prints the generated manager and resident passwords — save them. The walkthrough accounts command creates the applicant, platform reviewer and security officer with the documented demo passwords.

## Step 6 — Verify

Open these URLs:

- `https://your-app.vercel.app/` — project hub
- `https://your-app.vercel.app/api/v1/health/ready` — should return `{"status":"ready",...}`
- `https://your-app.vercel.app/onboarding/`, `/platform/`, `/admin/`, `/web/`, `/security/`

Sign in with the demo accounts from the hub. If sign-in fails, check the Vercel **Functions** log and confirm `DATABASE_URL`, `ACCESS_TOKEN_SECRET` and `APP_ORIGINS` are set for **Production**.

---

## How local development still works

Nothing about local hosting changed. The prebuilt bundles fall back to `http://127.0.0.1:4100/api/v1` when the runtime override is absent, so the local preview server and local API still work exactly as before.

If you change Dart code, rebuild all bundles before pushing:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\scripts\build-for-hosting.ps1
git add client/build
git commit -m "Rebuild web bundles"
git push
```

## Things to know

- Vercel functions have a 30-second timeout (set in `vercel.json`). All current endpoints are short-lived.
- The API is still HTTP-only at the platform level, but Vercel terminates TLS for you, so the public site is HTTPS.
- Do not commit `backend/.env`, Neon credentials, or Blob tokens.
- This is still a demo deployment. Payment provider, account recovery and outbound notifications remain unimplemented regardless of where you host.
