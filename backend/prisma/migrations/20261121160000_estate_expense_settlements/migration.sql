ALTER TYPE "EstateExpenseStatus" ADD VALUE IF NOT EXISTS 'PARTIALLY_PAID';
ALTER TYPE "EstateExpenseStatus" ADD VALUE IF NOT EXISTS 'PAID';

CREATE TABLE "estate_expense_settlements" (
  "id" UUID NOT NULL,
  "estate_id" UUID NOT NULL,
  "expense_id" UUID NOT NULL,
  "verified_by_id" UUID NOT NULL,
  "amount" DECIMAL(12,2) NOT NULL,
  "currency" VARCHAR(3) NOT NULL,
  "bank_reference" VARCHAR(120) NOT NULL,
  "normalized_bank_reference" VARCHAR(120) NOT NULL,
  "verification_note" VARCHAR(1000) NOT NULL,
  "receipt_number" VARCHAR(40) NOT NULL,
  "received_at" DATE NOT NULL,
  "idempotency_key_hash" VARCHAR(64) NOT NULL,
  "payload_hash" VARCHAR(64) NOT NULL,
  "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "estate_expense_settlements_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "estate_expense_settlements_positive_amount_check" CHECK ("amount" > 0),
  CONSTRAINT "estate_expense_settlements_normalized_reference_check" CHECK ("normalized_bank_reference" = upper(trim("bank_reference"))),
  CONSTRAINT "estate_expense_settlements_nonempty_note_check" CHECK (length(trim("verification_note")) >= 8)
);

CREATE UNIQUE INDEX "estate_expense_settlements_receipt_number_key" ON "estate_expense_settlements"("receipt_number");
CREATE UNIQUE INDEX "estate_expense_settlements_estate_id_normalized_bank_refere_key" ON "estate_expense_settlements"("estate_id", "normalized_bank_reference");
CREATE UNIQUE INDEX "estate_expense_settlements_estate_id_verified_by_id_idempot_key" ON "estate_expense_settlements"("estate_id", "verified_by_id", "idempotency_key_hash");
CREATE INDEX "estate_expense_settlements_estate_id_expense_id_received_at_idx" ON "estate_expense_settlements"("estate_id", "expense_id", "received_at");
CREATE UNIQUE INDEX "estate_expense_requests_estate_id_id_key" ON "estate_expense_requests"("estate_id", "id");

ALTER TABLE "estate_expense_settlements" ADD CONSTRAINT "estate_expense_settlements_estate_id_expense_id_fkey"
  FOREIGN KEY ("estate_id", "expense_id") REFERENCES "estate_expense_requests"("estate_id", "id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "estate_expense_settlements" ADD CONSTRAINT "estate_expense_settlements_verified_by_id_fkey"
  FOREIGN KEY ("verified_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
