-- CreateEnum
CREATE TYPE "EstateExpenseStatus" AS ENUM ('DRAFT', 'PENDING_APPROVAL', 'APPROVED', 'REJECTED', 'CANCELLED');
-- CreateTable
CREATE TABLE "estate_expense_policies" (
    "id" UUID NOT NULL,
    "estate_id" UUID NOT NULL,
    "version" INTEGER NOT NULL DEFAULT 1,
    "approval_stages" JSONB NOT NULL,
    "allow_unbudgeted" BOOLEAN NOT NULL DEFAULT true,
    "prevent_requester_approval" BOOLEAN NOT NULL DEFAULT true,
    "require_distinct_approvers" BOOLEAN NOT NULL DEFAULT true,
    "updated_by_id" UUID NOT NULL,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "estate_expense_policies_pkey" PRIMARY KEY ("id")
);
-- CreateTable
CREATE TABLE "estate_expense_categories" (
    "id" UUID NOT NULL,
    "estate_id" UUID NOT NULL,
    "code" VARCHAR(60) NOT NULL,
    "name" VARCHAR(120) NOT NULL,
    "active" BOOLEAN NOT NULL DEFAULT true,
    "created_by_id" UUID NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "estate_expense_categories_pkey" PRIMARY KEY ("id")
);
-- CreateTable
CREATE TABLE "estate_expense_payees" (
    "id" UUID NOT NULL,
    "estate_id" UUID NOT NULL,
    "reference" VARCHAR(60) NOT NULL,
    "display_name" VARCHAR(160) NOT NULL,
    "currency" VARCHAR(3) NOT NULL,
    "destination_reference" VARCHAR(120) NOT NULL,
    "verified_at" TIMESTAMPTZ(3),
    "verified_by_id" UUID,
    "created_by_id" UUID NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "estate_expense_payees_pkey" PRIMARY KEY ("id")
);
-- CreateTable
CREATE TABLE "estate_expense_requests" (
    "id" UUID NOT NULL,
    "estate_id" UUID NOT NULL,
    "code" VARCHAR(40) NOT NULL,
    "requester_user_id" UUID NOT NULL,
    "category_id" UUID NOT NULL,
    "payee_id" UUID NOT NULL,
    "description" VARCHAR(1000) NOT NULL,
    "amount" DECIMAL(12,2) NOT NULL,
    "currency" VARCHAR(3) NOT NULL,
    "needed_by" DATE,
    "status" "EstateExpenseStatus" NOT NULL DEFAULT 'DRAFT',
    "approval_policy_version" INTEGER,
    "approval_stage_index" INTEGER NOT NULL DEFAULT 0,
    "approved_destination_snapshot" VARCHAR(120),
    "submitted_at" TIMESTAMPTZ(3),
    "idempotency_key_hash" VARCHAR(64) NOT NULL,
    "payload_hash" VARCHAR(64) NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "estate_expense_requests_pkey" PRIMARY KEY ("id")
);
-- CreateTable
CREATE TABLE "estate_expense_decisions" (
    "id" UUID NOT NULL,
    "expense_id" UUID NOT NULL,
    "stage_index" INTEGER NOT NULL,
    "actor_user_id" UUID NOT NULL,
    "role" "EstateRole" NOT NULL,
    "decision" "EstateExpenseStatus" NOT NULL,
    "reason" VARCHAR(1000),
    "occurred_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "estate_expense_decisions_pkey" PRIMARY KEY ("id")
);
-- CreateIndex
CREATE UNIQUE INDEX "estate_expense_policies_estate_id_key" ON "estate_expense_policies"("estate_id");
-- CreateIndex
CREATE INDEX "estate_expense_categories_estate_id_active_name_idx" ON "estate_expense_categories"("estate_id", "active", "name");
-- CreateIndex
CREATE UNIQUE INDEX "estate_expense_categories_estate_id_code_key" ON "estate_expense_categories"("estate_id", "code");
-- CreateIndex
CREATE UNIQUE INDEX "estate_expense_categories_estate_id_id_key" ON "estate_expense_categories"("estate_id", "id");
-- CreateIndex
CREATE INDEX "estate_expense_payees_estate_id_verified_at_idx" ON "estate_expense_payees"("estate_id", "verified_at");
-- CreateIndex
CREATE UNIQUE INDEX "estate_expense_payees_estate_id_reference_key" ON "estate_expense_payees"("estate_id", "reference");
-- CreateIndex
CREATE UNIQUE INDEX "estate_expense_payees_estate_id_id_key" ON "estate_expense_payees"("estate_id", "id");
-- CreateIndex
CREATE INDEX "estate_expense_requests_estate_id_status_submitted_at_idx" ON "estate_expense_requests"("estate_id", "status", "submitted_at");
-- CreateIndex
CREATE INDEX "estate_expense_requests_requester_user_id_estate_id_created_idx" ON "estate_expense_requests"("requester_user_id", "estate_id", "created_at");
-- CreateIndex
CREATE UNIQUE INDEX "estate_expense_requests_estate_id_code_key" ON "estate_expense_requests"("estate_id", "code");
-- CreateIndex
CREATE UNIQUE INDEX "estate_expense_requests_estate_id_requester_user_id_idempot_key" ON "estate_expense_requests"("estate_id", "requester_user_id", "idempotency_key_hash");
-- CreateIndex
CREATE INDEX "estate_expense_decisions_expense_id_occurred_at_idx" ON "estate_expense_decisions"("expense_id", "occurred_at");
-- CreateIndex
CREATE INDEX "estate_expense_decisions_actor_user_id_occurred_at_idx" ON "estate_expense_decisions"("actor_user_id", "occurred_at");
-- CreateIndex
CREATE UNIQUE INDEX "estate_expense_decisions_expense_id_stage_index_key" ON "estate_expense_decisions"("expense_id", "stage_index");
-- AddForeignKey
ALTER TABLE "estate_expense_policies" ADD CONSTRAINT "estate_expense_policies_estate_id_fkey" FOREIGN KEY ("estate_id") REFERENCES "estates"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
-- AddForeignKey
ALTER TABLE "estate_expense_policies" ADD CONSTRAINT "estate_expense_policies_updated_by_id_fkey" FOREIGN KEY ("updated_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
-- AddForeignKey
ALTER TABLE "estate_expense_categories" ADD CONSTRAINT "estate_expense_categories_estate_id_fkey" FOREIGN KEY ("estate_id") REFERENCES "estates"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
-- AddForeignKey
ALTER TABLE "estate_expense_categories" ADD CONSTRAINT "estate_expense_categories_created_by_id_fkey" FOREIGN KEY ("created_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
-- AddForeignKey
ALTER TABLE "estate_expense_payees" ADD CONSTRAINT "estate_expense_payees_estate_id_fkey" FOREIGN KEY ("estate_id") REFERENCES "estates"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
-- AddForeignKey
ALTER TABLE "estate_expense_payees" ADD CONSTRAINT "estate_expense_payees_verified_by_id_fkey" FOREIGN KEY ("verified_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
-- AddForeignKey
ALTER TABLE "estate_expense_payees" ADD CONSTRAINT "estate_expense_payees_created_by_id_fkey" FOREIGN KEY ("created_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
-- AddForeignKey
ALTER TABLE "estate_expense_requests" ADD CONSTRAINT "estate_expense_requests_estate_id_fkey" FOREIGN KEY ("estate_id") REFERENCES "estates"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
-- AddForeignKey
ALTER TABLE "estate_expense_requests" ADD CONSTRAINT "estate_expense_requests_requester_user_id_fkey" FOREIGN KEY ("requester_user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
-- AddForeignKey
ALTER TABLE "estate_expense_requests" ADD CONSTRAINT "estate_expense_requests_estate_id_category_id_fkey" FOREIGN KEY ("estate_id", "category_id") REFERENCES "estate_expense_categories"("estate_id", "id") ON DELETE RESTRICT ON UPDATE CASCADE;
-- AddForeignKey
ALTER TABLE "estate_expense_requests" ADD CONSTRAINT "estate_expense_requests_estate_id_payee_id_fkey" FOREIGN KEY ("estate_id", "payee_id") REFERENCES "estate_expense_payees"("estate_id", "id") ON DELETE RESTRICT ON UPDATE CASCADE;
-- AddForeignKey
ALTER TABLE "estate_expense_decisions" ADD CONSTRAINT "estate_expense_decisions_expense_id_fkey" FOREIGN KEY ("expense_id") REFERENCES "estate_expense_requests"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
-- AddForeignKey
ALTER TABLE "estate_expense_decisions" ADD CONSTRAINT "estate_expense_decisions_actor_user_id_fkey" FOREIGN KEY ("actor_user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
