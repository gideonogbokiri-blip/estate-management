ALTER TABLE "estate_application_documents"
    ADD COLUMN "idempotency_key_hash" VARCHAR(64),
    ADD COLUMN "payload_hash" VARCHAR(64);

CREATE UNIQUE INDEX "estate_application_documents_application_id_idempotency_key_hash_key"
    ON "estate_application_documents"("application_id", "idempotency_key_hash");
