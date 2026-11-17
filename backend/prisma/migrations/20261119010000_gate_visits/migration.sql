CREATE TABLE "estate_gates" (
  "id" UUID NOT NULL,
  "estate_id" UUID NOT NULL,
  "code" VARCHAR(40) NOT NULL,
  "name" VARCHAR(120) NOT NULL,
  "active" BOOLEAN NOT NULL DEFAULT true,
  "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMPTZ(3) NOT NULL,
  CONSTRAINT "estate_gates_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "estate_gates_estate_id_fkey" FOREIGN KEY ("estate_id") REFERENCES "estates"("id") ON DELETE RESTRICT ON UPDATE CASCADE
);
CREATE UNIQUE INDEX "estate_gates_estate_id_code_key" ON "estate_gates"("estate_id", "code");
CREATE UNIQUE INDEX "estate_gates_estate_id_id_key" ON "estate_gates"("estate_id", "id");
CREATE INDEX "estate_gates_estate_id_active_idx" ON "estate_gates"("estate_id", "active");

CREATE TABLE "estate_gate_assignments" (
  "id" UUID NOT NULL,
  "estate_id" UUID NOT NULL,
  "gate_id" UUID NOT NULL,
  "user_id" UUID NOT NULL,
  "assigned_by_id" UUID NOT NULL,
  "active_from" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "active_to" TIMESTAMPTZ(3),
  "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "estate_gate_assignments_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "estate_gate_assignments_estate_id_fkey" FOREIGN KEY ("estate_id") REFERENCES "estates"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "estate_gate_assignments_gate_id_fkey" FOREIGN KEY ("gate_id") REFERENCES "estate_gates"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "estate_gate_assignments_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "estate_gate_assignments_assigned_by_id_fkey" FOREIGN KEY ("assigned_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE
);
CREATE INDEX "estate_gate_assignments_estate_id_gate_id_user_id_active_to_idx" ON "estate_gate_assignments"("estate_id", "gate_id", "user_id", "active_to");
CREATE INDEX "estate_gate_assignments_user_id_active_to_active_from_idx" ON "estate_gate_assignments"("user_id", "active_to", "active_from");

CREATE TABLE "estate_visitor_visits" (
  "id" UUID NOT NULL,
  "estate_id" UUID NOT NULL,
  "pass_id" UUID,
  "property_id" UUID NOT NULL,
  "gate_id" UUID NOT NULL,
  "admission_type" VARCHAR(20) NOT NULL DEFAULT 'pass',
  "visitor_display_name" VARCHAR(100) NOT NULL,
  "status" VARCHAR(20) NOT NULL DEFAULT 'checked_in',
  "checked_in_by_user_id" UUID NOT NULL,
  "checked_in_at" TIMESTAMPTZ(3) NOT NULL,
  "checked_out_by_user_id" UUID,
  "checked_out_at" TIMESTAMPTZ(3),
  "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "estate_visitor_visits_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "estate_visitor_visits_estate_id_fkey" FOREIGN KEY ("estate_id") REFERENCES "estates"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "estate_visitor_visits_pass_id_fkey" FOREIGN KEY ("pass_id") REFERENCES "estate_visitor_passes"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "estate_visitor_visits_property_id_fkey" FOREIGN KEY ("property_id") REFERENCES "estate_properties"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "estate_visitor_visits_gate_id_fkey" FOREIGN KEY ("gate_id") REFERENCES "estate_gates"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "estate_visitor_visits_checked_in_by_user_id_fkey" FOREIGN KEY ("checked_in_by_user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "estate_visitor_visits_checked_out_by_user_id_fkey" FOREIGN KEY ("checked_out_by_user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE
);
CREATE INDEX "estate_visitor_visits_estate_id_gate_id_status_checked_in_at_idx" ON "estate_visitor_visits"("estate_id", "gate_id", "status", "checked_in_at");
CREATE INDEX "estate_visitor_visits_estate_id_pass_id_status_idx" ON "estate_visitor_visits"("estate_id", "pass_id", "status");
CREATE UNIQUE INDEX "estate_visitor_visits_one_active_pass_key" ON "estate_visitor_visits"("estate_id", "pass_id") WHERE "status" = 'checked_in' AND "pass_id" IS NOT NULL;

CREATE TABLE "estate_access_events" (
  "id" UUID NOT NULL,
  "estate_id" UUID NOT NULL,
  "pass_id" UUID,
  "visit_id" UUID,
  "property_id" UUID,
  "gate_id" UUID NOT NULL,
  "staff_user_id" UUID NOT NULL,
  "event_kind" VARCHAR(30) NOT NULL,
  "reason_code" VARCHAR(80),
  "occurred_at" TIMESTAMPTZ(3) NOT NULL,
  CONSTRAINT "estate_access_events_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "estate_access_events_estate_id_fkey" FOREIGN KEY ("estate_id") REFERENCES "estates"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "estate_access_events_gate_id_fkey" FOREIGN KEY ("gate_id") REFERENCES "estate_gates"("id") ON DELETE RESTRICT ON UPDATE CASCADE
);
CREATE INDEX "estate_access_events_estate_id_gate_id_occurred_at_idx" ON "estate_access_events"("estate_id", "gate_id", "occurred_at");
CREATE INDEX "estate_access_events_estate_id_pass_id_occurred_at_idx" ON "estate_access_events"("estate_id", "pass_id", "occurred_at");

CREATE TABLE "estate_gate_check_in_idempotency" (
  "id" UUID NOT NULL,
  "actor_user_id" UUID NOT NULL,
  "estate_id" UUID NOT NULL,
  "gate_id" UUID NOT NULL,
  "idempotency_key_hash" VARCHAR(64) NOT NULL,
  "credential_hash" VARCHAR(64) NOT NULL,
  "state" VARCHAR(20) NOT NULL,
  "result" JSONB,
  "expires_at" TIMESTAMPTZ(3) NOT NULL,
  "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "estate_gate_check_in_idempotency_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "estate_gate_check_in_idempotency_actor_user_id_fkey" FOREIGN KEY ("actor_user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "estate_gate_check_in_idempotency_estate_id_fkey" FOREIGN KEY ("estate_id") REFERENCES "estates"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "estate_gate_check_in_idempotency_gate_id_fkey" FOREIGN KEY ("gate_id") REFERENCES "estate_gates"("id") ON DELETE RESTRICT ON UPDATE CASCADE
);
CREATE UNIQUE INDEX "estate_gate_check_in_idempotency_scope_key" ON "estate_gate_check_in_idempotency"("actor_user_id", "estate_id", "gate_id", "idempotency_key_hash");
CREATE INDEX "estate_gate_check_in_idempotency_expires_at_idx" ON "estate_gate_check_in_idempotency"("expires_at");

CREATE TABLE "estate_gate_verification_attempts" (
  "id" UUID NOT NULL,
  "estate_id" UUID NOT NULL,
  "gate_id" UUID NOT NULL,
  "device_hash" VARCHAR(64) NOT NULL,
  "credential_fingerprint" VARCHAR(64) NOT NULL,
  "window_started_at" TIMESTAMPTZ(3) NOT NULL,
  "attempts" INTEGER NOT NULL DEFAULT 1,
  "updated_at" TIMESTAMPTZ(3) NOT NULL,
  CONSTRAINT "estate_gate_verification_attempts_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "estate_gate_verification_attempts_window_key" ON "estate_gate_verification_attempts"("estate_id", "gate_id", "device_hash", "credential_fingerprint", "window_started_at");
CREATE INDEX "estate_gate_verification_attempts_updated_at_idx" ON "estate_gate_verification_attempts"("updated_at");
