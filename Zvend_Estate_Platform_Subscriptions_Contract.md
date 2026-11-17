# Zvend Estate — Platform Plans and Subscriptions Contract

**Status:** Proposed contract; reconcile with Zvend platform billing and entitlement services before implementation  
**Product baseline:** `Zvend_Estate_Management_Build_Documentation.md`  
**Scope:** Configurable commercial plans, estate subscriptions, entitlements, renewals, usage and platform billing

This domain belongs to Zvend Platform, not to an individual estate's resident billing. It does not create a competing payment system or assume fixed plan prices. Reuse existing Zvend subscription, wallet/payment, invoicing, ledger, entitlement and notification services where appropriate.

## 1. Financial and product boundary

- Platform subscription charges are between Zvend and the estate customer. They are separate from rent, estate fees, resident invoices and estate operational expenses.
- Plans contain configurable entitlements (property/unit limit, staff/admin limit, enabled modules, storage allowance, support level, trial rules and billing interval) and versioned price/currency terms.
- Prices, limits, trials and terms are data configured by authorized platform roles; never hardcode them into UI logic or estate business rules.
- Negotiated/custom contracts retain their explicit terms, billing schedule and history. A subscription points to the plan/contract version agreed at the time; editing a plan applies only to new agreements or an explicitly approved renewal/change.
- Subscription invoice, payment state and platform settlement come from existing Zvend billing/payment sources. A client redirect or estate administrator action cannot mark a subscription paid.
- Subscription delinquency and estate operational status are separate state machines. Any grace, restriction, suspension or restoration policy must be explicitly configured and audited; a failed payment must not silently produce an unreviewed estate-status mutation.

## 2. Actors and permissions

| Actor | Scope |
|---|---|
| Platform plan administrator | Create/version/retire catalog plans, configure default limits/terms and define permitted entitlements |
| Platform finance administrator | View platform subscription accounts, invoices, payment/reconciliation state and settlement reports; approve discounts/contract changes by policy |
| Platform operations administrator | View estate subscription/entitlement status needed for onboarding and operational support; no default financial detail access |
| Estate owner/billing contact | View own estate plan, contract summary, usage/limits, platform invoices and payment status; request eligible plan changes |
| Estate administrator | View operational entitlements needed to manage the estate; does not automatically see confidential negotiated pricing or platform-wide finance |

Use separate platform permissions for plan catalog, contract changes, platform finance and operational entitlement reads. Estate roles cannot change a platform plan, price, limit or subscription status.

## 3. Plan and subscription lifecycle

### Plan version

```text
Draft → Published → Retired
```

A published version is immutable for existing subscriptions. To change price, limits, billing interval, included modules or trial terms, create and publish a new version with an effective date and an authorized approver. Retired plans remain readable for historic contracts but cannot be selected for new agreements.

### Estate subscription

```text
Pending setup → Trial (optional) → Active → Renewal due → Active
                                 ├→ Past due → Grace (if configured) → Active
                                 │                         └→ Restricted/Cancelled (policy action)
                                 └→ Cancel scheduled → Cancelled/Expired
```

- Record the customer/legal billing entity, billing contact, plan or custom contract version, effective period, renewal mode, billing cadence, entitlements, invoice references and status history.
- A plan change creates a new subscription version or amendment with actor, approval, effective date and proration treatment. It does not rewrite past invoices or usage.
- Trial, grace, cancellation, service restriction and non-payment outcomes must follow explicit platform policy. Do not equate subscription status with the estate activation status from onboarding.
- Entitlement calculation is server-side. The UI may display usage but cannot authorize property/staff/module operations by itself.
- Usage counters should derive from authoritative estate records or rebuildable usage events. Define whether archived properties and inactive staff count against a limit.
- If a limit is reached, reject the relevant create/enable operation with a clear domain outcome. Do not silently delete records, prevent safety-critical reads or alter historical access.

## 4. Logical records

Reconcile with existing Zvend billing/subscription models before creating schema.

### Plan version

- Plan/catalog ID, immutable version, display name, published/retired state, effective time, included module/feature entitlements, property/staff/storage/support limits, trial/billing terms, fixed-precision price/currency and approval/publisher metadata.
- Use explicit unlimited/contract-defined values rather than magic numbers. A custom plan can reference negotiated terms without falsely claiming a public tier price.

### Estate subscription agreement

- Estate ID, billing customer/contact reference, selected plan version or custom contract reference, start/end/renewal dates, billing cadence, status, grace/restriction policy reference, negotiated terms, entitlement snapshot/version, external existing Zvend billing account reference and audit metadata.
- Restrict confidential contract documents and pricing fields to platform finance and the estate billing contact as policy allows.

### Subscription event and usage

- Append-only events for activation, trial start/end, renewal, plan amendment, payment state change, grace entry/exit, cancellation, entitlement change and restriction/restoration, with actor/source, timestamp, reason and prior/new version references.
- Usage observations/events identify metric, estate, interval, amount/unit and source or reproducible derivation. Do not use a client-provided counter as authoritative usage.

