CREATE TYPE "MaintenanceRequestStatus" AS ENUM (
  'SUBMITTED', 'UNDER_REVIEW', 'ASSIGNED', 'IN_PROGRESS', 'AWAITING_PARTS',
  'RESOLVED', 'CLOSED', 'REJECTED', 'REOPENED'
);

CREATE TYPE "MaintenanceUpdateVisibility" AS ENUM ('RESIDENT_VISIBLE', 'INTERNAL');

CREATE UNIQUE INDEX "estate_properties_estate_id_id_key" ON "estate_properties"("estate_id", "id");

CREATE TABLE "estate_maintenance_requests" (
  "id" UUID NOT NULL,
  "estate_id" UUID NOT NULL,
  "property_id" UUID NOT NULL,
  "requester_user_id" UUID NOT NULL,
  "assignee_user_id" UUID,
  "reference" VARCHAR(40) NOT NULL,
  "category" VARCHAR(40) NOT NULL,
  "priority" VARCHAR(20) NOT NULL,
  "description" VARCHAR(700) NOT NULL,
  "status" "MaintenanceRequestStatus" NOT NULL DEFAULT 'SUBMITTED',
  "submitted_at" TIMESTAMPTZ(3) NOT NULL,
  "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMPTZ(3) NOT NULL,
  CONSTRAINT "estate_maintenance_requests_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "estate_maintenance_requests_estate_id_fkey" FOREIGN KEY ("estate_id") REFERENCES "estates"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "estate_maintenance_requests_property_id_fkey" FOREIGN KEY ("property_id") REFERENCES "estate_properties"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "estate_maintenance_requests_requester_user_id_fkey" FOREIGN KEY ("requester_user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "estate_maintenance_requests_assignee_user_id_fkey" FOREIGN KEY ("assignee_user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "estate_maintenance_requests_category_check" CHECK ("category" IN ('plumbing', 'electrical', 'security', 'cleaning', 'other')),
  CONSTRAINT "estate_maintenance_requests_priority_check" CHECK ("priority" IN ('normal', 'high', 'urgent')),
  CONSTRAINT "estate_maintenance_requests_estate_property_fkey" FOREIGN KEY ("estate_id", "property_id") REFERENCES "estate_properties"("estate_id", "id") ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE "estate_maintenance_updates" (
  "id" UUID NOT NULL,
  "request_id" UUID NOT NULL,
  "author_id" UUID NOT NULL,
  "visibility" "MaintenanceUpdateVisibility" NOT NULL,
  "body" VARCHAR(700) NOT NULL,
  "occurred_at" TIMESTAMPTZ(3) NOT NULL,
  CONSTRAINT "estate_maintenance_updates_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "estate_maintenance_updates_request_id_fkey" FOREIGN KEY ("request_id") REFERENCES "estate_maintenance_requests"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "estate_maintenance_updates_author_id_fkey" FOREIGN KEY ("author_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE "estate_maintenance_history" (
  "id" UUID NOT NULL,
  "request_id" UUID NOT NULL,
  "actor_user_id" UUID NOT NULL,
  "from_status" "MaintenanceRequestStatus",
  "to_status" "MaintenanceRequestStatus" NOT NULL,
  "reason" VARCHAR(1000),
  "occurred_at" TIMESTAMPTZ(3) NOT NULL,
  CONSTRAINT "estate_maintenance_history_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "estate_maintenance_history_request_id_fkey" FOREIGN KEY ("request_id") REFERENCES "estate_maintenance_requests"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "estate_maintenance_history_actor_user_id_fkey" FOREIGN KEY ("actor_user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE "estate_maintenance_idempotency" (
  "id" UUID NOT NULL,
  "actor_user_id" UUID NOT NULL,
  "estate_id" UUID NOT NULL,
  "idempotency_key_hash" VARCHAR(64) NOT NULL,
  "payload_hash" VARCHAR(64) NOT NULL,
  "state" VARCHAR(20) NOT NULL,
  "result" JSONB,
  "request_id" UUID,
  "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMPTZ(3) NOT NULL,
  CONSTRAINT "estate_maintenance_idempotency_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "estate_maintenance_idempotency_actor_user_id_fkey" FOREIGN KEY ("actor_user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "estate_maintenance_idempotency_request_id_fkey" FOREIGN KEY ("request_id") REFERENCES "estate_maintenance_requests"("id") ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE "estate_maintenance_notice_outbox" (
  "id" UUID NOT NULL,
  "estate_id" UUID NOT NULL,
  "request_id" UUID NOT NULL,
  "event_type" VARCHAR(100) NOT NULL,
  "payload" JSONB NOT NULL,
  "state" VARCHAR(20) NOT NULL DEFAULT 'queued',
  "attempts" INTEGER NOT NULL DEFAULT 0,
  "available_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "processed_at" TIMESTAMPTZ(3),
  "last_error" VARCHAR(500),
  CONSTRAINT "estate_maintenance_notice_outbox_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "estate_maintenance_notice_outbox_estate_id_fkey" FOREIGN KEY ("estate_id") REFERENCES "estates"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "estate_maintenance_notice_outbox_request_id_fkey" FOREIGN KEY ("request_id") REFERENCES "estate_maintenance_requests"("id") ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE UNIQUE INDEX "estate_maintenance_requests_estate_id_reference_key" ON "estate_maintenance_requests"("estate_id", "reference");
CREATE INDEX "estate_maintenance_requests_estate_id_status_submitted_at_idx" ON "estate_maintenance_requests"("estate_id", "status", "submitted_at");
CREATE INDEX "estate_maintenance_requests_requester_user_id_estate_id_submitted_at_idx" ON "estate_maintenance_requests"("requester_user_id", "estate_id", "submitted_at");
CREATE INDEX "estate_maintenance_requests_property_id_status_submitted_at_idx" ON "estate_maintenance_requests"("property_id", "status", "submitted_at");
CREATE INDEX "estate_maintenance_requests_assignee_user_id_status_submitted_at_idx" ON "estate_maintenance_requests"("assignee_user_id", "status", "submitted_at");
CREATE INDEX "estate_maintenance_updates_request_id_visibility_occurred_at_idx" ON "estate_maintenance_updates"("request_id", "visibility", "occurred_at");
CREATE INDEX "estate_maintenance_history_request_id_occurred_at_idx" ON "estate_maintenance_history"("request_id", "occurred_at");
CREATE UNIQUE INDEX "estate_maintenance_idempotency_request_id_key" ON "estate_maintenance_idempotency"("request_id");
CREATE UNIQUE INDEX "estate_maintenance_idempotency_actor_user_id_estate_id_idempotency_key_hash_key" ON "estate_maintenance_idempotency"("actor_user_id", "estate_id", "idempotency_key_hash");
CREATE INDEX "estate_maintenance_idempotency_estate_id_created_at_idx" ON "estate_maintenance_idempotency"("estate_id", "created_at");
CREATE INDEX "estate_maintenance_notice_outbox_state_available_at_idx" ON "estate_maintenance_notice_outbox"("state", "available_at");
CREATE INDEX "estate_maintenance_notice_outbox_estate_id_created_at_idx" ON "estate_maintenance_notice_outbox"("estate_id", "created_at");