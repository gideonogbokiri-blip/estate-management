# Zvend Estate — Phase 2 Backend Contract

**Status:** Proposed domain contract; reconcile with the Zvend source repository before implementation  
**Product baseline:** `Zvend_Estate_Management_Build_Documentation.md`  
**Depends on:** Phase 1 estate identity, membership, authorization context and audit contract  
**Scope:** Estate hierarchy, properties, ownership history, resident memberships, household occupants and tenancies

## 1. Phase 2 outcome

An active estate administrator can define the estate's physical structure and maintain a register of units. Existing Zvend users can be associated with a property as owner, tenant, household member or authorized occupant. Resident access requires estate approval. A tenancy links a property, tenant and owner/payee for a defined period, while preserving previous ownership, occupancy and tenancy records.

The API must never infer that an owner is a tenant or that every occupant is a bill payer. Those relationships and the access they grant are explicit and time-bounded.

## 2. Relationship model

```text
Active Estate
  └── Zone/Phase → Street → Building → Floor (optional)
                                     └── Property/Unit
                                           ├── Ownership Interest(s) → Existing Zvend User(s)
                                           ├── Occupancy/Resident Membership(s) → Existing Zvend User(s)
                                           └── Tenancy history
                                                 ├── Tenant → Existing Zvend User
                                                 └── Owner/authorized payee(s)
```

Zone, street, building and floor nodes are optional and configurable to support houses, apartments, shops, offices, warehouses, parking and mixed-use estates. A property belongs to one estate. Any relationship across estates must be represented explicitly rather than inferred from a matching address or name.

## 3. Logical records

Reuse existing user/profile, file, role and audit infrastructure. These are logical records, not required table names.

### Estate hierarchy

- **Estate zone/phase:** estate ID, display name/code, order and active/archive state.
- **Estate street:** estate ID, optional zone ID, display name/code and state.
- **Building:** estate ID, optional zone/street parent, name/code, type and optional floor count.
- **Property:** estate ID, unique property code, property type, hierarchy references, unit/house number, address/description, optional coordinates, status, archive timestamps and actor metadata.

Property types should be configurable or safely extensible. Property statuses follow the product baseline: Under Development, Vacant, Occupied, Reserved, Under Maintenance, Inactive and Archived. Occupied/vacant may be derived from effective occupancy, but the estate may also need an explicit operational status; keep those concepts separate.

### Ownership interest

- estate ID, property ID, existing Zvend user ID or approved legal entity reference
- ownership share where enabled; effective-from/effective-to dates
- verification state, evidence document reference and review metadata
- source/status and created/updated actor metadata

Allow multiple owners if estate policy permits. Do not delete old interests when ownership changes; close the effective period and create a new record.

### Resident membership and property occupancy

Keep estate membership/access separate from property occupancy:

- estate membership: estate ID, existing user ID, membership state and estate-scoped role/permissions
- property occupant relation: estate ID, property ID, user ID, relationship (`owner`, `tenant`, `household_member`, `authorized_occupant`), effective dates and approval state
- join request: user, requested estate/property, requested relationship, optional proof, state, reviewer, decision reason/time

A resident may be a member of an estate without a current property relationship if estate policy allows. An approved occupant does not automatically receive property-owner or billing privileges.

### Tenancy

- estate ID and property ID
- tenant user ID; owner/landlord or authorized payee links
- start/end/notice dates and status
- rent amount, currency and frequency using fixed precision
- due-day/schedule details, deposit and explicitly configured additional terms
- agreement document references through private storage
- created/approved actor and timestamps

Tenancy status baseline: Draft, Pending Approval, Active, Expiring, Expired, Terminated and Cancelled. Renewals create a linked historical record or a versioned renewal record; do not overwrite the prior contract terms. At most one active tenancy per property unless an explicit product rule permits multiple occupancies (such as separately leased rooms/units).

## 4. Authorization and isolation rules

