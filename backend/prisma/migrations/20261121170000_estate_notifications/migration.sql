CREATE TYPE "EstateNotificationType" AS ENUM ('EXPENSE', 'INCIDENT');

CREATE TABLE "estate_notifications" (
  "id" UUID NOT NULL,
  "estate_id" UUID NOT NULL,
  "recipient_user_id" UUID NOT NULL,
  "event_key" VARCHAR(180) NOT NULL,
  "type" "EstateNotificationType" NOT NULL,
  "title" VARCHAR(180) NOT NULL,
  "message" VARCHAR(1000) NOT NULL,
  "source_id" UUID NOT NULL,
  "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "read_at" TIMESTAMPTZ(3),
  CONSTRAINT "estate_notifications_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "estate_notifications_nonempty_content_check" CHECK (length(trim("event_key")) > 0 AND length(trim("title")) > 0 AND length(trim("message")) > 0)
);

CREATE UNIQUE INDEX "estate_notifications_estate_id_recipient_user_id_event_key_key" ON "estate_notifications"("estate_id", "recipient_user_id", "event_key");
CREATE INDEX "estate_notifications_recipient_user_id_read_at_created_at_idx" ON "estate_notifications"("recipient_user_id", "read_at", "created_at");
CREATE INDEX "estate_notifications_estate_id_type_created_at_idx" ON "estate_notifications"("estate_id", "type", "created_at");

ALTER TABLE "estate_notifications" ADD CONSTRAINT "estate_notifications_estate_id_fkey"
  FOREIGN KEY ("estate_id") REFERENCES "estates"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "estate_notifications" ADD CONSTRAINT "estate_notifications_recipient_user_id_fkey"
  FOREIGN KEY ("recipient_user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
