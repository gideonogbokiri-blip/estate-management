# 12 — Terra Crest Redesign

Date: 26 November 2026

## Source

Two user-supplied mockups (desktop + mobile) for the resident home. They define the target visual language for every role dashboard and service page.

## Visual language

- **Background:** warm cream `#F6F3ED`; surfaces `#FDFBF7`, muted tiles `#F1EDE4`, pale sage `#E9F0E5`.
- **Primary:** deep forest green `#1F5C3A`; ink `#1E2A22`; muted `#7C857A`; amber `#B8873B`; danger `#B44A3E`.
- **Type:** serif (Georgia) for display headings and large amounts; sans-serif for labels and body. Small uppercase labels with wide letter spacing.
- **Shape:** 18px cards, 14px tiles, 12px buttons, soft borders `#E6E0D4`, no shadows.

## Shared implementation

- `client/lib/core/design/terra_theme.dart` — `TerraTheme.light()`, `TerraColors`, `TerraCard`, `TerraBadge`, `TerraLabel`, `TerraSectionTitle`, `TerraMetric`, `TerraEmpty`, `TerraQuickServicesGrid`.
- `client/lib/core/design/terra_shell.dart` — `TerraTopBar`, `TerraStatus`, `TerraWalletCard`, `TerraWalletAction`, `TerraServiceTile`.
- `client/lib/core/design/service_page_scaffold.dart` — light Terra shell for all service pages.

## Resident home

Matches the mockups: top status bar, profile greeting card, deep-green wallet card with Add Money / Pay Bills / History, 12-tile Quick Services grid, Outstanding Payments with Pay Now, and the right-hand Terminal Gateway Login, Housing Archetype Telemetry and Multi-Gen Kinship Status cards. Mobile uses a Home / Access / Services / Kinship bottom bar.

## Rebranding

The live demo estate is now **Terra Crest** (Emerald Living Sanctuary, Cluster Alpha-A); primary resident **Dr. Funke Adeyemi**, property **A-104 / Villa Lotus 12**, wallet **₦125,000.00** in a GTBank escrow account. Applied by `npm run seed:terra-crest -- --confirm-terra-crest --allow-remote-demo-seed`.

## Estate Chairman role

An `ESTATE_CHAIRMAN` role was added as the distinct payout approver. The chairman account is `chairman@testlancon.com` / `lancon123`; the previous demo approver account is now an estate administrator so initiation and approval are held by different people. Only `ESTATE_CHAIRMAN` can decide a payout. The single sign-in page routes this role to `/admin/`.

## Demo-data policy

Per the user's decision: keep the simulated funding/payment flows working, but remove demo-only wording from the UI. No "DEMO MODE" badges, no `DEMO-…` voucher text, no "demo service" suffixes. Paystack activation remains the final step and is unchanged.
