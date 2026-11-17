ALTER TABLE "estate_charge_versions" ADD COLUMN "property_id" UUID;
ALTER TABLE "estate_charge_versions" DROP CONSTRAINT "estate_charge_versions_property_scope";
ALTER TABLE "estate_charge_versions" ADD CONSTRAINT "estate_charge_versions_scope_target" CHECK (
  ("applies_to" = 'PROPERTY' AND "property_id" IS NOT NULL AND "property_type" IS NULL)
  OR ("applies_to" = 'PROPERTY_TYPE' AND "property_id" IS NULL AND "property_type" IS NOT NULL)
  OR ("applies_to" = 'ESTATE' AND "property_id" IS NULL AND "property_type" IS NULL)
);
ALTER TABLE "estate_charge_versions" ADD CONSTRAINT "estate_charge_versions_property_id_fkey"
  FOREIGN KEY ("property_id") REFERENCES "estate_properties"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
