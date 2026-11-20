-- Phase 4 configurable services catalogue and demo vending orders.
-- Real provider vending is intentionally deferred; demo orders are clearly
-- labelled and post to an internal clearing account only.

CREATE TABLE "estate_service_definitions" (
  "id" UUID NOT NULL,
  "estate_id" UUID NOT NULL,
  "code" VARCHAR(40) NOT NULL,
  "name" VARCHAR(120) NOT NULL,
  "description" VARCHAR(500),
  "category" VARCHAR(40) NOT NULL,
  "provider" VARCHAR(60) NOT NULL,
  "amount" DECIMAL(12,2) NOT NULL,
  "currency" VARCHAR(3) NOT NULL,
  "demo" BOOLEAN NOT NULL DEFAULT true,
  "status" VARCHAR(20) NOT NULL,
  "created_by_id" UUID NOT NULL,
  "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "estate_service_definitions_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "estate_service_definitions_amount_check" CHECK ("amount" > 0),
  CONSTRAINT "estate_service_definitions_status_check"
    CHECK ("status" IN ('ACTIVE', 'INACTIVE'))
);
CREATE UNIQUE INDEX "estate_service_definitions_estate_code"
  ON "estate_service_definitions"("estate_id", "code");
CREATE INDEX "estate_service_definitions_estate_status_idx"
  ON "estate_service_definitions"("estate_id", "status");
ALTER TABLE "estate_service_definitions" ADD CONSTRAINT "estate_service_definitions_estate_fkey"
  FOREIGN KEY ("estate_id") REFERENCES "estates"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "estate_service_definitions" ADD CONSTRAINT "estate_service_definitions_creator_fkey"
  FOREIGN KEY ("created_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

CREATE TABLE "estate_service_orders" (
  "id" UUID NOT NULL,
  "estate_id" UUID NOT NULL,
  "service_id" UUID NOT NULL,
  "ordered_by" UUID NOT NULL,
  "amount" DECIMAL(12,2) NOT NULL,
  "currency" VARCHAR(3) NOT NULL,
  "status" VARCHAR(20) NOT NULL,
  "provider" VARCHAR(60) NOT NULL,
  "provider_reference" VARCHAR(180),
  "fulfilment_code" VARCHAR(80),
  "failure_reason" VARCHAR(500),
  "paid_at" TIMESTAMPTZ(3),
  "fulfilled_at" TIMESTAMPTZ(3),
  "idempotency_key_hash" VARCHAR(64) NOT NULL,
  "payload_hash" VARCHAR(64) NOT NULL,
  "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "estate_service_orders_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "estate_service_orders_amount_check" CHECK ("amount" > 0),
  CONSTRAINT "estate_service_orders_status_check"
    CHECK ("status" IN ('PENDING_PAYMENT', 'PAID', 'FULFILLED', 'FAILED', 'REFUNDED'))
);
CREATE UNIQUE INDEX "estate_service_orders_idempotency"
  ON "estate_service_orders"("estate_id", "ordered_by", "idempotency_key_hash");
CREATE INDEX "estate_service_orders_estate_status_idx"
  ON "estate_service_orders"("estate_id", "status");
CREATE INDEX "estate_service_orders_ordered_by_idx"
  ON "estate_service_orders"("ordered_by", "created_at");
ALTER TABLE "estate_service_orders" ADD CONSTRAINT "estate_service_orders_estate_fkey"
  FOREIGN KEY ("estate_id") REFERENCES "estates"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "estate_service_orders" ADD CONSTRAINT "estate_service_orders_service_fkey"
  FOREIGN KEY ("service_id") REFERENCES "estate_service_definitions"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "estate_service_orders" ADD CONSTRAINT "estate_service_orders_ordered_by_fkey"
  FOREIGN KEY ("ordered_by") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
