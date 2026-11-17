CREATE TYPE "PropertyStatus" AS ENUM (
  'ACTIVE',
  'UNDER_DEVELOPMENT',
  'RESERVED',
  'UNDER_MAINTENANCE',
  'INACTIVE',
  'ARCHIVED'
);

CREATE TABLE "estate_properties" (
  "id" UUID NOT NULL,
  "estate_id" UUID NOT NULL,
  "code" VARCHAR(80) NOT NULL,
  "property_type" VARCHAR(80) NOT NULL,
  "status" "PropertyStatus" NOT NULL DEFAULT 'ACTIVE',
  "unit_number" VARCHAR(80),
  "address" VARCHAR(240),
  "description" VARCHAR(700),
  "latitude" DECIMAL(9,6),
  "longitude" DECIMAL(9,6),
  "archived_at" TIMESTAMPTZ(3),
  "created_by_user_id" UUID NOT NULL,
  "updated_by_user_id" UUID,
  "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMPTZ(3) NOT NULL,
  CONSTRAINT "estate_properties_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "estate_properties_estate_id_fkey" FOREIGN KEY ("estate_id") REFERENCES "estates"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "estate_properties_created_by_user_id_fkey" FOREIGN KEY ("created_by_user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "estate_properties_updated_by_user_id_fkey" FOREIGN KEY ("updated_by_user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE UNIQUE INDEX "estate_properties_estate_id_code_key" ON "estate_properties"("estate_id", "code");
CREATE INDEX "estate_properties_estate_id_status_created_at_idx" ON "estate_properties"("estate_id", "status", "created_at");
