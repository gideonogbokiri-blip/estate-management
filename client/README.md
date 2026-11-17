# Estate Management Flutter client

This Flutter client is the resident mobile experience and responsive administration app for the standalone estate-management product. The main resident entry connects account sign-in, estate membership, access requests, current tenancy terms and resident maintenance requests to this workspace's API. Applicant onboarding, resident-access review, property registration, ownership management and tenancy management also use the API. The landlord portal reads estates, verified properties, occupancy and current tenancy terms from that API. Other resident and admin modules are staged previews while their product services are built.

For local development, start this product's API in `../backend`. The main resident app is `flutter run -d chrome -t lib/main.dart --web-port 8765 --dart-define=API_BASE_URL=http://127.0.0.1:4100/api/v1`; onboarding with `lib/onboarding_main.dart`; resident access review with `lib/resident_review_main.dart`; resident estate search/request with `lib/resident_join_main.dart`; tenant rent terms with `lib/tenant_rent_main.dart`; property, ownership and tenancy management with `lib/property_register_main.dart`; and landlord portfolio with `lib/landlord_portal_main.dart`. Use a separate web port for each target and the same API define. Browser tokens stay in memory; native builds use secure storage. Ownership evidence and tenancy agreements are currently not uploaded; payment tracking, automated tenancy expiry, applicant notifications and the platform initial-administrator picker remain outstanding.

## Current screen structure

- Home overview, outstanding-balance summary, estate activity and shortcuts
- Resident maintenance request form and history use the maintenance API in the main resident app; other maintenance views are still staged previews
- Resident visitor pass history with credential-free pass summaries
- Resident My Property view with property identity and authorized ownership/household relationship summaries
- Resident estate charge rules filtered to those applicable to the current property, kept distinct from invoices and balances
- Resident My Rent summary for an authorized active tenancy, with terms separated from invoice and verified payment history
- Resident estate map schematic with authorized place layers, location-confidence labels, unmapped-place visibility and no device-location tracking
- Facility catalogue and resident booking history
- Estate notices feed scoped to the resident audience
- Invoice history with balances, verified payment summaries and receipt references
- Account and estate context summary
- Estate manager dashboard with live estate summary counts and API-backed maintenance queue review, assignment, resident updates and internal notes
- Estate property register with search, occupancy and operational-status filters, plus permission-aware relationship details
- API-backed property ownership workflow: estate managers add owner accounts and ownership shares, then verify/reject pending records with an audited reason; evidence source is recorded as a note until private document upload is implemented
- Expandable estate structure tree for zones, streets, buildings and floors, with an archived-node filter and session-local add, edit and guarded archive previews
- Resident membership review queue with status/relationship filters, applicant search, privacy-safe evidence metadata and API-backed approve/reject decisions
- Finance budget overview and searchable expense queue with verified payment summaries
- Facility booking review queue with resident/property context, capacity and fee summaries, policy version and separate verified payment state
- Security incident queue using estate-scoped safe incident summaries, including priority; investigation details and attachments remain behind the authorized service
- Estate team directory with active, invited and suspended membership states and delegated-role labels; access changes await the estate membership API
- Estate tenancy register with property, tenant, rent, term and next-due summaries, plus search and lifecycle filters; sample rows follow the backend's actor-authorized list projection
- Landlord portfolio screen connected to verified ownership, current occupancy and active tenancy terms from the backend; rent collection remains separate until billing services are implemented
- Estate invoice register with payer/property context, status/search/dispute filters, due dates, totals and balances sourced from the safe invoice read model
- Rent management schedule view derived from active approved tenancy terms, with next-due filters and missing-date visibility; invoice generation remains behind the idempotent billing service
- Administrative charge register showing category, recurrence, amount, applicability, due rules and effective dates; changes stay disabled until the versioned charge service is implemented
- Estate settings summary for operational identity, address, timezone and currency, with clear boundaries for platform subscription, payment destination and private estate documents
- Estate announcements workspace with an audience/channel composer, emergency permission context, and a published/scheduled/draft timeline; dispatch controls await the estate notification service
- Reports and analytics overview from dashboard section availability, as-of time and source freshness; no unavailable totals or historic trends are fabricated
- Finance and expenses page with budget commitments, verified paid totals, expense filtering and safe request details; approval and payment remain unavailable until the host services are connected
- Responsive estate admin navigation for the 18 modules listed in the product brief; module visibility comes from `availableSections`, and modules without a connected service are marked unavailable in this preview
- Separate platform operations dashboard for the estate application review queue
- Applicant-facing estate onboarding form for estate/location, applicant/management contact and property structure, connected to this product's API
- Estate manager resident-access review with estate selection, persisted request queue, and audited approve/reject decisions
- Resident estate search, optional property/relationship selection, persisted access requests, and personal request history
- Separate responsive landlord portal with verified properties, current tenancy terms, relationship-scoped rent invoices and property charge invoice summaries derived from verified allocations
- Landlord property document library with property/category filters and safe metadata; opening content remains behind the existing short-lived private-file access service

