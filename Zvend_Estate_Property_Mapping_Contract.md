# Zvend Estate — Property Mapping Contract

**Status:** Proposed contract; confirm Zvend's geographic/map services and location policy before implementation  
**Product baseline:** `Zvend_Estate_Management_Build_Documentation.md`  
**Scope:** Estate outlines and mapped properties, zones, streets, buildings, gates, parking and facilities

This contract defines property and estate asset mapping only. It does not propose live resident/landlord/tenant location tracking. The product specification explicitly prohibits continuous tracking of people or their phones.

## 1. Location data boundary

- Coordinates belong to mapped estate assets, not people. Store optional coordinates for estate boundary vertices, zones, streets, buildings, properties, gates, parking areas and facilities where the estate has reliable location data.
- Never collect continuous GPS, resident device location, visit routes, staff routes, or background location. Visitor or security workflows must not add a person's GPS point to map storage.
- Preserve the existing Zvend property/address record as the source for labels; maps are another view over authorized property/estate records, not a separate property directory.
- Use a consistent geographic CRS, normally WGS 84 latitude/longitude for interchange if compatible with Zvend's GIS provider. Validate coordinate bounds and geometry shape; preserve provider/source, verification status, accuracy if known, and updated-by/updated-at metadata.
- Location values may be approximate or unverified. Represent missing/unverified data explicitly; do not geocode guesses or present approximate points as surveyed locations.
- A property's marker is visible only to actors who may view that property. Public/resident map detail follows the same property and relationship authorization rules as the property list.

## 2. Boundary, layers and property coordinate updates

An estate outline is optional and may be a polygon/multipolygon according to existing GIS support. It can support visual context and plausibility checks but is not proof of legal ownership, survey boundary or a physical security perimeter.

Supported optional map layers include zones, streets, buildings, units/properties, gates, parking and facilities. A layer is returned only when the actor has access to those records and the estate has configured the layer. Do not infer security-critical gate status from map visibility.

Only staff with explicit estate-map/property location permission may create or update coordinates. Each change records actor, estate, target, previous and new safe coordinate/source/verification values, reason and timestamp in the audit facility. Coordinate corrections do not change property identity, tenancy, occupancy or access records.

## 3. Logical records

Reconcile these concepts with the current estate/property schema and any existing Zvend GIS provider before adding tables/columns.

### Asset location

- Estate ID and target asset type/ID with one authorized parent relationship.
- Point/shape in the chosen coordinate system, source, verification state, optional known accuracy, created/updated actor and timestamps.
- Estate-scoped constraints to prevent duplicate location rows per asset where applicable; spatial indexes only if consistent with the current database and query pattern.

### Estate boundary

- Estate ID, optional polygon/multipolygon geometry, source/verification state, version/effective time and reviewer metadata.
- Preserve old boundary versions for history if updates have operational/legal significance. Do not label a user-supplied outline as a legal survey.

## 4. Proposed API operations

Match existing API, GIS serialization and pagination conventions after repository audit.

| Method and path | Permission | Behavior |
|---|---|---|
| `GET /api/estate/estates/:estateId/map` | Estate map view plus asset-specific view permissions | Return authorized layers and map metadata, scoped to the active estate |
| `GET /api/estate/estates/:estateId/map/assets/:assetType/:assetId` | Authorized asset view | Return one authorized asset's display label, permitted location and property summary |
| `POST /api/estate/estates/:estateId/map/assets/:assetType/:assetId/location` | `map.location.manage` and asset manage permission | Validate and record an asset coordinate update with source/reason and audit event |
| `POST /api/estate/estates/:estateId/map/boundaries` | `map.boundary.manage` | Add a draft estate outline and validation metadata |
| `POST /api/estate/estates/:estateId/map/boundaries/:boundaryId/verify` | Boundary verification permission | Record review/verification without asserting legal survey status |
| `GET /api/estate/estates/:estateId/map/boundaries` | Estate map view | Return active and, if authorized, historical boundary versions |

If the selected map SDK needs tiles/geocoding, use the existing approved Zvend provider/credentials and licensing. Do not put provider secrets in the browser or adopt a new paid dependency before confirming the platform's map service and terms.

## 5. Map query and privacy rules

- Authorize the estate and each asset layer server-side before returning markers or counts.
- Apply property, zone and role relationships before map bounding-box filtering; a map viewport is not an authorization boundary.
- Bound viewport size, feature count and zoom/detail level. Paginate or cluster large estates according to the chosen map provider.
- Use map/list as two views of the same scoped property results. Search results, marker labels, tooltips and side panels must not disclose owner contact data or unrelated resident information.
- Keep staff's own device location and security guard tracking out of this feature. If a future emergency feature proposes location access, it requires a separate product and privacy decision; it is outside this scope.
- Escape/map-provider sanitize asset labels before rendering popup content.

## 6. UI mapping

| Preview surface | Integrated behavior |
|---|---|
| Property register map/list switch | Switch the same authorized property set between table and map views |
| Map marker | Select one authorized property and show its permitted label/status/location confidence |
| Property locator/update | Use the estate map service and permission-checked coordinate update command; audit changes |
| Zone/gate/facility layers | Read estate asset layers subject to per-layer permission |
| Missing coordinates | Show an unmapped state and provide update affordance only to authorized staff |

The current schematic is for layout review only. It contains illustrative markers and coordinates and is not a live map, survey or GPS feed.

`backend/modules/properties/list-estate-map-assets.js` provides a framework-independent read seam for the authorized map view. Its resolver must confirm active map access; the repository must apply per-asset/layer authorization before returning its bounded rows. The use case validates WGS 84 coordinate bounds and pair completeness, requires an explicit verified/approximate/unverified/unmapped confidence state, and returns only asset labels/details from an allowlisted projection. The resident Flutter preview uses separate normalized diagram positions and clearly labels them illustrative; it does not plot these backend coordinates without an approved map-provider and projection adapter.

`backend/modules/properties/update-estate-map-asset-location.js` defines the proposed staff location-write seam. Its access resolver must enforce both `map.location.manage` and the target asset's management capability, and return the estate's configured location-source allowlist. The command locks and rechecks the target asset in the estate, validates coordinate pairs, WGS 84 bounds, confidence, source and optional accuracy, and commits the location plus an audit event containing the reason and previous/new safe location values in one transaction. Unmapped state requires null coordinates and no accuracy. The host must serialize this command with asset archive/reparent writers and connect it only to Zvend's approved location/storage service.

## 7. Acceptance evidence and integration gates

Before production claims, demonstrate:

1. No resident/landlord/tenant/device location collection or continuous tracking in clients, API, analytics or storage.
2. Cross-estate and property-level map isolation, including marker counts, search, viewport filtering and side-panel detail.
3. Invalid coordinates/geometries are rejected and unverified/approximate data is labelled accurately.
4. Coordinate/boundary changes are permission checked, audited and do not mutate occupancy/ownership/tenancy.
5. Map labels do not leak private contact or unrelated household data.
6. Map provider choice, credentials, attribution, cost and license are approved and configured through existing platform mechanisms.

Inspect existing Zvend map/GIS provider and schema, estate/property IDs, location precision policy, authorization helpers, audit facility, frontend map package and terms before implementation.
