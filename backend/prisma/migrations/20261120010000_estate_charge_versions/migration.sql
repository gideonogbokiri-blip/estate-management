CREATE TYPE "EstateChargeRecurrence" AS ENUM ('ONE_TIME', 'MONTHLY', 'QUARTERLY', 'ANNUALLY');
CREATE TYPE "EstateChargeScope" AS ENUM ('ESTATE', 'PROPERTY', 'PROPERTY_TYPE');
CREATE TYPE "EstateChargeVersionStatus" AS ENUM ('DRAFT', 'ACTIVE', 'RETIRED');

CREATE TABLE "estate_charge_definitions" (
    "id" UUID NOT NULL,
    "estate_id" UUID NOT NULL,
    "code" VARCHAR(40) NOT NULL,
    "created_by_id" UUID NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,
    CONSTRAINT "estate_charge_definitions_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "estate_charge_versions" (
    "id" UUID NOT NULL,
    "charge_id" UUID NOT NULL,
    "version_number" INTEGER NOT NULL,
    "name" VARCHAR(120) NOT NULL,
    "description" VARCHAR(500),
    "category" VARCHAR(40) NOT NULL,
    "amount" DECIMAL(12,2) NOT NULL,
    "currency" VARCHAR(3) NOT NULL,
    "recurrence" "EstateChargeRecurrence" NOT NULL,
    "effective_from" DATE NOT NULL,
    "effective_to" DATE,
    "due_day" INTEGER NOT NULL,
    "grace_days" INTEGER NOT NULL DEFAULT 0,
    "applies_to" "EstateChargeScope" NOT NULL,
    "property_type" VARCHAR(80),
    "status" "EstateChargeVersionStatus" NOT NULL DEFAULT 'DRAFT',
    "created_by_id" UUID NOT NULL,
    "activated_by_id" UUID,
    "activated_at" TIMESTAMPTZ(3),
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "estate_charge_versions_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "estate_charge_versions_positive_amount" CHECK ("amount" > 0),
    CONSTRAINT "estate_charge_versions_due_day_range" CHECK ("due_day" BETWEEN 1 AND 31),
    CONSTRAINT "estate_charge_versions_grace_days_range" CHECK ("grace_days" BETWEEN 0 AND 90),
    CONSTRAINT "estate_charge_versions_effective_range" CHECK ("effective_to" IS NULL OR "effective_to" >= "effective_from"),
    CONSTRAINT "estate_charge_versions_property_scope" CHECK (("applies_to" = 'PROPERTY_TYPE' AND "property_type" IS NOT NULL) OR ("applies_to" <> 'PROPERTY_TYPE' AND "property_type" IS NULL))
);

CREATE UNIQUE INDEX "estate_charge_definitions_estate_id_code_key" ON "estate_charge_definitions"("estate_id", "code");
CREATE INDEX "estate_charge_definitions_estate_id_created_at_idx" ON "estate_charge_definitions"("estate_id", "created_at");
CREATE UNIQUE INDEX "estate_charge_versions_charge_id_version_number_key" ON "estate_charge_versions"("charge_id", "version_number");
CREATE INDEX "estate_charge_versions_charge_id_status_effective_from_idx" ON "estate_charge_versions"("charge_id", "status", "effective_from");

ALTER TABLE "estate_charge_definitions" ADD CONSTRAINT "estate_charge_definitions_estate_id_fkey" FOREIGN KEY ("estate_id") REFERENCES "estates"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "estate_charge_definitions" ADD CONSTRAINT "estate_charge_definitions_created_by_id_fkey" FOREIGN KEY ("created_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "estate_charge_versions" ADD CONSTRAINT "estate_charge_versions_charge_id_fkey" FOREIGN KEY ("charge_id") REFERENCES "estate_charge_definitions"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "estate_charge_versions" ADD CONSTRAINT "estate_charge_versions_created_by_id_fkey" FOREIGN KEY ("created_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "estate_charge_versions" ADD CONSTRAINT "estate_charge_versions_activated_by_id_fkey" FOREIGN KEY ("activated_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