`ResidentEstateRepository` still supplies the broader staged `ResidentShell` modules. The main resident entry uses `EstateApplicationApiClient` for active-tenancy-scoped maintenance submissions and history. Private attachment upload is deferred until this product's private file service is implemented.

`EstateAdminRepository` continues to serve the broader staged administration modules. The `admin_main.dart` manager dashboard uses `EstateApplicationApiClient` for live estate counts and maintenance queue/review operations. Property/structure management and resident-access review have separate API-connected screens; the remaining operations modules are previews. Private evidence and maintenance attachments require this product's private-file service.

The supplied Homely images inform the restrained green palette, compact service cards and mobile-friendly spacing only. This client does not implement property discovery, sale/rent listings or agent contact.

## Run locally

```powershell
cd client
flutter pub get
flutter run -d chrome
```

Run the dedicated admin web preview with `flutter run -d chrome --target lib/admin_main.dart`, or build it separately with `flutter build web --release --target lib/admin_main.dart --output build/admin`.

Run the platform application review preview with `flutter run -d chrome --target lib/platform_admin_main.dart`, or build it with `flutter build web --release --target lib/platform_admin_main.dart --output build/platform --base-href /platform/`.

Run the dedicated mobile-first gate/security preview with `flutter run -d chrome --target lib/security_main.dart`, or build it with `flutter build web --release --target lib/security_main.dart --output build/security --base-href /security/`.

Run the dedicated landlord portal preview with `flutter run -d chrome --target lib/landlord_main.dart`, or build it with `flutter build web --release --target lib/landlord_main.dart --output build/landlord --base-href /landlord/`. Open `http://127.0.0.1:8765/landlord/` when the local preview server is running.

The authenticated landlord portfolio is available separately at `http://127.0.0.1:8765/landlord-live/`. Build it with `flutter build web --release --target lib/landlord_portal_main.dart --output build/landlord-live --base-href /landlord-live/ --dart-define=API_BASE_URL=http://127.0.0.1:4100/api/v1`. It reads estates, verified ownership, occupancy, current tenancy information and property maintenance requests from the API. The maintenance view includes resident-visible updates only; rent invoice and document views remain preview-only in the other landlord dashboard.

Run the estate application form preview with `flutter run -d chrome --target lib/onboarding_main.dart`, or build it with `flutter build web --release --target lib/onboarding_main.dart --output build/onboarding --base-href /onboarding/`. Open `http://127.0.0.1:8765/onboarding/` when the local preview server is running.

Run the API-backed resident access review with `flutter run -d chrome --target lib/resident_review_main.dart --dart-define=API_BASE_URL=http://127.0.0.1:4100/api/v1`. Build it with `flutter build web --release --target lib/resident_review_main.dart --output build/resident-review --base-href /resident-review/ --dart-define=API_BASE_URL=http://127.0.0.1:4100/api/v1`. Open `http://127.0.0.1:8765/resident-review/` when the local preview server is running.

Run the resident estate search and join-request page with `flutter run -d chrome --target lib/resident_join_main.dart --dart-define=API_BASE_URL=http://127.0.0.1:4100/api/v1`. Build it with `flutter build web --release --target lib/resident_join_main.dart --output build/join-estate --base-href /join-estate/ --dart-define=API_BASE_URL=http://127.0.0.1:4100/api/v1`. Open `http://127.0.0.1:8765/join-estate/` when the local preview server is running.

