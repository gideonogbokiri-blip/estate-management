CREATE TYPE "EstateBudgetStatus" AS ENUM ('DRAFT', 'PENDING_APPROVAL', 'APPROVED', 'REJECTED', 'SUPERSEDED');

ALTER TABLE "estate_expense_requests" ADD COLUMN "budget_line_id" UUID;

CREATE TABLE "estate_budgets" (
  "id" UUID NOT NULL,
  "estate_id" UUID NOT NULL,
  "version" INTEGER NOT NULL DEFAULT 1,
  "period_start" DATE NOT NULL,
  "period_end" DATE NOT NULL,
  "currency" VARCHAR(3) NOT NULL,
  "status" "EstateBudgetStatus" NOT NULL DEFAULT 'DRAFT',
  "created_by_id" UUID NOT NULL,
  "submitted_at" TIMESTAMPTZ(3),
  "approved_by_id" UUID,
  "approved_at" TIMESTAMPTZ(3),
  "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMPTZ(3) NOT NULL,
  CONSTRAINT "estate_budgets_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "estate_budget_lines" (
  "id" UUID NOT NULL,
  "estate_id" UUID NOT NULL,
  "budget_id" UUID NOT NULL,
  "category_id" UUID NOT NULL,
  "allocated_amount" DECIMAL(12,2) NOT NULL,
  "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "estate_budget_lines_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "estate_budget_decisions" (
  "id" UUID NOT NULL,
  "budget_id" UUID NOT NULL,
  "actor_user_id" UUID NOT NULL,
  "decision" "EstateBudgetStatus" NOT NULL,
  "reason" VARCHAR(1000),
  "occurred_at" TIMESTAMPTZ(3) NOT NULL,
  CONSTRAINT "estate_budget_decisions_pkey" PRIMARY KEY ("id")
);

ALTER TABLE "estate_budgets" ADD CONSTRAINT "estate_budgets_valid_period_check" CHECK ("period_end" >= "period_start");
ALTER TABLE "estate_budget_lines" ADD CONSTRAINT "estate_budget_lines_positive_allocation_check" CHECK ("allocated_amount" > 0);

CREATE UNIQUE INDEX "estate_budgets_estate_id_id_key" ON "estate_budgets"("estate_id", "id");
CREATE UNIQUE INDEX "estate_budgets_estate_id_period_start_period_end_version_key" ON "estate_budgets"("estate_id", "period_start", "period_end", "version");
CREATE INDEX "estate_budgets_estate_id_status_period_start_period_end_idx" ON "estate_budgets"("estate_id", "status", "period_start", "period_end");
CREATE UNIQUE INDEX "estate_budget_lines_estate_id_id_key" ON "estate_budget_lines"("estate_id", "id");
CREATE UNIQUE INDEX "estate_budget_lines_budget_id_category_id_key" ON "estate_budget_lines"("budget_id", "category_id");
CREATE INDEX "estate_budget_lines_estate_id_category_id_idx" ON "estate_budget_lines"("estate_id", "category_id");
CREATE INDEX "estate_budget_decisions_budget_id_occurred_at_idx" ON "estate_budget_decisions"("budget_id", "occurred_at");

ALTER TABLE "estate_budgets" ADD CONSTRAINT "estate_budgets_estate_id_fkey" FOREIGN KEY ("estate_id") REFERENCES "estates"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "estate_budgets" ADD CONSTRAINT "estate_budgets_created_by_id_fkey" FOREIGN KEY ("created_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "estate_budgets" ADD CONSTRAINT "estate_budgets_approved_by_id_fkey" FOREIGN KEY ("approved_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "estate_budget_lines" ADD CONSTRAINT "estate_budget_lines_estate_id_budget_id_fkey" FOREIGN KEY ("estate_id", "budget_id") REFERENCES "estate_budgets"("estate_id", "id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "estate_budget_lines" ADD CONSTRAINT "estate_budget_lines_estate_id_category_id_fkey" FOREIGN KEY ("estate_id", "category_id") REFERENCES "estate_expense_categories"("estate_id", "id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "estate_budget_decisions" ADD CONSTRAINT "estate_budget_decisions_budget_id_fkey" FOREIGN KEY ("budget_id") REFERENCES "estate_budgets"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "estate_budget_decisions" ADD CONSTRAINT "estate_budget_decisions_actor_user_id_fkey" FOREIGN KEY ("actor_user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "estate_expense_requests" ADD CONSTRAINT "estate_expense_requests_estate_id_budget_line_id_fkey" FOREIGN KEY ("estate_id", "budget_line_id") REFERENCES "estate_budget_lines"("estate_id", "id") ON DELETE RESTRICT ON UPDATE CASCADE;
