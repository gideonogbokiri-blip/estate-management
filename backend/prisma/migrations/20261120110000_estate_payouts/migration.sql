-- Phase 2: estate payout requests, approvals and provider executions.
-- Initiation, approval and execution remain separable permissions.

CREATE TABLE "estate_payout_beneficiaries" (
  "id" UUID NOT NULL,
  "estate_id" UUID NOT NULL,
  "display_name" VARCHAR(160) NOT NULL,
  "bank_name" VARCHAR(120) NOT NULL,
  "account_number" VARCHAR(34) NOT NULL,
  "account_reference" VARCHAR(120) NOT NULL,
  "active" BOOLEAN NOT NULL DEFAULT true,
  "verified_at" TIMESTAMPTZ(3),
  "verified_by" UUID,
  "created_by" UUID NOT NULL,
  "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "estate_payout_beneficiaries_pkey" PRIMARY KEY ("id")
);
CREATE INDEX "estate_payout_beneficiaries_estate_idx" ON "estate_payout_beneficiaries"("estate_id", "active");
ALTER TABLE "estate_payout_beneficiaries" ADD CONSTRAINT "estate_payout_beneficiaries_estate_fkey"
  FOREIGN KEY ("estate_id") REFERENCES "estates"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

CREATE TABLE "estate_payout_policies" (
  "id" UUID NOT NULL,
  "estate_id" UUID NOT NULL,
  "threshold" DECIMAL(14,2) NOT NULL,
  "required_approvals" INT NOT NULL DEFAULT 1,
  "updated_by" UUID NOT NULL,
  "updated_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "estate_payout_policies_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "estate_payout_policies_unique" UNIQUE ("estate_id"),
  CONSTRAINT "estate_payout_policies_threshold_check" CHECK ("threshold" > 0),
  CONSTRAINT "estate_payout_policies_approvals_check" CHECK ("required_approvals" BETWEEN 1 AND 3)
);

CREATE TABLE "estate_payout_requests" (
  "id" UUID NOT NULL,
  "estate_id" UUID NOT NULL,
  "beneficiary_id" UUID NOT NULL,
  "amount" DECIMAL(14,2) NOT NULL,
  "currency" VARCHAR(3) NOT NULL,
  "purpose" VARCHAR(500) NOT NULL,
  "fund_category" VARCHAR(60) NOT NULL DEFAULT 'estate_operations',
  "status" VARCHAR(20) NOT NULL DEFAULT 'pending_approval',
  "initiated_by" UUID NOT NULL,
  "idempotency_key_hash" VARCHAR(64) NOT NULL,
  "policy_snapshot" JSONB NOT NULL,
  "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "estate_payout_requests_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "estate_payout_requests_amount_check" CHECK ("amount" > 0),
  CONSTRAINT "estate_payout_requests_status_check"
    CHECK ("status" IN ('pending_approval', 'approved', 'rejected', 'executing', 'paid', 'failed'))
);
CREATE INDEX "estate_payout_requests_estate_status_idx" ON "estate_payout_requests"("estate_id", "status", "created_at");
CREATE UNIQUE INDEX "estate_payout_requests_idempotency_key"
  ON "estate_payout_requests"("estate_id", "initiated_by", "idempotency_key_hash");
ALTER TABLE "estate_payout_requests" ADD CONSTRAINT "estate_payout_requests_estate_fkey"
  FOREIGN KEY ("estate_id") REFERENCES "estates"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "estate_payout_requests" ADD CONSTRAINT "estate_payout_requests_beneficiary_fkey"
  FOREIGN KEY ("beneficiary_id") REFERENCES "estate_payout_beneficiaries"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

CREATE TABLE "estate_payout_approvals" (
  "id" UUID NOT NULL,
  "payout_id" UUID NOT NULL,
  "approver_id" UUID NOT NULL,
  "decision" VARCHAR(10) NOT NULL,
  "note" VARCHAR(500),
  "occurred_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "estate_payout_approvals_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "estate_payout_approvals_unique" UNIQUE ("payout_id", "approver_id"),
  CONSTRAINT "estate_payout_approvals_decision_check" CHECK ("decision" IN ('approve', 'reject'))
);
ALTER TABLE "estate_payout_approvals" ADD CONSTRAINT "estate_payout_approvals_payout_fkey"
  FOREIGN KEY ("payout_id") REFERENCES "estate_payout_requests"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

CREATE TABLE "estate_payout_executions" (
  "id" UUID NOT NULL,
  "payout_id" UUID NOT NULL,
  "provider" VARCHAR(30) NOT NULL,
  "provider_reference" VARCHAR(180),
  "status" VARCHAR(20) NOT NULL,
  "provider_response" JSONB,
  "executed_by" UUID NOT NULL,
  "executed_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "estate_payout_executions_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "estate_payout_executions_payout_unique" UNIQUE ("payout_id")
);
ALTER TABLE "estate_payout_executions" ADD CONSTRAINT "estate_payout_executions_payout_fkey"
  FOREIGN KEY ("payout_id") REFERENCES "estate_payout_requests"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