Open the standalone estate map preview at `http://127.0.0.1:8765/map/`, or run `flutter run -d chrome --target lib/estate_map_main.dart`. Build it with `flutter build web --release --target lib/estate_map_main.dart --output build/map --base-href /map/`.

With the local preview server running, open `http://127.0.0.1:8765/` for the preview hub and links to the resident, estate admin, onboarding, landlord, platform review and gate/security screens.

The preview data is illustrative and is not connected to a live estate. This client intentionally has no AI/model branding.

Resident My Property is designed for the authenticated actor's safe property-detail projection. Estate charge visibility uses the resident-safe `list-my-applicable-charges.js` read seam; sample data is not connected to either service.

Resident My Rent uses the current tenant/property relationship and shows approved rent terms only; outstanding amounts and payments remain in the invoice and verified allocation views.

The resident Estate map is a layout schematic backed by the estate-map asset read boundary. Diagram positions are preview-only and explicitly not to scale; the production adapter must project only actor-authorized property/estate assets and preserve verified, approximate, unverified or unmapped location states. The client never requests device GPS.

The landlord portal previews properties and tenancy terms from the verified landlord portfolio projection and rent invoice summaries from a separate illustrative adapter. The connected rent view must use the invoice read service's landlord relationship authorization and verified allocations; it must never infer collections or arrears from contract rent. Receipt files and agreement documents require their own authorized private-file paths.

The backend includes `list-my-landlord-rent-invoices.js`, a composition seam over the existing relationship-aware invoice list. The host adapter must configure the canonical rent category and retain verified ownership/payee authorization and allocation-derived balances before replacing the preview repository.

Landlord property charges are shown only as issued invoice summaries in the preview. The connected query uses the server-configured category allowlist and the existing landlord relationship-scoped invoice service; charge definitions are not presented as invoices or balances.

The landlord document list uses illustrative metadata only. Production list and file access must be scoped to current verified ownership and reauthorized through this product's private storage service.

The estate communications composer previews all-resident, property-group and staff audiences with push/email/SMS channel selection. Saving a draft only adds it to the current browser session; schedule and dispatch require this product's announcement and notification services. Open the administration preview at `http://127.0.0.1:8765/admin/`.

Estate onboarding drafts and submission use this product's authenticated API. The server currently validates required form fields, records an audit event and places submitted applications in the platform review queue. Document upload and required-document policy have not yet been defined for this product.

The platform application detail shows illustrative document metadata and review states. Opening submitted files still requires an authenticated reviewer-scoped private document service; sample rows do not point to real files.



The admin Property register detail includes a session-local map-location preview for confidence, WGS 84 coordinates, optional accuracy and source. It does not write a live map location or audit event; production updates must use the authorized command in `backend/modules/properties/update-estate-map-asset-location.js` and the estate's approved map provider.

The admin Property register Add property preview also captures optional address (maximum 240 characters) and description (maximum 700 characters), shown in property details and retained by preview map updates and archival. These values remain session-local until wired to the authenticated property creation service.

Resident Estate map place details include the displayed location-confidence state and, when present in the authorized map projection, its source and known accuracy. Sample values are illustrative; the schematic is not a live map or surveyed coordinate display.

The admin Property register includes a session-local Add property preview with configurable property type/status and optional active hierarchy parent. It does not grant ownership/access or create tenancy; production creation must be routed through the estate-scoped property command and audit service.

Property details also expose a session-local Edit details form for non-archived records. It updates code, type, operational status, unit, address and description with bounds and duplicate-code checks while preserving relationship and map summaries. Connect it to the authenticated `PATCH` property command before treating edits as persistent.

The admin release preview is at `http://127.0.0.1:8765/admin/`; the resident Flutter preview is at `http://127.0.0.1:8765/web/` when `client/preview-server.js` is running.

Only preview-created vacant property records can be archived in the local admin preview, with the record retained and its status changed. Sample properties are excluded because their active relationship state cannot be verified; the live service must perform the full relationship check and audit commit in the property archive command.

The resident Account tab now previews the resident profile, active estate/property context, a membership-aware estate-switch entry and recent maintenance/community requests linked to their resident-safe detail view. Estate switching will use this product's membership API.
