CREATE TABLE "estate_invoice_settlements" (
    "id" UUID NOT NULL,
    "estate_id" UUID NOT NULL,
    "invoice_id" UUID NOT NULL,
    "verified_by_id" UUID NOT NULL,
    "amount" DECIMAL(12,2) NOT NULL,
    "currency" VARCHAR(3) NOT NULL,
    "bank_reference" VARCHAR(120) NOT NULL,
    "normalized_bank_reference" VARCHAR(120) NOT NULL,
    "receipt_number" VARCHAR(40) NOT NULL,
    "received_at" TIMESTAMPTZ(3) NOT NULL,
    "verification_note" VARCHAR(500) NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "estate_invoice_settlements_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "estate_invoice_settlements_positive_amount" CHECK ("amount" > 0)
);

CREATE UNIQUE INDEX "estate_invoice_settlements_estate_id_normalized_bank_reference_key" ON "estate_invoice_settlements"("estate_id", "normalized_bank_reference");
CREATE UNIQUE INDEX "estate_invoice_settlements_receipt_number_key" ON "estate_invoice_settlements"("receipt_number");
CREATE INDEX "estate_invoice_settlements_invoice_id_received_at_idx" ON "estate_invoice_settlements"("invoice_id", "received_at");
CREATE INDEX "estate_invoice_settlements_estate_id_received_at_idx" ON "estate_invoice_settlements"("estate_id", "received_at");

ALTER TABLE "estate_invoice_settlements" ADD CONSTRAINT "estate_invoice_settlements_estate_id_fkey" FOREIGN KEY ("estate_id") REFERENCES "estates"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "estate_invoice_settlements" ADD CONSTRAINT "estate_invoice_settlements_invoice_id_fkey" FOREIGN KEY ("invoice_id") REFERENCES "estate_invoice_drafts"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "estate_invoice_settlements" ADD CONSTRAINT "estate_invoice_settlements_verified_by_id_fkey" FOREIGN KEY ("verified_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
