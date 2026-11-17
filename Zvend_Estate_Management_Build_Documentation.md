# Estate Management Platform

## Product Requirements, Software Requirements and Development Blueprint

**Document type:** Product & Technical Build Specification\
**Product:** Estate Management Platform\
**Platform:** Standalone web and Flutter applications\
**Version:** 1.0\
**Date:** 4 November 2026\
**Status:** Initial implementation blueprint

------------------------------------------------------------------------

# Current Build Direction (Authoritative)

The product is being built as its own estate-management platform. It does
not depend on a Zvend application, identity provider, wallet, payment
service, database, notification service or file-storage adapter. The
references to an existing host platform elsewhere in this initial
blueprint are historical assumptions and are superseded by this section
and later explicit user decisions.

The current implementation uses a NestJS/TypeScript API, PostgreSQL with
Prisma, and a Flutter/Dart client for resident and estate-manager
experiences. Estate membership and role checks are enforced by this
product's API. Payment processors, external messaging providers and
production storage/deployment adapters remain separate integrations to
select and implement when required. Venco is a workflow reference only;
its brand, assets and proprietary implementation are not used.

The user-facing product should use neutral Estate Management branding.
Do not present the product as an AI application or expose build tools,
agent terminology or generated-content language in its UI.

# 1. Executive Summary

The Estate Management Platform is a multi-estate property and community
management product. It supports residential estates, gated communities,
apartment complexes, commercial properties and mixed-use developments.

The platform will provide estate owners and administrators with tools to
manage properties, landlords, tenants, residents, billing, rent,
visitors, security, maintenance, facilities, communications and
financial reporting. Residents and landlords will access relevant
services through this product's Flutter application. Estate staff use
role-specific interfaces, while platform administrators manage onboarded
estates through a central dashboard.

The product should use Venco as a functional reference for
community-management workflows, not copy its branding, interface or
proprietary implementation. This specification describes the proposed
Zvend requirements; it does not claim to document Venco's private source
code or internal architecture.

## 1.1 Product objectives

1.  Give each estate a complete digital operating system.
2.  Support multiple estates on one platform with strict data isolation.
3.  Make property, ownership, occupancy and tenancy relationships clear.
4.  Digitize estate fees, rent, invoices, collections and receipts.
5.  Improve gate security through visitor invitations and verification.
6.  Make complaints and maintenance work trackable from submission to
    resolution.
7.  Give residents, landlords and estate staff appropriate mobile
    services.
8.  Reuse Zvend authentication, wallet/payment services and notification
    infrastructure where technically suitable.
9.  Provide reliable financial and operational reporting.
10. Create a commercial platform that can be subscribed to by multiple
    estates.

## 1.2 Product name and positioning

**Name:** Zvend Estate Management\
**Short name:** Zvend Estate\
**Suggested tagline:** Smarter Estates. Better Living.

------------------------------------------------------------------------

# 2. Initial Product Assumptions (Superseded Where Conflicting)

This section preserves the original planning notes. The standalone
architecture and decisions in **Current Build Direction** take precedence
where these draft assumptions mention a host application or its services.

The following decisions have already been established:

  -----------------------------------------------------------------------
  Area                                Confirmed decision
  ----------------------------------- -----------------------------------
  Deployment                          Estate features inside the existing
                                      Zvend mobile app, plus a separate
                                      web administration dashboard

  Rent access                         Both landlords and tenants can use
                                      relevant rent-management and
                                      payment functions

  GPS                                 Property mapping only; no
                                      continuous resident tracking

  Backend integration                 Dedicated module inside the
                                      existing Zvend backend/application

  Commercial model                    Multi-estate platform; each estate
                                      has its own administrators and
                                      isolated records

  Existing platform                   Reuse existing Zvend services where
                                      suitable; do not rebuild the Zvend
                                      application

  Coding preference                   Use JavaScript and existing
                                      repository conventions; do not
                                      introduce TypeScript if the current
                                      project is JavaScript

  Database                            Reuse the existing database and ORM
                                      conventions after repository
                                      inspection; PostgreSQL/Prisma is
                                      the proposed baseline where
                                      consistent with the current system
  -----------------------------------------------------------------------

## 2.1 Decisions to confirm during implementation

These are recommended defaults, not yet confirmed user decisions:

-   Estate registration should require Zvend Super Admin approval.
-   Zvend Super Admin should create or approve the first Estate
    Administrator.
-   Support residential, gated, apartment, commercial and mixed-use
    properties.
-   Estate owners may request an estate account, but activation follows
    platform verification.
-   Fees, billing cycles, subscription prices and payment destinations
    must be configurable rather than hardcoded.

------------------------------------------------------------------------

# 3. Users, Roles and Permissions

The system must use role-based access control (RBAC), with permissions
scoped to the platform or a particular estate. A user may belong to more
than one estate and have different roles in each.

## 3.1 Platform roles

-   **Super Administrator:** Full platform administration, estate
    approval/suspension, global configuration and platform oversight.
-   **Platform Support Administrator:** Support access to assigned
    platform functions; no unrestricted financial authority by default.
-   **Platform Finance Administrator:** Platform subscription,
    settlement and platform-level financial reporting.
-   **Platform Operations Administrator:** Estate onboarding and
    operational monitoring.

## 3.2 Estate roles

