-- Phase 1 P0: authoritative double-entry ledger, funding intents and provider
-- webhook replay protection. Additive; existing wallet records remain valid.

CREATE TABLE "ledger_journals" (
  "id" UUID NOT NULL,
  "estate_id" UUID,
  "reference" VARCHAR(180) NOT NULL,
  "source_type" VARCHAR(40) NOT NULL,
  "source_id" VARCHAR(180),
  "description" VARCHAR(300) NOT NULL,
  "currency" VARCHAR(3) NOT NULL,
  "status" VARCHAR(20) NOT NULL DEFAULT 'posted',
  "reversed_by_journal_id" UUID,
  "occurred_at" TIMESTAMPTZ(3) NOT NULL,
  "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "ledger_journals_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "ledger_journals_status_check" CHECK ("status" IN ('posted', 'reversed'))
);
CREATE UNIQUE INDEX "ledger_journals_reference_key" ON "ledger_journals"("reference");
CREATE INDEX "ledger_journals_estate_created_idx" ON "ledger_journals"("estate_id", "created_at");
ALTER TABLE "ledger_journals" ADD CONSTRAINT "ledger_journals_estate_fkey"
  FOREIGN KEY ("estate_id") REFERENCES "estates"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

CREATE TABLE "ledger_entries" (
  "id" UUID NOT NULL,
  "journal_id" UUID NOT NULL,
  "account_code" VARCHAR(120) NOT NULL,
  "direction" VARCHAR(6) NOT NULL,
  "amount" DECIMAL(14,2) NOT NULL,
  "currency" VARCHAR(3) NOT NULL,
  "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "ledger_entries_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "ledger_entries_direction_check" CHECK ("direction" IN ('debit', 'credit')),
  CONSTRAINT "ledger_entries_amount_check" CHECK ("amount" > 0)
);
CREATE INDEX "ledger_entries_journal_idx" ON "ledger_entries"("journal_id");
CREATE INDEX "ledger_entries_account_idx" ON "ledger_entries"("account_code", "created_at");
ALTER TABLE "ledger_entries" ADD CONSTRAINT "ledger_entries_journal_fkey"
  FOREIGN KEY ("journal_id") REFERENCES "ledger_journals"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

CREATE TABLE "wallet_funding_intents" (
  "id" UUID NOT NULL,
  "wallet_id" UUID NOT NULL,
  "estate_id" UUID NOT NULL,
  "user_id" UUID NOT NULL,
  "amount" DECIMAL(14,2) NOT NULL,
  "currency" VARCHAR(3) NOT NULL,
  "status" VARCHAR(20) NOT NULL DEFAULT 'pending',
  "provider_reference" VARCHAR(180),
  "idempotency_key_hash" VARCHAR(64) NOT NULL,
  "expires_at" TIMESTAMPTZ(3) NOT NULL,
  "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "wallet_funding_intents_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "wallet_funding_intents_amount_check" CHECK ("amount" > 0),
  CONSTRAINT "wallet_funding_intents_status_check"
    CHECK ("status" IN ('pending', 'awaiting_provider', 'completed', 'failed', 'expired'))
);
CREATE UNIQUE INDEX "wallet_funding_intents_idempotency_key"
  ON "wallet_funding_intents"("user_id", "estate_id", "idempotency_key_hash");
CREATE UNIQUE INDEX "wallet_funding_intents_provider_reference_key"
  ON "wallet_funding_intents"("provider_reference") WHERE "provider_reference" IS NOT NULL;
ALTER TABLE "wallet_funding_intents" ADD CONSTRAINT "wallet_funding_intents_wallet_fkey"
  FOREIGN KEY ("wallet_id") REFERENCES "estate_wallets"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "wallet_funding_intents" ADD CONSTRAINT "wallet_funding_intents_estate_fkey"
  FOREIGN KEY ("estate_id") REFERENCES "estates"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "wallet_funding_intents" ADD CONSTRAINT "wallet_funding_intents_user_fkey"
  FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

CREATE TABLE "provider_webhook_events" (
  "id" UUID NOT NULL,
  "provider" VARCHAR(30) NOT NULL,
  "event_id" VARCHAR(180) NOT NULL,
  "event_type" VARCHAR(80) NOT NULL,
  "status" VARCHAR(20) NOT NULL,
  "payload" JSONB NOT NULL,
  "error" VARCHAR(500),
  "received_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "processed_at" TIMESTAMPTZ(3),
  CONSTRAINT "provider_webhook_events_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "provider_webhook_events_unique" UNIQUE ("provider", "event_id")
);

ALTER TABLE "estate_wallet_transactions" ADD COLUMN "journal_id" UUID;
CREATE INDEX "estate_wallet_transactions_journal_idx" ON "estate_wallet_transactions"("journal_id");
ALTER TABLE "estate_wallet_transactions" ADD CONSTRAINT "estate_wallet_transactions_journal_fkey"
  FOREIGN KEY ("journal_id") REFERENCES "ledger_journals"("id") ON DELETE SET NULL ON UPDATE CASCADE;
