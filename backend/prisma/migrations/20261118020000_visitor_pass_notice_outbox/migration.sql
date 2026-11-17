CREATE TABLE "estate_visitor_pass_notice_outbox" (
  "id" UUID NOT NULL,
  "estate_id" UUID NOT NULL,
  "pass_id" UUID NOT NULL,
  "event_type" VARCHAR(100) NOT NULL,
  "payload" JSONB NOT NULL,
  "state" VARCHAR(20) NOT NULL DEFAULT 'queued',
  "attempts" INTEGER NOT NULL DEFAULT 0,
  "available_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "processed_at" TIMESTAMPTZ(3),
  "last_error" VARCHAR(500),
  CONSTRAINT "estate_visitor_pass_notice_outbox_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "estate_visitor_pass_notice_outbox_estate_id_fkey" FOREIGN KEY ("estate_id") REFERENCES "estates"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "estate_visitor_pass_notice_outbox_pass_id_fkey" FOREIGN KEY ("pass_id") REFERENCES "estate_visitor_passes"("id") ON DELETE RESTRICT ON UPDATE CASCADE
);
CREATE INDEX "estate_visitor_pass_notice_outbox_state_available_at_idx" ON "estate_visitor_pass_notice_outbox"("state", "available_at");
CREATE INDEX "estate_visitor_pass_notice_outbox_estate_id_created_at_idx" ON "estate_visitor_pass_notice_outbox"("estate_id", "created_at");
