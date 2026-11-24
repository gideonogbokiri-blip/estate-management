# 11 — Client Architecture (LANCON estate fintech bank)

Date: 24 November 2026

## Target layout

```
client/lib/
├── core/
│   ├── config/        API base URL, shared session, downloads
│   ├── design/        dashboard design system, service page shell
│   ├── errors/        API error -> user message mapping
│   ├── navigation/    central AppNavigation + AppRoute registry
│   ├── theme/         EstateTheme / EstateColors
│   └── utils/         shared money/date formatters
├── data/
│   ├── api.dart       single public API surface
│   └── models/        domain model barrels (wallet, billing, rent, ...)
├── app/               MaterialApp entry points and shells only
├── features/
│   ├── access/  billing/  documents/  facilities/  identity/
│   ├── maintenance/  property/  rent/  safety/  services/
│   ├── treasury/  wallet/     (domain barrels)
│   ├── services/presentation/  resident service pages (12)
│   ├── landlord/presentation/  landlord service pages (12)
│   ├── admin/presentation/     manager service pages + dashboards
│   ├── resident/presentation/  resident dashboard + shared pages
│   └── ...
└── features.dart      feature registry
```

## Rules

1. **One public data surface.** Feature code imports `package:zvend_estate_app/data/api.dart` or a domain barrel, never the monolithic client file directly.
2. **One navigation path.** Pages are pushed through `AppNavigation.push`. `AppRoute` holds stable route identifiers for future deep links.
3. **One visual language.** All role dashboards and service pages use `DashboardTokens`, `DashboardHero`, `DashboardQuickServices` and `ServicePageScaffold`.
4. **One formatting rule.** Money and dates come from `AppFormat`; no local copies.
5. **Domain boundaries.** A feature owns its pages and exposes a barrel. Cross-feature imports go through barrels, not deep paths.

## Migration status

- DONE: central navigation, route registry, domain model barrels, feature barrels, shared formatters and error mapping. Resident, landlord and manager dashboards import through the data barrel.
- DONE: every Quick Services tile opens a dedicated page (resident 12, landlord 12, manager 3 replacing stubs).
- REMAINING: split the large dashboard files into feature-local section widgets; move the model class bodies out of the legacy client file into `data/models/` (barrels currently re-export them); isolate preview-only repositories under `features/preview/`.

These remaining items are refactors with no API or behaviour change and are tracked in `10_IMPLEMENTATION_TRACEABILITY_MATRIX.md`.

## Backend shape

The NestJS backend is already module-oriented (`auth`, `properties`, `platform-applications`, `private-documents`, `notifications`, `health`). The `properties` module is the largest and still contains wallet, ledger, billing, rent, treasury, identity, property, services and access concerns together. Its next refactor is to split those into feature modules behind a shared `common/` layer (guards, pagination, idempotency, audit helpers) while keeping every existing route path unchanged for backward compatibility. No provider/legal behaviour changes are part of that refactor.
