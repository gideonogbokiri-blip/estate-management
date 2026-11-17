ALTER TABLE "estate_tenancies" DROP CONSTRAINT "estate_tenancies_termination_fields_check";
ALTER TABLE "estate_tenancies" ADD CONSTRAINT "estate_tenancies_termination_fields_check"
  CHECK (("status" = 'TERMINATED' AND "terminated_by_id" IS NOT NULL AND "terminated_at" IS NOT NULL AND "termination_effective_date" IS NOT NULL AND "termination_reason" IS NOT NULL)
      OR ("status" <> 'TERMINATED' AND "terminated_by_id" IS NULL AND "terminated_at" IS NULL AND "termination_effective_date" IS NULL AND "termination_reason" IS NULL));
