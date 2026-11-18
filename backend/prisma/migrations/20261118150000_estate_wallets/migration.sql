-- Estate fund accounts: one wallet per resident/landlord per estate and currency.
-- Account numbers are issued by Paystack dedicated virtual accounts; no local
-- bank details are generated.

CREATE TABLE "estate_wallets" (
  "id" UUID NOT NULL,
  "estate_id" UUID NOT NULL,
  "user_id" UUID NOT NULL,
  "currency" VARCHAR(3) NOT NULL,
  "account_number" VARCHAR(34),
  "bank_name" VARCHAR(120),
  "account_name" VARCHAR(160),
  "provider_reference" VARCHAR(120),
  "status" VARCHAR(20) NOT NULL DEFAULT 'pending',
  "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "estate_wallets_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "estate_wallets_status_check" CHECK ("status" IN ('pending', 'active', 'closed'))
);

CREATE UNIQUE INDEX "estate_wallets_estate_user_currency_key"
  ON "estate_wallets"("estate_id", "user_id", "currency");
CREATE UNIQUE INDEX "estate_wallets_account_number_key"
  ON "estate_wallets"("account_number") WHERE "account_number" IS NOT NULL;

ALTER TABLE "estate_wallets" ADD CONSTRAINT "estate_wallets_estate_fkey"
  FOREIGN KEY ("estate_id") REFERENCES "estates"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "estate_wallets" ADD CONSTRAINT "estate_wallets_user_fkey"
  FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

CREATE TABLE "estate_wallet_transactions" (
  "id" UUID NOT NULL,
  "wallet_id" UUID NOT NULL,
  "estate_id" UUID NOT NULL,
  "type" VARCHAR(6) NOT NULL,
  "amount" DECIMAL(14,2) NOT NULL,
  "currency" VARCHAR(3) NOT NULL,
  "reference" VARCHAR(180) NOT NULL,
  "description" VARCHAR(300) NOT NULL,
  "source_type" VARCHAR(30) NOT NULL,
  "source_id" VARCHAR(180),
  "status" VARCHAR(20) NOT NULL DEFAULT 'posted',
  "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "estate_wallet_transactions_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "estate_wallet_transactions_type_check" CHECK ("type" IN ('credit', 'debit')),
  CONSTRAINT "estate_wallet_transactions_amount_check" CHECK ("amount" > 0)
);

CREATE UNIQUE INDEX "estate_wallet_transactions_reference_key"
  ON "estate_wallet_transactions"("reference");
CREATE INDEX "estate_wallet_transactions_wallet_created_idx"
  ON "estate_wallet_transactions"("wallet_id", "created_at");

ALTER TABLE "estate_wallet_transactions" ADD CONSTRAINT "estate_wallet_transactions_wallet_fkey"
  FOREIGN KEY ("wallet_id") REFERENCES "estate_wallets"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "estate_wallet_transactions" ADD CONSTRAINT "estate_wallet_transactions_estate_fkey"
  FOREIGN KEY ("estate_id") REFERENCES "estates"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
