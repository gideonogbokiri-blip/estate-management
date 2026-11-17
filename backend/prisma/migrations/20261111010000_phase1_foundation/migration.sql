-- CreateSchema
CREATE SCHEMA IF NOT EXISTS "public";

-- CreateEnum
CREATE TYPE "AccountStatus" AS ENUM ('ACTIVE', 'DISABLED');

-- CreateEnum
CREATE TYPE "ApplicationStatus" AS ENUM ('DRAFT', 'SUBMITTED', 'UNDER_REVIEW', 'MORE_INFORMATION_REQUIRED', 'APPROVED', 'REJECTED');

-- CreateEnum
CREATE TYPE "ApplicationDocumentStatus" AS ENUM ('PENDING', 'VERIFIED', 'REJECTED', 'MORE_INFORMATION_REQUIRED');

-- CreateEnum
CREATE TYPE "EstateStatus" AS ENUM ('ACTIVE', 'SUSPENDED', 'DEACTIVATED');

-- CreateEnum
CREATE TYPE "EstateMembershipStatus" AS ENUM ('ACTIVE', 'SUSPENDED', 'REVOKED');

-- CreateEnum
CREATE TYPE "EstateRole" AS ENUM ('ESTATE_ADMINISTRATOR', 'ESTATE_MANAGER', 'FINANCE_MANAGER', 'SECURITY_OFFICER', 'RESIDENT', 'LANDLORD');

