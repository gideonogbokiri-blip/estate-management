-- Add a distinct Estate Chairman / approver role so payout initiation and
-- approval are separated by role, not just by person.

ALTER TYPE "EstateRole" ADD VALUE IF NOT EXISTS 'ESTATE_CHAIRMAN';
