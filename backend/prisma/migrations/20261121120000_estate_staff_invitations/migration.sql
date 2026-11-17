CREATE TYPE "EstateStaffInvitationStatus" AS ENUM ('PENDING', 'ACCEPTED', 'REVOKED', 'EXPIRED');

CREATE TABLE "estate_staff_invitations" (
  "id" UUID NOT NULL,
  "estate_id" UUID NOT NULL,
  "email_normalized" VARCHAR(254) NOT NULL,
  "role" "EstateRole" NOT NULL,
  "token_hash" VARCHAR(64) NOT NULL,
  "status" "EstateStaffInvitationStatus" NOT NULL DEFAULT 'PENDING',
  "created_by_id" UUID NOT NULL,
  "accepted_by_id" UUID,
  "expires_at" TIMESTAMPTZ(3) NOT NULL,
  "accepted_at" TIMESTAMPTZ(3),
  "revoked_at" TIMESTAMPTZ(3),
  "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "estate_staff_invitations_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "estate_staff_invitations_estate_id_fkey" FOREIGN KEY ("estate_id") REFERENCES "estates"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "estate_staff_invitations_created_by_id_fkey" FOREIGN KEY ("created_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "estate_staff_invitations_accepted_by_id_fkey" FOREIGN KEY ("accepted_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE
);
CREATE UNIQUE INDEX "estate_staff_invitations_token_hash_key" ON "estate_staff_invitations"("token_hash");
CREATE INDEX "estate_staff_invitations_estate_id_status_expires_at_idx" ON "estate_staff_invitations"("estate_id", "status", "expires_at");
CREATE INDEX "estate_staff_invitations_email_normalized_status_expires_at_idx" ON "estate_staff_invitations"("email_normalized", "status", "expires_at");
