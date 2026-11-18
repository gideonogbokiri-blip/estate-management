-- Operator-issued account lifecycle codes (email verification and password reset).
-- Codes are shown once and stored only as hashes.

CREATE TABLE "account_recovery_codes" (
  "id" UUID NOT NULL,
  "user_id" UUID NOT NULL,
  "purpose" VARCHAR(24) NOT NULL,
  "code_hash" VARCHAR(64) NOT NULL,
  "expires_at" TIMESTAMPTZ(3) NOT NULL,
  "used_at" TIMESTAMPTZ(3),
  "created_by_user_id" UUID,
  "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "account_recovery_codes_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "account_recovery_codes_purpose_check"
    CHECK ("purpose" IN ('email_verification', 'password_reset'))
);

CREATE INDEX "account_recovery_codes_user_purpose_idx"
  ON "account_recovery_codes"("user_id", "purpose", "created_at");
CREATE INDEX "account_recovery_codes_expires_idx"
  ON "account_recovery_codes"("expires_at");

ALTER TABLE "account_recovery_codes" ADD CONSTRAINT "account_recovery_codes_user_fkey"
  FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "account_recovery_codes" ADD CONSTRAINT "account_recovery_codes_creator_fkey"
  FOREIGN KEY ("created_by_user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
