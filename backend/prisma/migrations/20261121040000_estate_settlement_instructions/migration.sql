CREATE TYPE "EstateSettlementPolicyStatus" AS ENUM ('DRAFT', 'ACTIVE', 'RETIRED');

CREATE TABLE "estate_settlement_policies" (
    "id" UUID NOT NULL,
    "estate_id" UUID NOT NULL,
    "currency" VARCHAR(3) NOT NULL,
    "bank_name" VARCHAR(100) NOT NULL,
    "account_name" VARCHAR(120) NOT NULL,
    "account_number" VARCHAR(34) NOT NULL,
    "payment_reference_format" VARCHAR(200) NOT NULL,
    "status" "EstateSettlementPolicyStatus" NOT NULL DEFAULT 'DRAFT',
    "created_by_id" UUID NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,
    CONSTRAINT "estate_settlement_policies_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "estate_settlement_policies_estate_id_currency_status_idx"
    ON "estate_settlement_policies"("estate_id", "currency", "status");
CREATE UNIQUE INDEX "estate_settlement_policies_one_active_currency_key"
    ON "estate_settlement_policies"("estate_id", "currency") WHERE "status" = 'ACTIVE';
ALTER TABLE "estate_settlement_policies" ADD CONSTRAINT "estate_settlement_policies_estate_id_fkey"
    FOREIGN KEY ("estate_id") REFERENCES "estates"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "estate_settlement_policies" ADD CONSTRAINT "estate_settlement_policies_created_by_id_fkey"
    FOREIGN KEY ("created_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "estate_invoice_drafts"
    ADD COLUMN "settlement_policy_id" UUID,
    ADD COLUMN "settlement_snapshot" JSONB,
    ADD COLUMN "issued_at" TIMESTAMPTZ(3);
ALTER TABLE "estate_invoice_drafts" ADD CONSTRAINT "estate_invoice_drafts_settlement_policy_id_fkey"
    FOREIGN KEY ("settlement_policy_id") REFERENCES "estate_settlement_policies"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