1. Resolve estate context through the authenticated actor's active membership; never accept a client estate ID as authorization.
2. Estate administrators need the corresponding permission for every property, ownership, resident or tenancy operation.
3. Landlords can read only properties with an active or historical ownership/authorization relationship that grants the requested view.
4. Tenants can read only their own tenancy and the permitted property information for its effective period.
5. Residents can access only their own membership, approved household links and property information granted by estate policy.
6. Reviewers may read submitted proof only through a server-authorized private document access operation.
7. Every write must verify the estate, property, parent hierarchy, user and tenancy all share the same authorized estate.
8. Record membership approvals/rejections/suspensions, ownership verification, tenancy activation/renewal/termination and property archive actions in the audit facility.
9. List endpoints must paginate and scope before applying search, sort or aggregate operations.

## 5. API groups

Paths remain provisional; follow Zvend's existing versioning, naming, pagination and error conventions after the repository audit.

### Estate structure and property register

| Method and path | Permission | Behavior |
|---|---|---|
| `GET /api/estate/structure` | Estate structure view | Return only hierarchy nodes for the authorized active estate |
| `POST /api/estate/structure/nodes` | Structure management | Create a zone, street, building or optional floor with a validated same-estate parent |
| `PATCH /api/estate/structure/nodes/:nodeId` | Structure management | Update allowed fields; reject cross-estate parent reassignment |
| `GET /api/estate/properties` | Property view | Paginated/filterable estate-scoped property register |
| `POST /api/estate/properties` | Property management | Create a property after validating its hierarchy and estate-scoped code uniqueness |
| `GET /api/estate/properties/:propertyId` | Property/relationship view | Return permitted property details and allowed ownership/occupancy summary |
| `PATCH /api/estate/properties/:propertyId` | Property management | Update mutable fields without rewriting ownership or occupant history |
| `POST /api/estate/properties/:propertyId/archive` | Property archive permission | Archive after checking active tenancy/financial/access relationships; preserve history |

### Landlord portfolio

| Method and path | Permission | Behavior |
|---|---|---|
| `GET /api/estate/estates/:estateId/landlord/portfolio` | Authenticated actor with current, verified ownership access | Return a bounded property list scoped to active, verified ownership records; include only same-estate, same-property tenancy summaries the actor may view |

The portfolio read must derive the actor from the existing Zvend session, deduplicate property records, and keep ownership/occupancy/tenancy distinct. Property, tenant, agreement, charge and rent details require their own actor authorization. Do not present tenancy rent terms as received rent or outstanding balance; those amounts come from authorized invoice records and verified payment allocations. The preview integration seam in `backend/modules/people/list-my-landlord-portfolio.js` requires currently effective active ownership with verified evidence and returns only safe estate/property/tenancy summary fields.

### Ownership and verification

| Method and path | Permission | Behavior |
|---|---|---|
| `GET /api/estate/properties/:propertyId/owners` | Estate property view or authorized owner | Return owner relationships permitted to the actor |
| `POST /api/estate/properties/:propertyId/owners` | Estate ownership management | Add owner/user and effective share/date; audit the change |
| `POST /api/estate/ownership/:ownershipId/verify` | Estate ownership reviewer | Record verification decision and evidence reference |
| `POST /api/estate/ownership/:ownershipId/end` | Estate ownership management | Close effective period; preserve prior ownership record |

### Resident membership and occupancy

| Method and path | Permission | Behavior |
|---|---|---|
| `POST /api/estate/residents/join-requests` | Authenticated user | Request to join a selected estate/property with relationship type |
| `GET /api/estate/residents/join-requests/mine` | Authenticated applicant | Paginated history of only the current user's requests across estates |
| `GET /api/estate/residents/join-requests` | Resident review permission | Paginated queue for the authorized estate |
| `GET /api/estate/residents/join-requests/:requestId` | Applicant or assigned reviewer | Return own request or scoped reviewer detail |
| `POST /api/estate/residents/join-requests/:requestId/approve` | Resident review permission | In one transaction, approve membership and occupancy; audit decision |
| `POST /api/estate/residents/join-requests/:requestId/reject` | Resident review permission | Require a reason, record decision and notify applicant |
| `GET /api/estate/residents` | Resident management/view permission | Return estate-scoped residents with only permitted profile fields |
| `POST /api/estate/properties/:propertyId/occupants` | Occupant management permission | Add a household/authorized occupant or link an approved tenant |
| `POST /api/estate/occupants/:occupantId/end` | Occupant management permission | End current occupancy/access effective period and audit |

### Tenancies

