CREATE TABLE "estate_security_incident_evidence" (
  "id" UUID NOT NULL,
  "incident_id" UUID NOT NULL,
  "uploaded_by_user_id" UUID NOT NULL,
  "display_name" VARCHAR(160) NOT NULL,
  "object_key" VARCHAR(500) NOT NULL,
  "content_type" VARCHAR(120) NOT NULL,
  "byte_size" BIGINT NOT NULL,
  "checksum" VARCHAR(64) NOT NULL,
  "idempotency_key_hash" VARCHAR(64) NOT NULL,
  "payload_hash" VARCHAR(64) NOT NULL,
  "uploaded_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "estate_security_incident_evidence_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "estate_security_incident_evidence_incident_id_fkey" FOREIGN KEY ("incident_id") REFERENCES "estate_security_incidents"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "estate_security_incident_evidence_uploaded_by_user_id_fkey" FOREIGN KEY ("uploaded_by_user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE UNIQUE INDEX "incident_evidence_incident_uploader_idempotency_key" ON "estate_security_incident_evidence"("incident_id", "uploaded_by_user_id", "idempotency_key_hash");
CREATE INDEX "incident_evidence_incident_uploaded_at_idx" ON "estate_security_incident_evidence"("incident_id", "uploaded_at");