-   Estate Owner
-   Estate Administrator
-   General Manager
-   Estate Accountant
-   Estate Secretary
-   Security Supervisor
-   Security Personnel
-   Facility Manager
-   Maintenance Officer
-   Landlord / Property Owner
-   Tenant
-   Resident

Roles should be configurable through permissions. Avoid relying only on
hardcoded role names.

## 3.3 Permission examples

  ---------------------------------------------------------------------------------------------------------------
  Capability            Super Admin  Estate Admin    Accountant       Security         Landlord   Tenant/Resident
  --------------- ----------------- ------------- ------------- -------------- ---------------- -----------------
  Register estate               Yes            No            No             No               No                No

  Approve estate                Yes            No            No             No               No                No

  Manage estate           Oversight           Yes       Read as             No   Own properties Assigned property
  properties                                          permitted                            only              view

  Manage                  Oversight           Yes       Limited           Gate     Own property       Own profile
  residents                                                       verification          context 
                                                                          only                  

  Configure              No, unless           Yes      Assigned             No  View applicable   View applicable
  estate charges    platform policy                 permissions                         charges           charges

  Record/verify      Platform scope  According to           Yes             No Own transactions  Own transactions
  finance                             permissions                                               

  Verify visitors   Audit/oversight           Yes            No            Yes   Invite/approve Invite/approve as
                                                                                  as configured        configured

  Resolve                 Oversight           Yes            No Assigned tasks     Own property      Own requests
  maintenance                                                             only         requests 

  Manage estate            Platform           Yes            No             No               No                No
  staff                   oversight                                                             
  ---------------------------------------------------------------------------------------------------------------

Every permission check must be performed on the backend. Hiding a button
in the frontend is not authorization.

------------------------------------------------------------------------

# 4. Applications and Interfaces

## 4.1 Zvend Super Admin Web Dashboard

Used by the Zvend platform team to:

-   View all estates and their statuses.
-   Review estate registration applications and documents.
-   Approve, reject, suspend or deactivate estates.
-   Create or approve initial estate administrators.
-   Manage platform staff and permissions.
-   Configure subscription plans and estate limits.
-   Monitor estate usage and platform transactions.
-   View platform-wide reports and audit events.
-   Manage integrations, support cases and platform settings.

Estate statuses:

-   Draft
-   Pending
-   Under Review
-   Active
-   Rejected
-   Suspended
-   Deactivated

Only Active estates may perform normal estate operations. Status
transitions must be audited.

## 4.2 Estate Administration Web Dashboard

Each estate has a separately scoped dashboard containing:

1.  Overview
2.  Properties
3.  Zones, streets and buildings
4.  Residents
5.  Landlords
6.  Tenants and tenancies
7.  Billing and demand notices
8.  Rent management
9.  Administrative charges
10. Visitors
11. Security and incidents
12. Maintenance and complaints
13. Facilities and bookings
14. Announcements and communication
15. Finance and expenses
16. Reports and analytics
17. Staff, roles and permissions
18. Estate settings and documents

## 4.3 Resident and Landlord Mobile Experience

These features should appear inside the existing Zvend mobile app,
subject to its existing navigation and framework.

Resident navigation/features:

-   My Estate
-   My Property
-   My Rent (when applicable)
-   Estate Fees
-   Administrative Charges
-   Visitor Passes
-   Payment History
-   Receipts
-   Maintenance Requests
-   Announcements
-   Estate Map
-   Profile and household members

Landlord features:

-   My Properties
-   My Tenants
-   Rent Collection and rent status
-   Rent History
-   Outstanding Rent
-   Tenancy Agreements
-   Property Charges
-   Property Documents
-   Property-related maintenance
-   Notifications

A user may be both landlord and resident or landlord and tenant in
different properties. The UI must support multiple relationships without
creating duplicate user accounts.

## 4.4 Security Interface

Provide a simple mobile-friendly security experience:

-   Secure staff login.
-   Select assigned estate/gate where permitted.
-   Scan QR code or enter visitor PIN.
-   Validate pass, estate, property, validity period and status.
-   Display only the minimum visitor information required for gate
    operations.
-   Record check-in and check-out.
-   Verify vehicles where configured.
-   Report incidents.
-   View expected visitors and currently checked-in visitors.
-   Emergency contact information.

------------------------------------------------------------------------

# 5. Functional Modules and Requirements

## 5.1 Estate Onboarding and Management

### Requirements

-   Estate application form with estate name, type, address, state, LGA,
    contact details and map location.
-   Estate owner, developer or management-company details.
-   Upload supporting documents.
-   Configure estate type and basic structure.
-   Submit for platform review.
-   Super Admin can approve, reject with reason, request more
    information, suspend or deactivate.
-   Create/assign the first Estate Administrator.
-   Generate a unique estate code or joining identifier.
-   Configure estate branding and contact information.
-   Record all administrative status changes in audit logs.

### Suggested onboarding workflow

1.  Applicant creates or uses an existing Zvend account.
2.  Applicant submits estate details and documents.
3.  Application enters Pending/Under Review.
4.  Platform reviewer checks details and documents.
5.  Reviewer approves, rejects or requests corrections.
6.  On approval, estate becomes Active.
7.  Initial Estate Administrator is assigned.
8.  Estate administrator configures properties, staff, fees and
    operational settings.

