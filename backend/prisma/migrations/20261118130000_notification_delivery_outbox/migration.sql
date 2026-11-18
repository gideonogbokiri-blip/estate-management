-- Outbound delivery queue for persisted in-app notifications.
-- In-app notices remain immediate; this records optional email delivery attempts.

CREATE TABLE "estate_notification_deliveries" (
  "id" UUID NOT NULL,
  "notification_id" UUID NOT NULL,
  "estate_id" UUID NOT NULL,
  "recipient_user_id" UUID NOT NULL,
  "recipient_email" VARCHAR(254) NOT NULL,
  "channel" VARCHAR(20) NOT NULL DEFAULT 'email',
  "status" VARCHAR(20) NOT NULL DEFAULT 'pending',
  "attempts" INT NOT NULL DEFAULT 0,
  "last_error" VARCHAR(500),
  "sent_at" TIMESTAMPTZ(3),
  "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "estate_notification_deliveries_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "estate_notification_deliveries_status_check"
    CHECK ("status" IN ('pending', 'sent', 'failed', 'skipped'))
);

CREATE UNIQUE INDEX "estate_notification_deliveries_notification_channel_key"
  ON "estate_notification_deliveries"("notification_id", "channel");
CREATE INDEX "estate_notification_deliveries_status_created_idx"
  ON "estate_notification_deliveries"("status", "created_at");

ALTER TABLE "estate_notification_deliveries" ADD CONSTRAINT "estate_notification_deliveries_notification_fkey"
  FOREIGN KEY ("notification_id") REFERENCES "estate_notifications"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "estate_notification_deliveries" ADD CONSTRAINT "estate_notification_deliveries_estate_fkey"
  FOREIGN KEY ("estate_id") REFERENCES "estates"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "estate_notification_deliveries" ADD CONSTRAINT "estate_notification_deliveries_recipient_fkey"
  FOREIGN KEY ("recipient_user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
