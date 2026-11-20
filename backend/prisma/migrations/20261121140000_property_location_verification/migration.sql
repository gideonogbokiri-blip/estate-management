-- Phase 3 property GPS: capture metadata, correction and verification workflow.
-- Registration-time user location is deliberately not used as proof of residence.

ALTER TABLE "estate_properties"
  ADD COLUMN "location_accuracy_meters" DECIMAL(10,2),
  ADD COLUMN "location_capture_method" VARCHAR(30),
  ADD COLUMN "location_captured_at" TIMESTAMPTZ(3),
  ADD COLUMN "location_verification_status" VARCHAR(20) NOT NULL DEFAULT 'UNVERIFIED',
  ADD COLUMN "location_verified_by_id" UUID,
  ADD COLUMN "location_verified_at" TIMESTAMPTZ(3),
  ADD COLUMN "location_correction_reason" VARCHAR(500);

ALTER TABLE "estate_properties" ADD CONSTRAINT "estate_properties_location_status_check"
  CHECK ("location_verification_status" IN ('UNVERIFIED', 'PENDING_VERIFICATION', 'VERIFIED', 'REJECTED'));
ALTER TABLE "estate_properties" ADD CONSTRAINT "estate_properties_location_capture_method_check"
  CHECK ("location_capture_method" IS NULL OR "location_capture_method" IN ('GPS_DEVICE', 'MAP_PIN', 'MANUAL'));
ALTER TABLE "estate_properties" ADD CONSTRAINT "estate_properties_location_accuracy_check"
  CHECK ("location_accuracy_meters" IS NULL OR "location_accuracy_meters" >= 0);
ALTER TABLE "estate_properties" ADD CONSTRAINT "estate_properties_location_verified_by_fkey"
  FOREIGN KEY ("location_verified_by_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

CREATE INDEX "estate_properties_location_status_idx"
  ON "estate_properties"("estate_id", "location_verification_status");
