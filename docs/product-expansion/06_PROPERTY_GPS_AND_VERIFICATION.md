# 06 — Property GPS and Verification

Status: implemented; map UI still schematic.

Reuses existing `EstateProperty.latitude`/`longitude` and adds `locationAccuracyMeters`, `locationCaptureMethod` (GPS_DEVICE/MAP_PIN/MANUAL), `locationCapturedAt`, `locationVerificationStatus` (UNVERIFIED/PENDING_VERIFICATION/VERIFIED/REJECTED), `locationVerifiedById`, `locationVerifiedAt` and `locationCorrectionReason`.

## Workflow

Manager captures or corrects a pin → `PENDING_VERIFICATION` → manager verifies or rejects with a reason. Residents only see coordinates when the status is `VERIFIED`; unverified pins are never exposed. Registration-time user location remains separate and is never treated as proof of residence.

## Routes

- `GET /api/v1/estate/estates/:estateId/properties/locations`
- `POST /api/v1/estate/estates/:estateId/properties/:propertyId/location`
- `POST /api/v1/estate/estates/:estateId/properties/:propertyId/location/verify`

## Remaining gap

The resident map screen still uses the illustrative schematic repository. Connecting it to verified coordinates is the outstanding UI work.

## Tests

`backend/tests/property-location.test.js`.
