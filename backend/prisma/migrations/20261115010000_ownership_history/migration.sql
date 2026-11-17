CREATE TYPE "OwnershipInterestStatus" AS ENUM ('ACTIVE', 'ENDED');
CREATE TYPE "OwnershipVerificationStatus" AS ENUM ('PENDING', 'VERIFIED', 'REJECTED');

CREATE TABLE "estate_ownership_interests" (
  "id" UUID NOT NULL,
  "estate_id" UUID NOT NULL,
  "property_id" UUID NOT NULL,
  "owner_user_id" UUID NOT NULL,
  "ownership_share" DECIMAL(5,2) NOT NULL,
  "effective_from" DATE NOT NULL,
  "effective_to" DATE,
  "status" "OwnershipInterestStatus" NOT NULL DEFAULT 'ACTIVE',
  "verification_status" "OwnershipVerificationStatus" NOT NULL DEFAULT 'PENDING',
  "evidence_note" VARCHAR(1000) NOT NULL,
  "review_reason" VARCHAR(1000),
  "reviewed_by_id" UUID,
  "reviewed_at" TIMESTAMPTZ(3),
  "end_reason" VARCHAR(1000),
  "created_by_id" UUID NOT NULL,
  "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMPTZ(3) NOT NULL,
  CONSTRAINT "estate_ownership_interests_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "estate_ownership_estate_fkey" FOREIGN KEY ("estate_id") REFERENCES "estates"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "estate_ownership_property_fkey" FOREIGN KEY ("property_id") REFERENCES "estate_properties"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "estate_ownership_owner_fkey" FOREIGN KEY ("owner_user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "estate_ownership_creator_fkey" FOREIGN KEY ("created_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "estate_ownership_reviewer_fkey" FOREIGN KEY ("reviewed_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "estate_ownership_share_check" CHECK ("ownership_share" > 0 AND "ownership_share" <= 100),
  CONSTRAINT "estate_ownership_dates_check" CHECK ("effective_to" IS NULL OR "effective_to" >= "effective_from"),
  CONSTRAINT "estate_ownership_review_fields_check" CHECK (("verification_status" = 'PENDING' AND "reviewed_by_id" IS NULL AND "reviewed_at" IS NULL) OR ("verification_status" <> 'PENDING' AND "reviewed_by_id" IS NOT NULL AND "reviewed_at" IS NOT NULL))
);
CREATE INDEX "estate_ownership_estate_property_status_verification_idx" ON "estate_ownership_interests"("estate_id", "property_id", "status", "verification_status");
CREATE INDEX "estate_ownership_owner_status_verification_from_idx" ON "estate_ownership_interests"("owner_user_id", "status", "verification_status", "effective_from");