## 5.2 Property and Estate Structure

Support:

-   Estates
-   Zones / phases
-   Streets
-   Blocks
-   Buildings
-   Floors (where applicable)
-   Houses
-   Apartments
-   Shops
-   Offices
-   Warehouses
-   Parking spaces
-   Other configurable property types

Each property should have:

-   Estate ID
-   Unique property code within the estate
-   Property type
-   Zone/street/block/building relationship
-   House/unit number
-   Address/description
-   GPS coordinates (optional)
-   Occupancy status
-   Ownership records
-   Current and historical occupants
-   Documents and images
-   Applicable charges
-   Created/updated timestamps

Property status examples:

-   Under Development
-   Vacant
-   Occupied
-   Reserved
-   Under Maintenance
-   Inactive
-   Archived

A property can have multiple owners if the business rules permit it.
Ownership shares and effective dates should be supported where needed.
Do not assume that the landlord and tenant are the same person.

## 5.3 Landlord Management

-   Link a Zvend user to one or more properties as an owner.
-   Store ownership verification and supporting documents.
-   Support multiple owners per property where configured.
-   View property portfolio.
-   View current and historical tenants.
-   View rent invoices and payment status for owned properties.
-   View property-related charges.
-   View tenancy agreements and important dates.
-   Receive notifications about rent, tenancy changes and maintenance.
-   Restrict access to properties owned or explicitly authorized.

## 5.4 Resident Management

-   Resident joins through estate code/search or an administrator
    invitation.
-   Select property and relationship (owner, tenant, household member,
    authorized occupant).
-   Submit identity/contact details and supporting documents as required
    by estate policy.
-   Estate administrator reviews and approves/rejects.
-   Record approval status and reviewer.
-   Support household members and authorized occupants.
-   Suspend or revoke access with reason and audit history.
-   Do not expose sensitive resident data to unrelated residents.

## 5.5 Tenant and Tenancy Management

A tenancy links a tenant to a property for a defined period.

Fields should include:

-   Estate
-   Property
-   Landlord/owner
-   Tenant
-   Start date and end date
-   Rent amount and currency
-   Payment frequency
-   Due date/rent cycle
-   Deposit and other agreed charges
-   Agreement document
-   Renewal terms
-   Status
-   Notice and termination dates
-   Created by and approval history

Tenancy statuses:

-   Draft
-   Pending Approval
-   Active
-   Expiring
-   Expired
-   Terminated
-   Cancelled

Support renewals and historical tenancies. Do not overwrite old tenancy
records when a tenant changes.

## 5.6 Billing, Estate Fees and Demand Notices

Allow estates to configure recurring and one-time charges.

Examples:

-   Estate management fee
-   Security fee
-   Waste collection
-   Water/service charge
-   Maintenance levy
-   Generator/infrastructure levy
-   Parking charge
-   Facility booking
-   Administrative charge
-   Other configurable charge

Charge configuration:

-   Name and description
-   Category
-   Amount and currency
-   One-time or recurring
-   Frequency
-   Applicable property types, properties or residents
-   Effective date and end date
-   Due date/grace period
-   Late fee policy (optional and configurable)
-   Payment destination
-   Approval requirements
-   Active/inactive status

Demand notice/invoice requirements:

-   Unique invoice number
-   Estate and payer
-   Property/tenancy reference
-   Line items
-   Issue date and due date
-   Subtotal, fees and total
-   Amount paid and balance
-   Status
-   Downloadable receipt/invoice
-   Payment history

Invoice statuses:

-   Draft
-   Issued
-   Partially Paid
-   Paid
-   Overdue
-   Cancelled
-   Disputed

Never silently alter a previously issued invoice. Use credit notes,
adjustments or cancellation/reissue workflows with audit trails.

## 5.7 Rent Management

Rent must be available to landlords and tenants according to their
permissions.

-   Configure annual, semi-annual, quarterly, monthly or custom
    schedules.
-   Generate rent invoices based on active tenancy terms.
-   Support full and partial payments if estate/landlord policy allows.
-   Track due, paid, outstanding and overdue amounts.
-   Send reminders before and after due dates.
-   Show rent history to authorized landlord and tenant.
-   Store tenancy agreements and renewal documents.
-   Notify landlord and tenant of rent payment events.
-   Support landlord-designated payment destination where legally and
    technically authorized.
-   Support rent receipts and reconciliation.

Important distinction: rent may be collected for a landlord, by an
estate, or into another authorized destination. The settlement model
must be explicitly configured. Do not assume every rent payment belongs
to the estate.

## 5.8 Administrative Charges

Support configurable charges such as:

-   New property registration
-   Resident registration
-   Tenant registration
-   Access card
-   Property transfer
-   Renovation/building permit
-   Move-in or move-out
-   Documentation
-   Special service requests

Each charge should have amount, payer, applicable event, approval
process, invoice and payment status. Amounts must be configurable.

## 5.9 Visitor Management

Resident/landlord workflow:

1.  Choose property.
2.  Enter visitor name and required contact details.
3.  Select expected arrival date/time and expiry.
4.  Add vehicle details if needed.
5.  Generate a unique QR code or PIN.
6.  Share invitation with visitor.
7.  Revoke invitation if plans change.

Security workflow:

