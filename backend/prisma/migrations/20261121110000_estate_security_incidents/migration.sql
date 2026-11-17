CREATE TYPE "EstateSecurityIncidentStatus" AS ENUM ('REPORTED', 'ACKNOWLEDGED', 'INVESTIGATING', 'RESOLVED', 'CLOSED');

CREATE TABLE "estate_security_incidents" (
  "id" UUID NOT NULL,
  "estate_id" UUID NOT NULL,
  "reference" VARCHAR(32) NOT NULL,
  "category" VARCHAR(60) NOT NULL,
  "priority" VARCHAR(20) NOT NULL,
  "description" VARCHAR(1000) NOT NULL,
  "location_description" VARCHAR(120),
  "observed_at" TIMESTAMPTZ(3) NOT NULL,
  "status" "EstateSecurityIncidentStatus" NOT NULL DEFAULT 'REPORTED',
  "reporter_user_id" UUID NOT NULL,
  "reviewed_by_user_id" UUID,
  "resolution_summary" VARCHAR(1000),
  "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMPTZ(3) NOT NULL,
  CONSTRAINT "estate_security_incidents_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "estate_security_incidents_estate_id_fkey" FOREIGN KEY ("estate_id") REFERENCES "estates"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "estate_security_incidents_reporter_user_id_fkey" FOREIGN KEY ("reporter_user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "estate_security_incidents_reviewed_by_user_id_fkey" FOREIGN KEY ("reviewed_by_user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE
);
CREATE UNIQUE INDEX "estate_security_incidents_estate_id_reference_key" ON "estate_security_incidents"("estate_id", "reference");
CREATE INDEX "estate_security_incidents_estate_id_status_created_at_idx" ON "estate_security_incidents"("estate_id", "status", "created_at");
CREATE INDEX "estate_security_incidents_reporter_user_id_estate_id_created_at_idx" ON "estate_security_incidents"("reporter_user_id", "estate_id", "created_at");

CREATE TABLE "estate_security_incident_history" (
  "id" UUID NOT NULL,
  "incident_id" UUID NOT NULL,
  "actor_user_id" UUID NOT NULL,
  "from_status" "EstateSecurityIncidentStatus",
  "to_status" "EstateSecurityIncidentStatus" NOT NULL,
  "note" VARCHAR(1000),
  "occurred_at" TIMESTAMPTZ(3) NOT NULL,
  CONSTRAINT "estate_security_incident_history_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "estate_security_incident_history_incident_id_fkey" FOREIGN KEY ("incident_id") REFERENCES "estate_security_incidents"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "estate_security_incident_history_actor_user_id_fkey" FOREIGN KEY ("actor_user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE
);
CREATE INDEX "estate_security_incident_history_incident_id_occurred_at_idx" ON "estate_security_incident_history"("incident_id", "occurred_at");
