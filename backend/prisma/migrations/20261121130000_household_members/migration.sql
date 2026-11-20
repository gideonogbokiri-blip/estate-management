-- Phase 3 household profiles: adult members, dependants and restricted members.
-- Household members are distinct from account owners and do not automatically
-- receive financial privileges.

CREATE TABLE "household_members" (
  "id" UUID NOT NULL,
  "estate_id" UUID NOT NULL,
  "property_id" UUID NOT NULL,
  "primary_user_id" UUID NOT NULL,
  "full_name" VARCHAR(160) NOT NULL,
  "relationship" VARCHAR(30) NOT NULL,
  "member_type" VARCHAR(20) NOT NULL,
  "date_of_birth" DATE,
  "phone" VARCHAR(30),
  "email" VARCHAR(254),
  "linked_user_id" UUID,
  "financial_access" BOOLEAN NOT NULL DEFAULT false,
  "status" VARCHAR(20) NOT NULL DEFAULT 'PENDING_APPROVAL',
  "effective_from" DATE NOT NULL,
  "effective_to" DATE,
  "added_by_id" UUID NOT NULL,
  "decided_by_id" UUID,
  "decided_at" TIMESTAMPTZ(3),
  "decision_reason" VARCHAR(500),
  "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "household_members_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "household_members_status_check"
    CHECK ("status" IN ('PENDING_APPROVAL', 'ACTIVE', 'ENDED', 'REJECTED')),
  CONSTRAINT "household_members_member_type_check"
    CHECK ("member_type" IN ('ADULT', 'CHILD', 'RESTRICTED')),
  CONSTRAINT "household_members_relationship_check"
    CHECK ("relationship" IN ('SPOUSE', 'CHILD', 'PARENT', 'DEPENDENT', 'OTHER', 'AUTHORIZED_OCCUPANT')),
  CONSTRAINT "household_members_dates_check"
    CHECK ("effective_to" IS NULL OR "effective_to" >= "effective_from")
);
CREATE INDEX "household_members_estate_property_status_idx"
  ON "household_members"("estate_id", "property_id", "status");
CREATE INDEX "household_members_primary_status_idx"
  ON "household_members"("primary_user_id", "status");
ALTER TABLE "household_members" ADD CONSTRAINT "household_members_estate_fkey"
  FOREIGN KEY ("estate_id") REFERENCES "estates"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "household_members" ADD CONSTRAINT "household_members_property_fkey"
  FOREIGN KEY ("property_id") REFERENCES "estate_properties"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "household_members" ADD CONSTRAINT "household_members_primary_fkey"
  FOREIGN KEY ("primary_user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "household_members" ADD CONSTRAINT "household_members_added_by_fkey"
  FOREIGN KEY ("added_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "household_members" ADD CONSTRAINT "household_members_decided_by_fkey"
  FOREIGN KEY ("decided_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "household_members" ADD CONSTRAINT "household_members_linked_user_fkey"
  FOREIGN KEY ("linked_user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