1.  Scan QR or enter PIN.
2.  Backend validates pass.
3.  Confirm estate, property, validity window, remaining uses and
    revocation status.
4.  Display limited verification details.
5.  Record entry time, gate and verifying staff.
6.  Record exit time.
7.  Flag expired, revoked, invalid or already-used passes.

Requirements:

-   QR/PIN must be unpredictable and difficult to guess.
-   Do not encode sensitive personal information directly in QR data.
-   Use server-side validation.
-   Support single-use and configurable multi-use passes.
-   Support pass expiry and revocation.
-   Keep immutable access logs.
-   Apply rate limits to verification attempts.
-   Provide emergency/manual override with reason and audit record.

## 5.10 Security and Incident Management

-   Register security staff and assign estate/gates.
-   Manage shifts and duty rosters if required.
-   Record visitor and vehicle access events.
-   Record incidents, location, time, category, description and
    attachments.
-   Assign incident follow-up.
-   Track status and resolution.
-   Support emergency contact directory.
-   Restrict security staff to assigned estates/gates and necessary
    information.

## 5.11 Maintenance and Complaints

Resident can:

-   Submit complaint or maintenance request.
-   Select category and property.
-   Enter description and priority.
-   Upload images/documents.
-   View status and updates.
-   Add comments where allowed.
-   Confirm resolution or reopen according to policy.

Admin can:

-   Review and categorize.
-   Assign staff or contractor.
-   Set priority and target date.
-   Add internal notes.
-   Update status.
-   Record cost and materials where applicable.
-   Close with resolution details.

Suggested statuses:

-   Submitted
-   Under Review
-   Assigned
-   In Progress
-   Awaiting Parts/Approval
-   Resolved
-   Closed
-   Rejected

Keep an update history; do not overwrite the request timeline.

## 5.12 Facilities and Amenities

-   Register facilities such as halls, clubhouse, sports courts,
    swimming pool and shared parking.
-   Set opening hours, capacity and booking rules.
-   Configure fees, deposits and cancellation rules.
-   Allow residents to view availability and request bookings.
-   Admin approves or automatically confirms according to policy.
-   Prevent conflicting bookings.
-   Link any fee to an invoice/payment.
-   Record cancellations, refunds and usage.

## 5.13 Announcements and Communication

-   Estate-wide announcements.
-   Targeted messages by zone, street, property type or resident group.
-   Emergency alerts.
-   Scheduled announcements.
-   Polls and feedback.
-   Push notifications, email and SMS where integrations exist.
-   Read/delivery status where supported.
-   User notification preferences.

Do not expose recipients' private contact details to other residents.

## 5.14 Financial Management

-   Income categories.
-   Expense categories.
-   Budgets.
-   Expense requests and approval workflow.
-   Vendor/payee records.
-   Payment and receipt records.
-   Refunds and reversals.
-   Bank/payment reconciliation.
-   Outstanding receivables.
-   Collection reports.
-   Exportable reports.

Financial records must use decimal/fixed-precision types, not
floating-point numbers. Never delete a posted financial transaction.
Correct mistakes through auditable reversal/adjustment entries.

## 5.15 Reports and Analytics

Estate dashboard metrics:

-   Total properties
-   Occupied/vacant properties
-   Total registered residents
-   Active landlords and tenants
-   Active tenancies
-   Rent billed, collected and outstanding
-   Estate fees billed, collected and outstanding
-   Other charges
-   Visitor activity
-   Open maintenance requests
-   Expenses and net operating position

Reports:

-   Property register
-   Occupancy report
-   Resident register
-   Landlord portfolio
-   Tenancy and expiry report
-   Rent collection and arrears
-   Estate charge collection
-   Invoice ageing
-   Payment transactions
-   Expenses and budgets
-   Visitor access logs
-   Security incidents
-   Maintenance performance
-   Facility bookings

Reports must be filtered by estate, date range, category and permitted
organizational scope. Financial totals must reconcile to transaction
records.

## 5.16 Estate Map and GPS Property Mapping

-   Store estate boundary or outline.
-   Map zones, streets, buildings, properties, gates, parking and
    facilities.
-   Store latitude/longitude for relevant mapped objects.
-   Allow authorized staff to update property coordinates.
-   Provide map/list views and property lookup.

**Privacy rule:** GPS is for property mapping only. Do not continuously
track residents, landlords, tenants or their phones.

## 5.17 Subscription and Commercial Plan Management

Platform can offer configurable plans such as:

-   Starter
-   Professional
-   Enterprise
-   Custom

Plan configuration may include:

-   Number of properties/units
-   Number of staff/admin accounts
-   Enabled modules
-   Storage allowance
-   Support level
-   Billing frequency
-   Trial period
-   Price and currency

Do not hardcode prices or plan limits. Support negotiated/custom
contracts and plan history. Subscription billing is separate from estate
resident charges.

------------------------------------------------------------------------

# 6. Payment and Zvend Integration

## 6.1 Integration principle

The Estate module must integrate with existing Zvend payment/wallet
services after the existing codebase and payment APIs have been
inspected. Do not build a competing wallet or duplicate the payment
gateway.

## 6.2 Payment categories

-   RENT
-   ESTATE_MANAGEMENT_FEE
-   SECURITY_FEE
-   ADMINISTRATIVE_CHARGE
-   MAINTENANCE_FEE
-   FACILITY_BOOKING
-   OTHER_CHARGE

