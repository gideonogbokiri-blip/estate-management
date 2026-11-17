CREATE TABLE "estate_visitor_passes" (
  "id" UUID NOT NULL,
  "estate_id" UUID NOT NULL,
  "property_id" UUID NOT NULL,
  "host_user_id" UUID NOT NULL,
  "visitor_display_name" VARCHAR(100) NOT NULL,
  "credential_hash" VARCHAR(64) NOT NULL,
  "valid_from" TIMESTAMPTZ(3) NOT NULL,
  "valid_until" TIMESTAMPTZ(3) NOT NULL,
  "allowed_uses" INTEGER NOT NULL DEFAULT 1,
  "use_count" INTEGER NOT NULL DEFAULT 0,
  "revoked_at" TIMESTAMPTZ(3),
  "vehicle_summary" VARCHAR(80),
  "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "estate_visitor_passes_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "estate_visitor_passes_estate_id_fkey" FOREIGN KEY ("estate_id") REFERENCES "estates"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "estate_visitor_passes_property_id_fkey" FOREIGN KEY ("property_id") REFERENCES "estate_properties"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "estate_visitor_passes_host_user_id_fkey" FOREIGN KEY ("host_user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE
);
CREATE UNIQUE INDEX "estate_visitor_passes_credential_hash_key" ON "estate_visitor_passes"("credential_hash");
CREATE INDEX "estate_visitor_passes_estate_id_host_user_id_created_at_idx" ON "estate_visitor_passes"("estate_id", "host_user_id", "created_at");
CREATE INDEX "estate_visitor_passes_estate_id_property_id_valid_until_idx" ON "estate_visitor_passes"("estate_id", "property_id", "valid_until");

CREATE TABLE "estate_visitor_pass_idempotency" (
  "id" UUID NOT NULL,
  "actor_user_id" UUID NOT NULL,
  "estate_id" UUID NOT NULL,
  "idempotency_key_hash" VARCHAR(64) NOT NULL,
  "payload_hash" VARCHAR(64) NOT NULL,
  "state" VARCHAR(20) NOT NULL,
  "pass_id" UUID,
  "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMPTZ(3) NOT NULL,
  CONSTRAINT "estate_visitor_pass_idempotency_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "estate_visitor_pass_idempotency_actor_user_id_fkey" FOREIGN KEY ("actor_user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "estate_visitor_pass_idempotency_estate_id_fkey" FOREIGN KEY ("estate_id") REFERENCES "estates"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "estate_visitor_pass_idempotency_pass_id_fkey" FOREIGN KEY ("pass_id") REFERENCES "estate_visitor_passes"("id") ON DELETE RESTRICT ON UPDATE CASCADE
);
CREATE UNIQUE INDEX "estate_visitor_pass_idempotency_actor_user_id_estate_id_idempotency_key_hash_key" ON "estate_visitor_pass_idempotency"("actor_user_id", "estate_id", "idempotency_key_hash");
CREATE UNIQUE INDEX "estate_visitor_pass_idempotency_pass_id_key" ON "estate_visitor_pass_idempotency"("pass_id");
CREATE INDEX "estate_visitor_pass_idempotency_estate_id_created_at_idx" ON "estate_visitor_pass_idempotency"("estate_id", "created_at");
