-- Phase 2 rent engine: deterministic, idempotent rent schedules generated from
-- approved tenancies, with separate rent receipts and landlord entitlement.

CREATE TABLE "rent_schedules" (
  "id" UUID NOT NULL,
  "estate_id" UUID NOT NULL,
  "tenancy_id" UUID NOT NULL,
  "tenant_user_id" UUID NOT NULL,
  "payee_user_id" UUID NOT NULL,
  "property_id" UUID NOT NULL,
  "amount" DECIMAL(12,2) NOT NULL,
  "currency" VARCHAR(3) NOT NULL,
  "frequency" VARCHAR(12) NOT NULL,
  "period_start" DATE NOT NULL,
  "period_end" DATE NOT NULL,
  "due_date" DATE NOT NULL,
  "status" VARCHAR(20) NOT NULL DEFAULT 'scheduled',
  "idempotency_key" VARCHAR(180) NOT NULL,
  "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "rent_schedules_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "rent_schedules_amount_check" CHECK ("amount" > 0),
  CONSTRAINT "rent_schedules_period_check" CHECK ("period_end" > "period_start"),
  CONSTRAINT "rent_schedules_status_check"
    CHECK ("status" IN ('scheduled', 'partially_paid', 'paid', 'cancelled'))
);
CREATE UNIQUE INDEX "rent_schedules_idempotency_key" ON "rent_schedules"("idempotency_key");
CREATE INDEX "rent_schedules_estate_due_idx" ON "rent_schedules"("estate_id", "due_date");
CREATE INDEX "rent_schedules_tenant_idx" ON "rent_schedules"("tenant_user_id", "due_date");
CREATE INDEX "rent_schedules_payee_idx" ON "rent_schedules"("payee_user_id", "due_date");
ALTER TABLE "rent_schedules" ADD CONSTRAINT "rent_schedules_estate_fkey"
  FOREIGN KEY ("estate_id") REFERENCES "estates"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "rent_schedules" ADD CONSTRAINT "rent_schedules_tenancy_fkey"
  FOREIGN KEY ("tenancy_id") REFERENCES "estate_tenancies"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

CREATE TABLE "rent_payments" (
  "id" UUID NOT NULL,
  "schedule_id" UUID NOT NULL,
  "estate_id" UUID NOT NULL,
  "amount" DECIMAL(12,2) NOT NULL,
  "currency" VARCHAR(3) NOT NULL,
  "paid_by" UUID NOT NULL,
  "payment_reference" VARCHAR(180) NOT NULL,
  "receipt_number" VARCHAR(40) NOT NULL,
  "received_at" TIMESTAMPTZ(3) NOT NULL,
  "source_type" VARCHAR(30) NOT NULL DEFAULT 'wallet',
  "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "rent_payments_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "rent_payments_amount_check" CHECK ("amount" > 0)
);
CREATE UNIQUE INDEX "rent_payments_reference_key" ON "rent_payments"("payment_reference");
CREATE UNIQUE INDEX "rent_payments_receipt_key" ON "rent_payments"("receipt_number");
CREATE INDEX "rent_payments_schedule_idx" ON "rent_payments"("schedule_id", "received_at");
ALTER TABLE "rent_payments" ADD CONSTRAINT "rent_payments_schedule_fkey"
  FOREIGN KEY ("schedule_id") REFERENCES "rent_schedules"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
