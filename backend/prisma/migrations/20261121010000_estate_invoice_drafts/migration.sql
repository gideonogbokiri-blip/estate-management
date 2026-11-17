CREATE TYPE "EstateInvoiceDraftStatus" AS ENUM ('DRAFT', 'ISSUED', 'PARTIALLY_PAID', 'PAID', 'CANCELLED');

CREATE TABLE "estate_invoice_drafts" (
    "id" UUID NOT NULL,
    "estate_id" UUID NOT NULL,
    "invoice_number" VARCHAR(40) NOT NULL,
    "charge_version_id" UUID NOT NULL,
    "property_id" UUID NOT NULL,
    "payer_user_id" UUID NOT NULL,
    "created_by_id" UUID NOT NULL,
    "period_start" DATE NOT NULL,
    "period_end" DATE NOT NULL,
    "due_date" DATE NOT NULL,
    "currency" VARCHAR(3) NOT NULL,
    "subtotal" DECIMAL(12,2) NOT NULL,
    "total" DECIMAL(12,2) NOT NULL,
    "line_snapshot" JSONB NOT NULL,
    "status" "EstateInvoiceDraftStatus" NOT NULL DEFAULT 'DRAFT',
    "idempotency_key_hash" VARCHAR(64) NOT NULL,
    "payload_hash" VARCHAR(64) NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,
    CONSTRAINT "estate_invoice_drafts_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "estate_invoice_drafts_period_range" CHECK ("period_end" >= "period_start"),
    CONSTRAINT "estate_invoice_drafts_positive_amounts" CHECK ("subtotal" > 0 AND "total" > 0 AND "total" >= "subtotal")
);

CREATE UNIQUE INDEX "estate_invoice_drafts_estate_id_invoice_number_key" ON "estate_invoice_drafts"("estate_id", "invoice_number");
CREATE UNIQUE INDEX "estate_invoice_drafts_created_by_id_estate_id_idempotency_key_hash_key" ON "estate_invoice_drafts"("created_by_id", "estate_id", "idempotency_key_hash");
CREATE UNIQUE INDEX "estate_invoice_drafts_estate_id_charge_version_id_property_id_payer_user_id_period_start_period_end_key" ON "estate_invoice_drafts"("estate_id", "charge_version_id", "property_id", "payer_user_id", "period_start", "period_end");
CREATE INDEX "estate_invoice_drafts_estate_id_status_due_date_idx" ON "estate_invoice_drafts"("estate_id", "status", "due_date");
CREATE INDEX "estate_invoice_drafts_payer_user_id_status_due_date_idx" ON "estate_invoice_drafts"("payer_user_id", "status", "due_date");

ALTER TABLE "estate_invoice_drafts" ADD CONSTRAINT "estate_invoice_drafts_estate_id_fkey" FOREIGN KEY ("estate_id") REFERENCES "estates"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "estate_invoice_drafts" ADD CONSTRAINT "estate_invoice_drafts_charge_version_id_fkey" FOREIGN KEY ("charge_version_id") REFERENCES "estate_charge_versions"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "estate_invoice_drafts" ADD CONSTRAINT "estate_invoice_drafts_property_id_fkey" FOREIGN KEY ("property_id") REFERENCES "estate_properties"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "estate_invoice_drafts" ADD CONSTRAINT "estate_invoice_drafts_payer_user_id_fkey" FOREIGN KEY ("payer_user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "estate_invoice_drafts" ADD CONSTRAINT "estate_invoice_drafts_created_by_id_fkey" FOREIGN KEY ("created_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