## 6.3 Payment workflow

1.  User selects an issued invoice.
2.  Backend checks invoice ownership, estate scope, amount due and
    status.
3.  Estate module creates a payment intent/request through the existing
    Zvend payment service.
4.  Zvend processes payment.
5.  Estate module receives a verified webhook or trusted server-side
    confirmation.
6.  Backend verifies transaction reference, amount, currency,
    destination and status.
7.  Payment is recorded and allocated to invoice items.
8.  Invoice balance/status is updated transactionally.
9.  Receipt is generated.
10. Relevant payer, landlord and estate staff are notified according to
    permissions.

## 6.4 Payment security requirements

-   Verify webhook signatures/authenticity.
-   Verify transaction references with the payment service.
-   Use idempotency keys.
-   Prevent duplicate webhook processing.
-   Validate amount, currency and intended recipient/destination.
-   Do not mark a payment successful from a frontend redirect or button
    click.
-   Store raw webhook event identifiers and processing status safely.
-   Support pending, successful, failed, reversed and refunded states.
-   Maintain immutable transaction history.
-   Support reconciliation and exception reporting.
-   Never fabricate successful payment records.

------------------------------------------------------------------------

# 7. Multi-Tenant Architecture and Data Isolation

The platform is multi-estate. The recommended initial approach is a
modular monolith with shared database tables and strict estate scoping,
unless the existing Zvend architecture requires another pattern.

## 7.1 Mandatory isolation rules

-   Every estate-owned record must include an estate identifier,
    directly or through a rigorously enforced parent relationship.
-   Every request must derive the user's estate membership from
    authenticated server-side context.
-   Validate estate membership and permission on every read and write.
-   Never trust a client-supplied estate ID without checking membership.
-   Query filters must include the authorized estate scope.
-   Super Admin cross-estate access must be explicit and audited.
-   A user may belong to multiple estates with separate roles in each.
-   Add database constraints and indexes that support estate-scoped
    uniqueness and lookups.
-   Test for cross-estate access vulnerabilities.

A frontend filter is not tenant isolation.

## 7.2 Proposed logical backend modules

Adapt to existing repository conventions; this is a logical guide, not a
requirement to force a new folder structure.

-   estates
-   estate-memberships
-   roles
-   permissions
-   properties
-   residents
-   landlords
-   tenants
-   tenancies
-   visitors
-   visitor-passes
-   charges
-   invoices
-   rent
-   payments
-   administrative-charges
-   security
-   vehicles
-   maintenance
-   facilities
-   announcements
-   notifications
-   finance
-   reports
-   maps
-   subscriptions
-   audit

Shared services:

-   Authentication/authorization integration
-   Estate context and tenant-scope guard
-   Validation
-   File storage
-   Notifications
-   Payment integration
-   Audit logging
-   Error handling

------------------------------------------------------------------------

# 8. Proposed Data Model

The following is a logical entity inventory. It must be reconciled with
the existing Zvend schema before migrations are written. Reuse existing
users, payments, wallets and related tables wherever possible.

## 8.1 Platform and access

-   estates
-   estate_applications
-   estate_memberships
-   roles
-   permissions
-   role_permissions
-   user_roles
-   estate_subscriptions
-   subscription_plans
-   estate_settings

## 8.2 Property and people

-   estate_zones
-   estate_streets
-   buildings
-   properties
-   property_owners
-   property_documents
-   property_occupants
-   residents
-   landlords (only if not represented by existing user/profile
    relations)
-   tenancies
-   tenancy_documents

## 8.3 Billing and finance

-   charge_categories
-   charge_configurations
-   invoices
-   invoice_items
-   payments or payment references to existing Zvend transactions
-   payment_allocations
-   refunds
-   payment_reconciliations
-   rent_schedules
-   receipts
-   expenses
-   expense_approvals
-   budgets
-   credit_notes/adjustments

## 8.4 Visitors and security

-   visitors
-   visitor_passes
-   visitor_access_logs
-   vehicles
-   security_staff_assignments
-   security_shifts
-   security_incidents

## 8.5 Maintenance and facilities

-   maintenance_categories
-   maintenance_requests
-   maintenance_assignments
-   maintenance_updates
-   maintenance_attachments
-   facilities
-   facility_bookings

## 8.6 Communication and mapping

-   announcements
-   notifications
-   notification_preferences
-   resident_feedback
-   polls
-   poll_votes
-   estate_map_locations
-   property_coordinates

## 8.7 System and audit

-   audit_logs
-   activity_logs
-   integration_logs
-   webhook_events

## 8.8 Data design rules

-   Use the existing primary-key convention; UUIDs are recommended if
    consistent with Zvend.
-   Use fixed-precision decimal types for monetary values.
-   Store timestamps consistently (UTC recommended); display in the
    user's/estate's configured timezone.
-   Add foreign keys and indexes.
-   Use estate-scoped unique constraints where appropriate.
-   Use soft deletion/archive for operational records where appropriate.
-   Never hard-delete posted financial transactions or access logs.
-   Keep tenancy, ownership and occupancy history.
-   Add created_by, updated_by and relevant approval metadata to
    sensitive records.

------------------------------------------------------------------------

# 9. API Design

Use the existing API prefix/versioning conventions. Proposed module
prefix:

