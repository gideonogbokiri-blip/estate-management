-- Platform-controlled manual balance ledger for resident/landlord accounts in an estate.
-- These are staff-entered adjustments, not provider payments.

CREATE TABLE "estate_account_adjustments" (
  "id" UUID NOT NULL,
  "estate_id" UUID NOT NULL,
  "account_user_id" UUID NOT NULL,
  "amount" DECIMAL(14,2) NOT NULL,
  "currency" VARCHAR(8) NOT NULL,
  "direction" VARCHAR(6) NOT NULL,
  "reason" VARCHAR(500) NOT NULL,
  "created_by_user_id" UUID NOT NULL,
  "idempotency_key_hash" VARCHAR(64) NOT NULL,
  "payload_hash" VARCHAR(64) NOT NULL,
  "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "estate_account_adjustments_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "estate_account_adjustments_amount_check" CHECK ("amount" > 0),
  CONSTRAINT "estate_account_adjustments_direction_check" CHECK ("direction" IN ('credit', 'debit')),
  CONSTRAINT "estate_account_adjustments_reason_check" CHECK (length(trim("reason")) >= 5)
);

CREATE UNIQUE INDEX "estate_account_adjustments_idempotency_key"
  ON "estate_account_adjustments"("created_by_user_id", "estate_id", "account_user_id", "idempotency_key_hash");
CREATE INDEX "estate_account_adjustments_account_idx"
  ON "estate_account_adjustments"("estate_id", "account_user_id", "created_at");
CREATE INDEX "estate_account_adjustments_estate_idx"
  ON "estate_account_adjustments"("estate_id", "created_at");

ALTER TABLE "estate_account_adjustments" ADD CONSTRAINT "estate_account_adjustments_estate_fkey"
  FOREIGN KEY ("estate_id") REFERENCES "estates"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "estate_account_adjustments" ADD CONSTRAINT "estate_account_adjustments_account_fkey"
  FOREIGN KEY ("account_user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "estate_account_adjustments" ADD CONSTRAINT "estate_account_adjustments_creator_fkey"
  FOREIGN KEY ("created_by_user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