| Method and path | Permission | Behavior |
|---|---|---|
| `GET /api/estate/tenancies` | Tenancy view permission | Estate-scoped, paginated list with status/date/property filters |
| `POST /api/estate/tenancies` | Tenancy management permission | Create Draft/Pending tenancy after validating property, tenant and owner links |
| `GET /api/estate/tenancies/:tenancyId` | Authorized estate staff, linked landlord or tenant | Return only fields allowed for the actor's relationship |
| `PATCH /api/estate/tenancies/:tenancyId` | Tenancy management permission | Update allowed pre-activation terms; preserve changes and approval history |
| `POST /api/estate/tenancies/:tenancyId/approve` | Tenancy approval permission | Validate no conflicting active tenancy; activate and set effective occupancy |
| `POST /api/estate/tenancies/:tenancyId/renew` | Tenancy management permission | Create linked renewal with new dates/terms and an audit event |
| `POST /api/estate/tenancies/:tenancyId/terminate` | Tenancy management permission | Require termination date/reason, close occupancy and preserve history |

## 6. List query contract

After aligning with the existing API convention, property/resident/tenancy list endpoints should support bounded pagination and safe filters such as:

- property: zone, street, building, type, occupancy, operational status, code/search term
- resident queue: status, property, relationship, submitted date range
- tenancy: property, tenant, landlord, status, start/end/due range

The service must apply authorization and estate scoping before search and counts. Never return cross-estate totals or use unscoped IDs in aggregate endpoints.

The property register response is an allowlisted summary: property ID, code, type, operational status, unit number, derived occupied/vacant state, and bounded structure/occupancy/ownership/tenancy labels only when the actor's relationship policy permits them. The repository derives occupancy at a server timestamp and scopes before filtering, counting and pagination. Raw ownership, occupant, tenancy, document, coordinate or internal relationship records are not register fields.

## 7. Validation and concurrency invariants

- Property code is unique within an estate according to the agreed normalization rule.
- Every hierarchy parent belongs to the same estate as the child.
- Ownership shares, when used, are within the configured range and effective periods do not conflict beyond policy.
- Effective occupancy and tenancy relationships reference the same estate/property and valid user identities.
- The join-request decision is single-winner under concurrent requests.
- A tenancy cannot activate if another conflicting tenancy is active for the property.
- Tenancy approval commits the active tenancy and its linked active occupancy together; renewal approval also retains the expired prior tenancy and closes its prior occupancy when the handoff plan requires it.
- Closing an occupancy or tenancy does not delete associated resident, payment or access history.
- Financial amounts are decimal values with explicit currency; do not use binary floating point.
- Dates are stored consistently and rendered in the estate timezone; end-date inclusivity must be defined by the existing product convention.

## 8. UI mapping

| UI flow | Backend operation |
|---|---|
| Property register and detail | Scoped property list/detail; ownership and occupancy summary endpoints |
| Add/edit property | Property create/update plus validated hierarchy references |
| Resident approval queue | Join-request queue/detail and approve/reject transitions |
| Household member access | Occupant create/end; invitation/identity link through existing Zvend account flow |
| Tenancy list/detail | Tenancy list/detail with actor-sensitive projections |
| Create/renew/terminate tenancy | Explicit transition endpoints with concurrency and audit behavior |
| Resident My Home | Authorized membership/property summary; no client-side property ID grants access |

## 9. Acceptance evidence for Phase 2

Before describing Phase 2 as complete, demonstrate:

1. Estate A staff cannot list or retrieve Estate B properties, residents, ownership or tenancies.
2. A landlord sees only linked properties and permitted tenancy/payment data.
3. A tenant sees only their own tenancy and allowed property information.
4. A resident cannot read another resident's private documents or profile.
5. Ownership, occupancy and tenancy changes preserve past records and audit events.
6. Conflicting active tenancies are rejected safely under concurrent requests.
7. Property archive does not delete financial, access, ownership or tenancy history.

## 10. Integration gates

Before migrations or endpoints are implemented, confirm the existing user/identity and document model, relationship/role conventions, ORM and transaction support, API response/pagination patterns, property hierarchy needs for the first rollout, and rules for multiple owners or concurrent/room-based tenancies. Additive migrations must follow the existing project process; this proposal is not an executable migration.