`/api/estate`

All endpoints must enforce authentication, authorization, validation,
estate scoping, rate limits where appropriate and consistent error
handling.

## 9.1 Estates

-   POST `/api/estate/estates`
-   GET `/api/estate/estates`
-   GET `/api/estate/estates/:id`
-   PATCH `/api/estate/estates/:id`
-   PATCH `/api/estate/estates/:id/status`
-   POST `/api/estate/estates/:id/approve`
-   POST `/api/estate/estates/:id/reject`

## 9.2 Properties

-   POST `/api/estate/properties`
-   GET `/api/estate/properties`
-   GET `/api/estate/properties/:id`
-   PATCH `/api/estate/properties/:id`
-   DELETE `/api/estate/properties/:id` (archive; no destructive
    deletion)

## 9.3 Residents and memberships

-   POST `/api/estate/residents/join-requests`
-   GET `/api/estate/residents`
-   GET `/api/estate/residents/:id`
-   PATCH `/api/estate/residents/:id`
-   POST `/api/estate/residents/:id/approve`
-   POST `/api/estate/residents/:id/reject`
-   POST `/api/estate/residents/:id/suspend`

## 9.4 Landlords, tenants and tenancies

-   GET `/api/estate/landlords`
-   GET `/api/estate/landlords/:id`
-   GET `/api/estate/tenants`
-   POST `/api/estate/tenancies`
-   GET `/api/estate/tenancies`
-   GET `/api/estate/tenancies/:id`
-   PATCH `/api/estate/tenancies/:id`
-   POST `/api/estate/tenancies/:id/renew`
-   POST `/api/estate/tenancies/:id/terminate`

## 9.5 Visitors

-   POST `/api/estate/visitors/invitations`
-   GET `/api/estate/visitors`
-   GET `/api/estate/visitors/:id`
-   POST `/api/estate/visitors/verify`
-   POST `/api/estate/visitors/:id/check-in`
-   POST `/api/estate/visitors/:id/check-out`
-   POST `/api/estate/visitors/:id/revoke`

## 9.6 Billing and rent

-   POST `/api/estate/charges`
-   GET `/api/estate/charges`
-   PATCH `/api/estate/charges/:id`
-   POST `/api/estate/invoices/generate`
-   GET `/api/estate/invoices`
-   GET `/api/estate/invoices/:id`
-   POST `/api/estate/invoices/:id/cancel`
-   POST `/api/estate/rent/generate-invoice`
-   GET `/api/estate/rent/invoices`
-   GET `/api/estate/rent/landlord/:id`
-   GET `/api/estate/rent/tenant/:id`

## 9.7 Payments

-   POST `/api/estate/payments/initiate`
-   GET `/api/estate/payments`
-   GET `/api/estate/payments/:id`
-   POST `/api/estate/payments/webhook`
-   GET `/api/estate/receipts/:id`

Webhook authentication must follow the existing Zvend payment provider's
secure integration pattern.

## 9.8 Maintenance and reports

-   POST `/api/estate/maintenance`
-   GET `/api/estate/maintenance`
-   GET `/api/estate/maintenance/:id`
-   PATCH `/api/estate/maintenance/:id`
-   POST `/api/estate/maintenance/:id/assign`
-   POST `/api/estate/maintenance/:id/resolve`
-   GET `/api/estate/reports/dashboard`
-   GET `/api/estate/reports/financial`
-   GET `/api/estate/reports/rent`
-   GET `/api/estate/reports/collections`
-   GET `/api/estate/reports/outstanding`
-   GET `/api/estate/reports/expenses`

API response format, pagination, sorting, filtering and error structure
should match the existing Zvend API conventions.

------------------------------------------------------------------------

# 10. Notifications

Notification events may include:

-   Estate application submitted/approved/rejected.
-   Resident join request submitted/approved/rejected.
-   New invoice issued.
-   Payment successful/failed/reversed.
-   Rent due/overdue.
-   Tenancy approaching expiry.
-   Visitor invitation created/revoked/expired.
-   Visitor checked in/out.
-   Maintenance request status changed.
-   Emergency announcement.
-   Facility booking approved/rejected.

Use existing Zvend notification services where available. Push, email
and SMS should be configurable and should respect user preferences and
applicable consent requirements.

------------------------------------------------------------------------

# 11. File and Document Management

Support uploads for:

-   Estate registration documents.
-   Property documents.
-   Ownership evidence.
-   Tenancy agreements.
-   Resident verification documents.
-   Maintenance photos.
-   Incident evidence.
-   Receipts and generated statements.

Requirements:

-   Use existing Zvend storage integration if available.
-   Validate file type, size and content.
-   Restrict access by estate and role.
-   Use private storage for sensitive documents.
-   Use expiring signed access links where supported.
-   Do not expose permanent public URLs for identity or tenancy
    documents.
-   Record uploader, time, related entity and access scope.

------------------------------------------------------------------------

# 12. Security, Privacy and Compliance

-   Reuse existing Zvend authentication and session model.
-   Enforce server-side RBAC and estate scoping.
-   Validate and sanitize all inputs.
-   Apply rate limiting to login, visitor verification and sensitive
    endpoints.
-   Secure file uploads.
-   Verify payment webhooks.
-   Maintain audit logs for administrative, access and financial
    actions.
