CREATE TYPE "TenancyStatus" AS ENUM ('PENDING_APPROVAL', 'ACTIVE', 'ENDED', 'TERMINATED', 'CANCELLED');
CREATE TYPE "RentFrequency" AS ENUM ('MONTHLY', 'QUARTERLY', 'ANNUALLY');

CREATE TABLE "estate_tenancies" (
  "id" UUID NOT NULL,
  "estate_id" UUID NOT NULL,
  "property_id" UUID NOT NULL,
  "tenant_user_id" UUID NOT NULL,
  "payee_user_id" UUID NOT NULL,
  "status" "TenancyStatus" NOT NULL DEFAULT 'PENDING_APPROVAL',
  "rent_amount" DECIMAL(12,2) NOT NULL,
  "currency" VARCHAR(3) NOT NULL,
  "rent_frequency" "RentFrequency" NOT NULL,
  "rent_due_day" INTEGER NOT NULL,
  "deposit_amount" DECIMAL(12,2),
  "effective_from" DATE NOT NULL,
  "effective_to" DATE,
  "terms_note" VARCHAR(2000),
  "created_by_id" UUID NOT NULL,
  "approved_by_id" UUID,
  "approved_at" TIMESTAMPTZ(3),
  "terminated_by_id" UUID,
  "terminated_at" TIMESTAMPTZ(3),
  "termination_effective_date" DATE,
  "termination_reason" VARCHAR(1000),
  "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMPTZ(3) NOT NULL,
  CONSTRAINT "estate_tenancies_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "estate_tenancies_estate_fkey" FOREIGN KEY ("estate_id") REFERENCES "estates"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "estate_tenancies_property_fkey" FOREIGN KEY ("property_id") REFERENCES "estate_properties"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "estate_tenancies_tenant_fkey" FOREIGN KEY ("tenant_user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "estate_tenancies_payee_fkey" FOREIGN KEY ("payee_user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "estate_tenancies_creator_fkey" FOREIGN KEY ("created_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "estate_tenancies_approver_fkey" FOREIGN KEY ("approved_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "estate_tenancies_terminator_fkey" FOREIGN KEY ("terminated_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "estate_tenancies_amount_check" CHECK ("rent_amount" > 0 AND ("deposit_amount" IS NULL OR "deposit_amount" >= 0)),
  CONSTRAINT "estate_tenancies_due_day_check" CHECK ("rent_due_day" BETWEEN 1 AND 31),
  CONSTRAINT "estate_tenancies_dates_check" CHECK ("effective_to" IS NULL OR "effective_to" >= "effective_from"),
  CONSTRAINT "estate_tenancies_approval_fields_check" CHECK (("status" = 'PENDING_APPROVAL' AND "approved_by_id" IS NULL AND "approved_at" IS NULL) OR ("status" <> 'PENDING_APPROVAL' AND "approved_by_id" IS NOT NULL AND "approved_at" IS NOT NULL)),
  CONSTRAINT "estate_tenancies_termination_fields_check" CHECK (("status" = 'TERMINATED' AND "terminated_by_id" IS NOT NULL AND "terminated_at" IS NOT NULL AND "termination_reason" IS NOT NULL) OR ("status" <> 'TERMINATED' AND "terminated_by_id" IS NULL AND "terminated_at" IS NULL AND "termination_reason" IS NULL))
);

CREATE INDEX "estate_tenancies_estate_status_from_idx" ON "estate_tenancies"("estate_id", "status", "effective_from");
CREATE INDEX "estate_tenancies_tenant_status_from_idx" ON "estate_tenancies"("tenant_user_id", "status", "effective_from");
CREATE INDEX "estate_tenancies_payee_status_from_idx" ON "estate_tenancies"("payee_user_id", "status", "effective_from");
CREATE INDEX "estate_tenancies_property_status_from_idx" ON "estate_tenancies"("property_id", "status", "effective_from");
CREATE UNIQUE INDEX "estate_tenancies_one_active_per_property" ON "estate_tenancies"("property_id") WHERE "status" = 'ACTIVE';

ALTER TABLE "property_occupancies" ADD COLUMN "tenancy_id" UUID;
ALTER TABLE "property_occupancies" ADD CONSTRAINT "property_occupancies_tenancy_fkey" FOREIGN KEY ("tenancy_id") REFERENCES "estate_tenancies"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
CREATE UNIQUE INDEX "property_occupancies_tenancy_id_key" ON "property_occupancies"("tenancy_id");
