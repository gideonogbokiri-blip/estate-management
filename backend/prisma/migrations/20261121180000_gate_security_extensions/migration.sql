-- Additive gate security extensions: manual admission idempotency and estate security contacts.

CREATE TABLE "estate_gate_manual_admission_idempotency" (
  "id" UUID NOT NULL,
  "actor_user_id" UUID NOT NULL,
  "estate_id" UUID NOT NULL,
  "gate_id" UUID NOT NULL,
  "idempotency_key_hash" VARCHAR(64) NOT NULL,
  "payload_hash" VARCHAR(64) NOT NULL,
  "state" VARCHAR(20) NOT NULL,
  "result" JSONB,
  "expires_at" TIMESTAMPTZ(3) NOT NULL,
  "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "estate_gate_manual_admission_idempotency_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "estate_gate_manual_admission_idempotency_state_check"
    CHECK ("state" IN ('claimed', 'completed'))
);

CREATE UNIQUE INDEX "estate_gate_manual_admission_idempotency_scope_key"
  ON "estate_gate_manual_admission_idempotency"("actor_user_id", "estate_id", "gate_id", "idempotency_key_hash");
CREATE INDEX "estate_gate_manual_admission_idempotency_expires_at_idx"
  ON "estate_gate_manual_admission_idempotency"("expires_at");

ALTER TABLE "estate_gate_manual_admission_idempotency" ADD CONSTRAINT "estate_gate_manual_admission_idempotency_actor_fkey"
  FOREIGN KEY ("actor_user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "estate_gate_manual_admission_idempotency" ADD CONSTRAINT "estate_gate_manual_admission_idempotency_estate_fkey"
  FOREIGN KEY ("estate_id") REFERENCES "estates"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "estate_gate_manual_admission_idempotency" ADD CONSTRAINT "estate_gate_manual_admission_idempotency_gate_fkey"
  FOREIGN KEY ("gate_id") REFERENCES "estate_gates"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

CREATE TABLE "estate_security_contacts" (
  "id" UUID NOT NULL,
  "estate_id" UUID NOT NULL,
  "label" VARCHAR(80) NOT NULL,
  "display_name" VARCHAR(120) NOT NULL,
  "phone_display" VARCHAR(50) NOT NULL,
  "active" BOOLEAN NOT NULL DEFAULT true,
  "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "estate_security_contacts_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "estate_security_contacts_nonempty_check"
    CHECK (length(trim("label")) > 0 AND length(trim("display_name")) > 0 AND length(trim("phone_display")) > 0)
);

CREATE UNIQUE INDEX "estate_security_contacts_estate_id_label_key"
  ON "estate_security_contacts"("estate_id", "label");
CREATE INDEX "estate_security_contacts_estate_id_active_idx"
  ON "estate_security_contacts"("estate_id", "active");

ALTER TABLE "estate_security_contacts" ADD CONSTRAINT "estate_security_contacts_estate_fkey"
  FOREIGN KEY ("estate_id") REFERENCES "estates"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