-   Protect sensitive personal and financial information.
-   Use HTTPS in transit and suitable encryption at rest.
-   Use secure secrets management; never commit credentials.
-   Implement backups and recovery procedures.
-   Provide account suspension and session revocation where supported.
-   Design with the Nigeria Data Protection Act 2023 and applicable NDPC
    guidance in mind.
-   Collect only information needed for a defined purpose.
-   Apply retention and deletion policies where legally appropriate.
-   No continuous resident GPS tracking.

Audit events should include actor, action, entity, entity ID, estate
scope, timestamp, outcome and relevant metadata. Avoid logging
passwords, tokens or unnecessary sensitive payloads.

------------------------------------------------------------------------

# 13. Non-Functional Requirements

## Performance

-   Paginate large lists.
-   Index frequent estate-scoped filters.
-   Avoid unbounded queries.
-   Use background jobs for bulk invoice generation, notifications and
    report exports.
-   Cache only data where invalidation and tenant isolation are
    understood.

## Reliability

-   Use database transactions for payment allocation and invoice balance
    updates.
-   Make webhook processing idempotent.
-   Provide retry handling for integrations.
-   Log failures and provide operational monitoring.
-   Back up data and test restoration.

## Accessibility and usability

-   Responsive web dashboard.
-   Mobile-first resident and security workflows.
-   Clear empty, loading, error and success states.
-   Simple language and low-bandwidth-friendly experiences.
-   Confirm destructive or financially consequential actions.

## Maintainability

-   Follow current repository structure and lint/test conventions.
-   Keep modules logically separated.
-   Avoid duplicated business logic.
-   Document environment variables and integration contracts.
-   Add automated tests for core workflows.

------------------------------------------------------------------------

# 14. Recommended Development Architecture

Use a modular monolith for this standalone product. Do not introduce
microservices unless operational needs justify them.

Proposed layers:

1.  Product-owned authentication and user identity.
2.  Estate module and estate-context authorization.
3.  Domain modules (properties, residents, billing, visitors, etc.).
4.  Explicit payment-provider adapters when selected.
5.  Product-owned notification and private-storage adapters.
6.  Product PostgreSQL database and Prisma migration system.
7.  Flutter resident and management applications.

Technology assumptions to verify:

-   Backend: NestJS with TypeScript.
-   Language: TypeScript for backend services; Dart for Flutter clients.
-   Database: PostgreSQL.
-   ORM: Prisma.
-   Dashboard and mobile client: Flutter Web and Flutter mobile targets.
-   Hosting: standalone environments and credentials must be configured
    for this product; no host-platform deployment is assumed.
-   Maps: Google Maps or Mapbox, selected based on existing account,
    pricing and technical fit.
-   Notifications: provider remains to be selected and configured.
-   File storage: private storage provider remains to be selected and
    configured.

Do not install or replace frameworks simply because they appear in this
blueprint.

------------------------------------------------------------------------

# 15. Development Phases

## Phase 0 --- Repository Audit and Product Foundation

The repository audit established that this workspace is a new,
standalone product with a NestJS/TypeScript backend, Prisma/PostgreSQL
data layer and Flutter/Dart clients. The API owns authentication,
estate membership, roles and estate-scoped data. There is no external
host application adapter to preserve. Continue implementation from this
greenfield foundation; do not pause for approval of the obsolete host
integration plan described in the initial draft of this document.

## Phase 1 --- Foundation

-   Estate module scaffolding.
-   Estate application and onboarding.
-   Estate status lifecycle.
-   Multi-estate data model.
-   Estate membership and role permissions.
-   Tenant-scope middleware/guards.
-   Super Admin estate dashboard.
-   Initial Estate Administrator setup.
-   Audit logging.

Acceptance: multiple estates can be registered and approved; each has
independent administrators; cross-estate access is blocked and tested.

## Phase 2 --- Property and People

-   Estate structure: zones, streets, buildings and units.
-   Property register.
-   Landlord and ownership relationships.
-   Resident joining and verification.
-   Tenant and tenancy records.
-   Property mapping.

Acceptance: properties, owners, tenants and occupants are accurately
linked; ownership and tenancy history is preserved.

## Phase 3 --- Visitors and Security

-   Visitor invitations.
-   QR/PIN pass generation and verification.
-   Check-in/check-out.
-   Gate/security interface.
-   Vehicle details and incident reporting.
-   Notifications.

Acceptance: expired, revoked, invalid and already-used passes cannot be
accepted; every access event is recorded.

## Phase 4 --- Billing, Rent and Payments

-   Charge configuration.
-   Invoice and demand notice generation.
-   Rent schedules and tenancy-linked invoices.
-   Payment integration.
-   Webhook verification and idempotency.
-   Payment allocations and receipts.
-   Reconciliation and outstanding balances.

Acceptance: no duplicate allocation; invoice balances are correct;
payment records reconcile with Zvend's trusted transaction records.

## Phase 5 --- Estate Operations

-   Maintenance and complaints.
-   Staff assignment.
-   Facilities and bookings.
-   Announcements and notifications.
-   Expenses and approvals.
-   Operational reports.

Acceptance: requests can be tracked to resolution; bookings prevent
conflicts; reports match underlying records.

## Phase 6 --- Hardening and Deployment

