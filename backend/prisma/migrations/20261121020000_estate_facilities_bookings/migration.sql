CREATE TYPE "EstateFacilityApprovalMode" AS ENUM ('MANUAL', 'AUTOMATIC');
CREATE TYPE "EstateFacilityBookingStatus" AS ENUM ('PENDING_REVIEW', 'CONFIRMED', 'DECLINED', 'CANCELLED', 'COMPLETED');

CREATE TABLE "estate_facilities" (
    "id" UUID NOT NULL,
    "estate_id" UUID NOT NULL,
    "code" VARCHAR(60) NOT NULL,
    "name" VARCHAR(120) NOT NULL,
    "category" VARCHAR(60) NOT NULL,
    "description" VARCHAR(700) NOT NULL,
    "location" VARCHAR(160) NOT NULL,
    "capacity" INTEGER NOT NULL,
    "duration_minutes" INTEGER NOT NULL,
    "opening_time" VARCHAR(5) NOT NULL,
    "closing_time" VARCHAR(5) NOT NULL,
    "booking_lead_hours" INTEGER NOT NULL DEFAULT 2,
    "approval_mode" "EstateFacilityApprovalMode" NOT NULL DEFAULT 'MANUAL',
    "policy_version" INTEGER NOT NULL DEFAULT 1,
    "active" BOOLEAN NOT NULL DEFAULT true,
    "created_by_id" UUID NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,
    CONSTRAINT "estate_facilities_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "estate_facilities_positive_limits" CHECK ("capacity" > 0 AND "duration_minutes" > 0 AND "booking_lead_hours" >= 0),
    CONSTRAINT "estate_facilities_valid_hours" CHECK ("opening_time" ~ '^([01][0-9]|2[0-3]):[0-5][0-9]$' AND "closing_time" ~ '^([01][0-9]|2[0-3]):[0-5][0-9]$' AND "closing_time" > "opening_time")
);

CREATE TABLE "estate_facility_bookings" (
    "id" UUID NOT NULL,
    "reference" VARCHAR(32) NOT NULL,
    "estate_id" UUID NOT NULL,
    "facility_id" UUID NOT NULL,
    "property_id" UUID NOT NULL,
    "requester_user_id" UUID NOT NULL,
    "reviewer_user_id" UUID,
    "starts_at" TIMESTAMPTZ(3) NOT NULL,
    "ends_at" TIMESTAMPTZ(3) NOT NULL,
    "attendee_count" INTEGER NOT NULL,
    "purpose" VARCHAR(500),
    "policy_version" INTEGER NOT NULL,
    "status" "EstateFacilityBookingStatus" NOT NULL DEFAULT 'PENDING_REVIEW',
    "review_reason" VARCHAR(1000),
    "reviewed_at" TIMESTAMPTZ(3),
    "idempotency_key_hash" VARCHAR(64) NOT NULL,
    "payload_hash" VARCHAR(64) NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,
    CONSTRAINT "estate_facility_bookings_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "estate_facility_bookings_valid_period" CHECK ("ends_at" > "starts_at" AND "attendee_count" > 0)
);

CREATE TABLE "estate_facility_booking_history" (
    "id" UUID NOT NULL,
    "booking_id" UUID NOT NULL,
    "actor_user_id" UUID NOT NULL,
    "from_status" "EstateFacilityBookingStatus",
    "to_status" "EstateFacilityBookingStatus" NOT NULL,
    "reason" VARCHAR(1000),
    "occurred_at" TIMESTAMPTZ(3) NOT NULL,
    CONSTRAINT "estate_facility_booking_history_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "estate_facilities_estate_id_code_key" ON "estate_facilities"("estate_id", "code");
CREATE INDEX "estate_facilities_estate_id_active_category_idx" ON "estate_facilities"("estate_id", "active", "category");
CREATE UNIQUE INDEX "estate_facility_bookings_reference_key" ON "estate_facility_bookings"("reference");
CREATE UNIQUE INDEX "estate_facility_bookings_requester_user_id_estate_id_idempotency_key_hash_key" ON "estate_facility_bookings"("requester_user_id", "estate_id", "idempotency_key_hash");
CREATE INDEX "estate_facility_bookings_facility_id_status_starts_at_ends_at_idx" ON "estate_facility_bookings"("facility_id", "status", "starts_at", "ends_at");
CREATE INDEX "estate_facility_bookings_estate_id_status_created_at_idx" ON "estate_facility_bookings"("estate_id", "status", "created_at");
CREATE INDEX "estate_facility_bookings_requester_user_id_estate_id_starts_at_idx" ON "estate_facility_bookings"("requester_user_id", "estate_id", "starts_at");
CREATE INDEX "estate_facility_booking_history_booking_id_occurred_at_idx" ON "estate_facility_booking_history"("booking_id", "occurred_at");

ALTER TABLE "estate_facilities" ADD CONSTRAINT "estate_facilities_estate_id_fkey" FOREIGN KEY ("estate_id") REFERENCES "estates"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "estate_facilities" ADD CONSTRAINT "estate_facilities_created_by_id_fkey" FOREIGN KEY ("created_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "estate_facility_bookings" ADD CONSTRAINT "estate_facility_bookings_estate_id_fkey" FOREIGN KEY ("estate_id") REFERENCES "estates"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "estate_facility_bookings" ADD CONSTRAINT "estate_facility_bookings_facility_id_fkey" FOREIGN KEY ("facility_id") REFERENCES "estate_facilities"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "estate_facility_bookings" ADD CONSTRAINT "estate_facility_bookings_property_id_fkey" FOREIGN KEY ("property_id") REFERENCES "estate_properties"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "estate_facility_bookings" ADD CONSTRAINT "estate_facility_bookings_requester_user_id_fkey" FOREIGN KEY ("requester_user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "estate_facility_bookings" ADD CONSTRAINT "estate_facility_bookings_reviewer_user_id_fkey" FOREIGN KEY ("reviewer_user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "estate_facility_booking_history" ADD CONSTRAINT "estate_facility_booking_history_booking_id_fkey" FOREIGN KEY ("booking_id") REFERENCES "estate_facility_bookings"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "estate_facility_booking_history" ADD CONSTRAINT "estate_facility_booking_history_actor_user_id_fkey" FOREIGN KEY ("actor_user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