## 5. Proposed API operations

Adapt routes and response conventions to existing Zvend platform services.

| Method and path | Permission | Behavior |
|---|---|---|
| `GET /api/platform/estate-plans` | Platform plan view | List published/draft/retired plans according to actor permission |
| `POST /api/platform/estate-plans` | Platform plan manage | Create draft catalog item/version with validated configurable entitlements and price terms |
| `POST /api/platform/estate-plans/:planId/versions` | Platform plan manage/approval | Create immutable draft version; preserve old version |
| `POST /api/platform/estate-plans/:planId/versions/:versionId/publish` | Plan publisher/approver | Validate terms, limits and effective date; publish and audit |
| `POST /api/platform/estate-plans/:planId/retire` | Platform plan manage | Prevent new selection while preserving existing subscription history |
| `GET /api/platform/estate-subscriptions` | Platform operations or finance scope | Paginated/filterable platform list with role-appropriate financial fields |
| `GET /api/estate/subscription` | Estate owner/billing contact or permitted estate admin | Return own contract summary, effective entitlements, usage and invoice status according to role |
| `POST /api/platform/estates/:estateId/subscription` | Platform operations/finance as policy | Create/assign agreement or custom contract; audit approval and effective terms |
| `POST /api/platform/estate-subscriptions/:subscriptionId/amendments` | Platform-authorized contract manager | Propose/version a plan change, discount or custom term with approval and effective date |
| `POST /api/estate/subscription/change-requests` | Estate owner/billing contact | Request eligible plan upgrade/downgrade; does not directly change entitlements |
| `POST /api/platform/estate-subscriptions/:subscriptionId/renew` | Platform renewal service/authorized finance | Renew using captured current version and existing billing service; idempotent for period |
| `POST /api/platform/estate-subscriptions/:subscriptionId/cancel` | Authorized billing/contract manager | Cancel or schedule cancellation under contract terms and preserve history |
| `GET /api/platform/estate-subscriptions/:subscriptionId/usage` | Platform ops/finance according to field scope | Return server-derived usage and effective limits with freshness timestamp |
| `GET /api/platform/estate-subscriptions/:subscriptionId/events` | Platform audit/finance scope | Paginated status/amendment history with safe metadata |

The billing provider webhook remains owned by the existing Zvend billing/payment service. The subscription module consumes its verified transaction state; it should not create a parallel public payment webhook without platform architecture evidence.

## 6. Reliability, audit and reporting

- Use fixed-precision amounts, explicit currency and effective-dated terms; apply existing Zvend rounding/proration behavior.
- Make renewal invoice generation, payment event processing, plan amendment and cancellation idempotent using platform billing references.
- Atomically publish plan version with its entitlement snapshot; prevent partial publication.
- Audit plan creation/version publication/retirement, custom contract or discount approval, subscription assignment, amendment, payment exception, grace/restriction action, cancellation and restoration.
- Platform reports reconcile to existing subscription invoices and verified Zvend transactions; distinguish contracted revenue, invoiced, collected, overdue, refunded and pending values.
- Exported contract/payment detail follows platform finance permissions and private export rules; estate users see only their own agreement details.
- Never include payment secrets or raw provider credentials in plan, subscription, audit, report or client responses.

## 7. UI mapping

| UI surface | Integrated behavior |
|---|---|
| Platform plan catalog | List immutable published versions and permitted draft/retired catalog items |
| Plan editor | Create draft version with configurable price, limits, modules, support and billing terms |
| Estate subscriptions | Platform-scoped list; field visibility follows operations vs finance permission |
| Estate plan summary | Show own effective plan/contract, usage/limits, renewal date and authorized invoice/payment state |
| Plan change request | Request a change for platform review; no client-side entitlement mutation |
| Usage/limit notice | Read backend-derived counters; enforcement remains in domain APIs |
| Subscription payment state | Read verified Zvend billing state; never infer paid state from redirect |

The preview's plan and estate rows are illustrative and must not be read as Zvend's actual offerings, limits, prices, subscription states or financial data.

## 8. Acceptance evidence and integration gates

Before implementation claims, demonstrate:

1. No hardcoded price or entitlement limit controls production behavior; active subscriptions retain the exact agreed plan/contract version.
2. Changes to a catalog plan do not mutate current subscriptions, invoices or historical usage.
3. Estate roles cannot change plan/price/entitlements or view other estates' subscriptions.
4. Platform operations and finance roles receive only their assigned field scopes.
5. Subscription charge/payment states derive from verified Zvend platform billing records and handle duplicate events idempotently.
6. Trial, grace, restriction, cancellation, restoration and estate activation remain distinct, audited state transitions.
7. Usage/limits reconcile to authoritative records and prevent unauthorized over-limit creation server-side.
8. Custom agreements, discounts, proration and renewal terms follow authorized approval and financial reconciliation.

Inspect Zvend's existing subscription and invoicing models, payment/ledger references, customer identity, plan/feature-flag system, usage metering, notification/audit service, platform roles, renewal jobs, proration rules and support/finance reporting before code or migrations.