-   Security review.
-   Cross-estate penetration/access tests.
-   Payment and webhook tests.
-   Mobile integration tests.
-   Performance tests.
-   Backup/restore validation.
-   Production deployment and monitoring.
-   Admin and user documentation.

Do not proceed to the next phase until the current phase passes its
acceptance tests and is reviewed.

------------------------------------------------------------------------

# 16. Testing and Acceptance Criteria

Minimum required tests:

1.  Estate A administrator cannot read or modify Estate B records.
2.  A resident cannot access another resident's private profile or
    documents.
3.  A landlord sees only properties they own or are authorized to
    manage.
4.  A tenant sees only their tenancy and permitted property information.
5.  Suspended estates cannot perform normal operations.
6.  A revoked or expired visitor pass cannot be used.
7.  Visitor check-in/out creates immutable access records.
8.  Duplicate payment webhooks do not create duplicate payments.
9.  A frontend success redirect cannot mark an invoice paid.
10. Partial payments update invoice balances correctly.
11. Refunds/reversals preserve original payment history.
12. Rent invoices are generated according to tenancy schedules.
13. Terminated/expired tenancies do not receive future rent invoices
    unless policy explicitly requires it.
14. Financial reports reconcile to recorded transactions.
15. Unauthorized users cannot download private documents.
16. Existing Zvend electricity vending, wallet, authentication and APIs
    continue to work.

------------------------------------------------------------------------

# 17. Master Instructions for Antigravity / Codex

The following instructions should be supplied to the coding agent
alongside this document.

## Project role

You are a senior full-stack engineer working on the existing Zvend
application. Your task is to implement Zvend Estate Management as a
dedicated, modular, multi-estate feature within the existing product.

## Mandatory rules

1.  Inspect the existing repository before making changes.
2.  Begin with Phase 0 only. Do not write or modify application code
    until you have produced the repository audit and integration plan.
3.  Do not rebuild Zvend.
4.  Do not duplicate authentication, users, wallet or payment
    infrastructure.
5.  Do not break electricity vending or existing production features.
6.  Follow existing repository conventions and use JavaScript where the
    project uses JavaScript.
7.  Reuse existing database tables and services when appropriate.
8.  Do not make destructive schema changes or delete existing data.
9.  Every estate-owned record and request must be protected by
    server-side estate scoping.
10. Never trust frontend estate IDs or permission checks.
11. Verify payment events through trusted server-side mechanisms.
12. Never hardcode estate fees, rent policies, subscription prices or
    payment destinations.
13. Do not invent existing API capabilities. Inspect their
    implementation and document integration contracts.
14. Add migrations safely and make them reversible where practical.
15. Add tests for every completed phase.
16. Do not claim a feature is complete unless it works end-to-end and
    passes its tests.
17. Keep a development log describing files changed, migrations, tests,
    known limitations and next steps.

## Phase 0 deliverables

Before implementation, return:

-   Repository structure overview.
-   Backend/frontend/mobile technologies found.
-   Database and ORM findings.
-   Existing authentication and RBAC findings.
-   Existing payment/wallet/webhook findings.
-   Notification and file-storage findings.
-   Existing API and navigation integration points.
-   Deployment/environment findings.
-   Risks and compatibility concerns.
-   Proposed implementation sequence.
-   Proposed files/modules to add or modify.
-   Questions that cannot be resolved by inspecting the repository.

Wait for approval before coding.

## Implementation discipline

After approval, implement one phase at a time. For each phase:

1.  Explain the planned changes.
2.  Implement the backend and migrations.
3.  Add authorization and tenant-isolation checks.
4.  Implement the relevant web/mobile interface.
5.  Add tests.
6.  Run lint, tests and build.
7.  Report results and any limitations.
8.  Wait for approval before starting the next phase.

The specification is the product requirement baseline. If a requirement
conflicts with the existing Zvend architecture, do not silently work
around it. Explain the conflict and propose the safest integration
option.

------------------------------------------------------------------------

# 18. Glossary

-   **Estate:** A managed community or property development registered
    on the Estate Management Platform.
-   **Property/Unit:** A house, apartment, shop, office or other managed
    unit.
-   **Landlord:** A person or entity recorded as owning or authorized to
    manage a property.
-   **Tenant:** A person occupying a property under a tenancy agreement.
-   **Resident:** An approved person associated with an estate/property.
-   **Tenancy:** The time-bound agreement connecting tenant, property
    and landlord.
-   **Demand notice:** A statement requesting payment of estate charges.
-   **Invoice:** A formal record of an amount due.
-   **Estate scope:** The set of estate records a user is authorized to
    access.
-   **Tenant isolation:** Controls preventing one estate from accessing
    another estate's data.
-   **Payment allocation:** Applying a verified payment to one or more
    invoice balances.
-   **Webhook:** A server-to-server event notification from an external
    service.

------------------------------------------------------------------------

# 19. Final Product Principle

The Estate Management Platform must be a secure, reliable, multi-estate
operating platform---not just a collection of dashboard screens.

The system's core relationships must remain consistent:

**Estate → Property → Owner / Landlord → Tenancy → Tenant / Resident →
Charges / Rent → Invoice → Verified Payment → Receipt / Reconciliation**

Visitor access, security, maintenance, communication and facilities
should connect to the same estate, property and user records.

Build this platform as an independent product and deliver it
incrementally with auditable workflows.
