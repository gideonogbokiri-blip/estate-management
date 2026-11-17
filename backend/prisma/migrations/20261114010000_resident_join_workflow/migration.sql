CREATE TYPE "ResidentJoinRequestStatus" AS ENUM ('PENDING', 'APPROVED', 'REJECTED');
CREATE TYPE "PropertyOccupancyRelationship" AS ENUM ('OWNER', 'TENANT', 'HOUSEHOLD_MEMBER', 'AUTHORIZED_OCCUPANT');
CREATE TYPE "PropertyOccupancyStatus" AS ENUM ('ACTIVE', 'ENDED');

CREATE TABLE "estate_resident_join_requests" (
  "id" UUID NOT NULL,
  "estate_id" UUID NOT NULL,
  "property_id" UUID,
  "applicant_id" UUID NOT NULL,
  "relationship" "PropertyOccupancyRelationship",
  "note" VARCHAR(1000),
  "status" "ResidentJoinRequestStatus" NOT NULL DEFAULT 'PENDING',
  "submitted_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "reviewed_by_id" UUID,
  "reviewed_at" TIMESTAMPTZ(3),
  "decision_reason" VARCHAR(1000),
  "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMPTZ(3) NOT NULL,
  CONSTRAINT "estate_resident_join_requests_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "estate_resident_join_requests_estate_fkey" FOREIGN KEY ("estate_id") REFERENCES "estates"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "estate_resident_join_requests_property_fkey" FOREIGN KEY ("property_id") REFERENCES "estate_properties"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "estate_resident_join_requests_applicant_fkey" FOREIGN KEY ("applicant_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "estate_resident_join_requests_reviewer_fkey" FOREIGN KEY ("reviewed_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "estate_resident_join_requests_scope_check" CHECK (("property_id" IS NULL AND "relationship" IS NULL) OR ("property_id" IS NOT NULL AND "relationship" IS NOT NULL))
);
CREATE INDEX "estate_resident_join_requests_estate_status_submitted_idx" ON "estate_resident_join_requests"("estate_id", "status", "submitted_at");
CREATE INDEX "estate_resident_join_requests_applicant_submitted_idx" ON "estate_resident_join_requests"("applicant_id", "submitted_at");
CREATE UNIQUE INDEX "estate_resident_join_requests_one_pending_per_estate" ON "estate_resident_join_requests"("estate_id", "applicant_id") WHERE "status" = 'PENDING';

CREATE TABLE "property_occupancies" (
  "id" UUID NOT NULL,
  "estate_id" UUID NOT NULL,
  "property_id" UUID NOT NULL,
  "resident_id" UUID NOT NULL,
  "relationship" "PropertyOccupancyRelationship" NOT NULL,
  "status" "PropertyOccupancyStatus" NOT NULL DEFAULT 'ACTIVE',
  "effective_from" DATE NOT NULL,
  "effective_to" DATE,
  "approved_from_request_id" UUID,
  "created_by_id" UUID NOT NULL,
  "ended_by_id" UUID,
  "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMPTZ(3) NOT NULL,
  CONSTRAINT "property_occupancies_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "property_occupancies_estate_fkey" FOREIGN KEY ("estate_id") REFERENCES "estates"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "property_occupancies_property_fkey" FOREIGN KEY ("property_id") REFERENCES "estate_properties"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "property_occupancies_resident_fkey" FOREIGN KEY ("resident_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "property_occupancies_request_fkey" FOREIGN KEY ("approved_from_request_id") REFERENCES "estate_resident_join_requests"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "property_occupancies_creator_fkey" FOREIGN KEY ("created_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "property_occupancies_ender_fkey" FOREIGN KEY ("ended_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "property_occupancies_dates_check" CHECK ("effective_to" IS NULL OR "effective_to" >= "effective_from")
);
CREATE INDEX "property_occupancies_estate_property_status_idx" ON "property_occupancies"("estate_id", "property_id", "status");
CREATE INDEX "property_occupancies_resident_status_from_idx" ON "property_occupancies"("resident_id", "status", "effective_from");
CREATE UNIQUE INDEX "property_occupancies_one_active_person_property" ON "property_occupancies"("property_id", "resident_id") WHERE "status" = 'ACTIVE';
