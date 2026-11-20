# 10 — Implementation Traceability Matrix

Date: 20 November 2026. Status legend: **LIVE** = deployed and verified; **DEMO** = live but labelled demo data; **GAP** = not implemented; **DEFERRED** = intentionally postponed pending confirmation.

| Spec requirement | Backend capability | Flutter screen / entry | Migration | Tests | Status |
| --- | --- | --- | --- | --- | --- |
| §4 Double-entry ledger | `LedgerService.post/reverse`, `LedgerJournal/Entry` | statements UI on manager dashboard | ledger migration | `ledger.test.js` | LIVE |
| §4 Resident wallet balance, Add Money, history | `EstateWallet`, funding intents, demo credit | `main.dart` → `ResidentHomeApiPage` (dark hero) | wallet migrations | `money.integration.test.js` | DEMO |
| §4 Wallet invoice payment | `pay-rent`, `pay-rent-schedule` | resident Pay Bills / House Rent tiles | — | `money.integration.test.js` | DEMO |
| §5 Paystack funding/webhook | `wallets.service.ts`, `ProviderWebhookEvent` | — | webhook migration | `money.integration.test.js` | DEFERRED |
| §6 Charge applicability preview | `GET .../charges/versions/:id/applicability` | manager dashboard | charge migrations | `levies.test.js` | LIVE |
| §6 Deterministic recurring invoices | `POST .../charges/recurring/generate` | manager Recurring levies card | invoice migration | `levies.test.js` | LIVE |
| §6 Rent schedules, landlord entitlement | `RentService`, `RentPayment` | resident House Rent, manager rent card | `20261120120000_rent_schedules` | `rent.test.js` | LIVE |
| §7 Registration approval | resident join-request routes | `resident_join_main.dart`, `resident_review_main.dart` | `20261114010000_resident_join_workflow` | `domain.test.js` | LIVE |
| §7 Household members | `HouseholdService` | resident Household, manager review card | `20261121130000_household_members` | `household.test.js` | LIVE |
| §7 Identity verification | `IdentityService` | resident demo declaration, manager review | `20261121150000_identity_verifications` | `identity.test.js` | DEMO |
| §8 Property GPS | `PropertyLocationService` | manager Property GPS card | `20261121140000_property_location_verification` | `property-location.test.js` | LIVE |
| §9 Services catalogue/vending | `EstateServicesService` | both dashboards' Quick Services grid | `20261121160000_services_catalogue` | `services.test.js` | DEMO |
| §10 Visitor QR/PIN | gate security + visitor passes | `security_main.dart`, resident Gate Pass tile | visitor-pass migrations | `domain.test.js` | LIVE |
| §11 Resident dashboard | wallet summary endpoints | `main.dart` → `ResidentHomeApiPage` | — | — | LIVE |
| §11 Estate management dashboard | treasury, invoices, audit, services | `admin_main.dart` → `EstateManagerDashboardApiPage` | — | — | LIVE |
| §11 Landlord dashboard | `loadLandlordPortfolio`, rent schedule | `landlord_portal_main.dart` → `LandlordPortfolioApiPage` | — | — | LIVE |
| §12 Rate limiting | `RateLimitGuard` in local + Vercel bootstrap | — | — | `hardening.test.js` | LIVE |
| §12 Audit query | `GET .../audit` with CSV | manager Statements & audit trail card | — | `hardening.test.js` | LIVE |
| §12 Statements | `GET .../statements/wallet|ledger` | manager dashboard | — | `hardening.test.js` | LIVE |
| §12 MFA/step-up | — | — | — | — | DEFERRED |
| §8 Map with verified pins | property locations API | resident map still schematic | — | — | GAP |
| §9 Real utility/airtime/data vending | — | — | — | — | DEFERRED |
| §5 Real Paystack activation | — | — | — | — | DEFERRED |

## Dashboard restructure (this release)

All three role dashboards now use `client/lib/core/design/dashboard_design.dart`: dark canvas, greeting header, a deep-green hero card with three white actions, a 12-tile Quick Services grid and sectioned lists. The reference image is retained at `docs/product-expansion/reference-resident-dashboard.jpg`.

## Browser cache fix (20 November 2026)

The API client now sends `Cache-Control: no-store` and the backend sets the same header on `/api/v1` responses (both local bootstrap and Vercel wrapper). Without this, repeated browser loads received `304 Not Modified` with an empty body, which the client treated as an error and left dashboards stuck on the loading indicator. Verified against live dashboard reloads.

## Dated decisions

- 20 Nov 2026 — Paystack deferred to final rollout step; `FINANCIAL_DEMO_MODE=true` remains hosted.
- 20 Nov 2026 — Identity evidence stored as provider references only; no documents or biometrics retained.
- 20 Nov 2026 — Dashboard visual language standardized across resident, estate management and landlord roles.
