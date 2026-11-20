# 05 — Identity, Household and Onboarding

Status: implemented; real identity provider deferred.

## Registration approval

The connected join-request lifecycle (`EstateResidentJoinRequest` with PENDING/APPROVED/REJECTED) was already implemented and reused. Approval creates an active `EstateMembership` and `PropertyOccupancy`, is transactional, relationship-scoped and audited. Routes: `POST /api/v1/estate/residents/join-requests`, `GET .../mine`, manager list/approve/reject under `/api/v1/estate/estates/:estateId/resident-requests`.

## Household

`HouseholdMember` supports ADULT, CHILD and RESTRICTED members with relationship, effective dates, PENDING_APPROVAL → ACTIVE/REJECTED and ENDED. Residents submit for their own property; managers can add directly, approve/reject and end. `financialAccess` is forced false for CHILD and RESTRICTED members in both add and decision paths. Routes: `GET|POST /api/v1/estate/estates/:estateId/household`, `GET /api/v1/estate/household/mine`, `POST .../household/:memberId/decide|end`.

## Identity

`IdentityVerification` captures explicit consent, method (`DEMO_DECLARATION`, `PROVIDER_TOKEN`, `DOCUMENT_REVIEW`), level, provider reference and an audited manager decision. Demo declarations are labelled (`DEMO-…`, `demo: true`) and must not be treated as provider-verified. No document or biometric template is stored — provider verification tokens are preferred per spec. Routes under `/api/v1/estate/estates/:estateId/identity/verifications`.

## Tests

`backend/tests/household.test.js`, `identity.test.js`.
