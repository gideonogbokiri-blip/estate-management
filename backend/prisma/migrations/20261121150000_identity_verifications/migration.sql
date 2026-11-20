-- Phase 3 consent-based identity verification records.
-- Stores provider tokens/results, not biometric templates or identity documents.

CREATE TABLE "identity_verifications" (
  "id" UUID NOT NULL,
  "estate_id" UUID NOT NULL,
  "user_id" UUID NOT NULL,
  "method" VARCHAR(30) NOT NULL,
  "provider" VARCHAR(60) NOT NULL,
  "provider_reference" VARCHAR(180),
  "level" VARCHAR(20) NOT NULL,
  "consent_given" BOOLEAN NOT NULL,
  "consent_at" TIMESTAMPTZ(3) NOT NULL,
  "status" VARCHAR(20) NOT NULL DEFAULT 'PENDING',
  "decided_by_id" UUID,
  "decided_at" TIMESTAMPTZ(3),
  "decision_reason" VARCHAR(500),
  "submitted_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "identity_verifications_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "identity_verifications_method_check"
    CHECK ("method" IN ('DEMO_DECLARATION', 'PROVIDER_TOKEN', 'DOCUMENT_REVIEW')),
  CONSTRAINT "identity_verifications_level_check" CHECK ("level" IN ('BASIC', 'ENHANCED')),
  CONSTRAINT "identity_verifications_status_check"
    CHECK ("status" IN ('PENDING', 'VERIFIED', 'REJECTED', 'EXPIRED')),
  CONSTRAINT "identity_verifications_consent_check" CHECK ("consent_given" = true)
);
CREATE INDEX "identity_verifications_estate_status_idx"
  ON "identity_verifications"("estate_id", "status");
CREATE INDEX "identity_verifications_user_submitted_idx"
  ON "identity_verifications"("user_id", "submitted_at");
ALTER TABLE "identity_verifications" ADD CONSTRAINT "identity_verifications_estate_fkey"
  FOREIGN KEY ("estate_id") REFERENCES "estates"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "identity_verifications" ADD CONSTRAINT "identity_verifications_user_fkey"
  FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "identity_verifications" ADD CONSTRAINT "identity_verifications_decided_by_fkey"
  FOREIGN KEY ("decided_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