-- CreateTable
CREATE TABLE "users" (
    "id" UUID NOT NULL,
    "email_normalized" VARCHAR(254) NOT NULL,
    "display_name" VARCHAR(200) NOT NULL,
    "phone" VARCHAR(50),
    "password_hash" VARCHAR(255) NOT NULL,
    "status" "AccountStatus" NOT NULL DEFAULT 'ACTIVE',
    "email_verified_at" TIMESTAMPTZ(3),
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "users_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "user_sessions" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "refresh_token_hash" VARCHAR(128) NOT NULL,
    "expires_at" TIMESTAMPTZ(3) NOT NULL,
    "revoked_at" TIMESTAMPTZ(3),
    "rotated_from_id" UUID,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "user_sessions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "platform_role_grants" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "role_key" VARCHAR(80) NOT NULL,
    "granted_by_id" UUID,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "platform_role_grants_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "estate_applications" (
    "id" UUID NOT NULL,
    "application_code" VARCHAR(40) NOT NULL,
    "applicant_user_id" UUID NOT NULL,
    "proposed_name" VARCHAR(200) NOT NULL DEFAULT '',
    "estate_type" VARCHAR(80) NOT NULL DEFAULT '',
    "address" VARCHAR(300) NOT NULL DEFAULT '',
    "state" VARCHAR(100) NOT NULL DEFAULT '',
    "lga" VARCHAR(100) NOT NULL DEFAULT '',
    "latitude" DECIMAL(9,6),
    "longitude" DECIMAL(9,6),
    "applicant_relationship" VARCHAR(100) NOT NULL DEFAULT '',
    "applicant_contact_name" VARCHAR(200) NOT NULL DEFAULT '',
    "applicant_contact_email" VARCHAR(254) NOT NULL DEFAULT '',
    "applicant_contact_phone" VARCHAR(50) NOT NULL DEFAULT '',
    "management_entity_name" VARCHAR(200) NOT NULL DEFAULT '',
    "registration_number" VARCHAR(100),
    "home_count" INTEGER,
    "phase_count" INTEGER,
    "structure_summary" VARCHAR(500),
    "status" "ApplicationStatus" NOT NULL DEFAULT 'DRAFT',
    "submitted_at" TIMESTAMPTZ(3),
    "assigned_reviewer_user_id" UUID,
    "decision_reason" VARCHAR(2000),
    "decided_by_user_id" UUID,
    "decided_at" TIMESTAMPTZ(3),
    "initial_administrator_id" UUID,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "estate_applications_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "estate_application_documents" (
    "id" UUID NOT NULL,
    "application_id" UUID NOT NULL,
    "category" VARCHAR(80) NOT NULL,
    "display_name" VARCHAR(160) NOT NULL,
    "object_key" VARCHAR(500) NOT NULL,
    "content_type" VARCHAR(120) NOT NULL,
    "byte_size" BIGINT NOT NULL,
    "checksum" VARCHAR(128),
    "status" "ApplicationDocumentStatus" NOT NULL DEFAULT 'PENDING',
    "uploaded_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "reviewed_at" TIMESTAMPTZ(3),
    "review_note" VARCHAR(1000),

    CONSTRAINT "estate_application_documents_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "estates" (
    "id" UUID NOT NULL,
    "estate_code" VARCHAR(40) NOT NULL,
    "approved_application_id" UUID NOT NULL,
    "name" VARCHAR(200) NOT NULL,
    "estate_type" VARCHAR(80) NOT NULL,
    "address" VARCHAR(300) NOT NULL,
    "state" VARCHAR(100) NOT NULL,
    "lga" VARCHAR(100) NOT NULL,
    "status" "EstateStatus" NOT NULL DEFAULT 'ACTIVE',
    "activated_at" TIMESTAMPTZ(3) NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "estates_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "estate_memberships" (
    "id" UUID NOT NULL,
    "estate_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "role" "EstateRole" NOT NULL,
    "status" "EstateMembershipStatus" NOT NULL DEFAULT 'ACTIVE',
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "estate_memberships_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "audit_events" (
    "id" UUID NOT NULL,
    "actor_user_id" UUID,
    "scope" VARCHAR(40) NOT NULL,
    "estate_id" UUID,
    "action" VARCHAR(120) NOT NULL,
    "target_type" VARCHAR(80) NOT NULL,
    "target_id" VARCHAR(100) NOT NULL,
    "outcome" VARCHAR(40) NOT NULL,
    "reason" VARCHAR(2000),
    "metadata" JSONB,
    "occurred_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "audit_events_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "users_email_normalized_key" ON "users"("email_normalized");

-- CreateIndex
CREATE UNIQUE INDEX "user_sessions_refresh_token_hash_key" ON "user_sessions"("refresh_token_hash");

-- CreateIndex
CREATE INDEX "user_sessions_user_id_expires_at_idx" ON "user_sessions"("user_id", "expires_at");

-- CreateIndex
CREATE INDEX "user_sessions_revoked_at_expires_at_idx" ON "user_sessions"("revoked_at", "expires_at");

-- CreateIndex
CREATE INDEX "platform_role_grants_role_key_user_id_idx" ON "platform_role_grants"("role_key", "user_id");

-- CreateIndex
CREATE UNIQUE INDEX "platform_role_grants_user_id_role_key_key" ON "platform_role_grants"("user_id", "role_key");

-- CreateIndex
CREATE UNIQUE INDEX "estate_applications_application_code_key" ON "estate_applications"("application_code");

-- CreateIndex
CREATE INDEX "estate_applications_applicant_user_id_created_at_idx" ON "estate_applications"("applicant_user_id", "created_at");

-- CreateIndex
CREATE INDEX "estate_applications_status_submitted_at_idx" ON "estate_applications"("status", "submitted_at");

-- CreateIndex
CREATE INDEX "estate_applications_assigned_reviewer_user_id_status_submit_idx" ON "estate_applications"("assigned_reviewer_user_id", "status", "submitted_at");

-- CreateIndex
CREATE INDEX "estate_application_documents_application_id_status_idx" ON "estate_application_documents"("application_id", "status");

-- CreateIndex
CREATE UNIQUE INDEX "estates_estate_code_key" ON "estates"("estate_code");

-- CreateIndex
CREATE UNIQUE INDEX "estates_approved_application_id_key" ON "estates"("approved_application_id");

-- CreateIndex
CREATE INDEX "estate_memberships_user_id_status_idx" ON "estate_memberships"("user_id", "status");

-- CreateIndex
CREATE INDEX "estate_memberships_estate_id_status_idx" ON "estate_memberships"("estate_id", "status");

-- CreateIndex
CREATE UNIQUE INDEX "estate_memberships_estate_id_user_id_role_key" ON "estate_memberships"("estate_id", "user_id", "role");

-- CreateIndex
CREATE INDEX "audit_events_scope_estate_id_occurred_at_idx" ON "audit_events"("scope", "estate_id", "occurred_at");

-- CreateIndex
CREATE INDEX "audit_events_target_type_target_id_occurred_at_idx" ON "audit_events"("target_type", "target_id", "occurred_at");

-- CreateIndex
CREATE INDEX "audit_events_actor_user_id_occurred_at_idx" ON "audit_events"("actor_user_id", "occurred_at");

-- AddForeignKey
ALTER TABLE "user_sessions" ADD CONSTRAINT "user_sessions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "platform_role_grants" ADD CONSTRAINT "platform_role_grants_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "estate_applications" ADD CONSTRAINT "estate_applications_applicant_user_id_fkey" FOREIGN KEY ("applicant_user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "estate_applications" ADD CONSTRAINT "estate_applications_assigned_reviewer_user_id_fkey" FOREIGN KEY ("assigned_reviewer_user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "estate_applications" ADD CONSTRAINT "estate_applications_decided_by_user_id_fkey" FOREIGN KEY ("decided_by_user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "estate_applications" ADD CONSTRAINT "estate_applications_initial_administrator_id_fkey" FOREIGN KEY ("initial_administrator_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "estate_application_documents" ADD CONSTRAINT "estate_application_documents_application_id_fkey" FOREIGN KEY ("application_id") REFERENCES "estate_applications"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "estates" ADD CONSTRAINT "estates_approved_application_id_fkey" FOREIGN KEY ("approved_application_id") REFERENCES "estate_applications"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "estate_memberships" ADD CONSTRAINT "estate_memberships_estate_id_fkey" FOREIGN KEY ("estate_id") REFERENCES "estates"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "estate_memberships" ADD CONSTRAINT "estate_memberships_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "audit_events" ADD CONSTRAINT "audit_events_actor_user_id_fkey" FOREIGN KEY ("actor_user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
