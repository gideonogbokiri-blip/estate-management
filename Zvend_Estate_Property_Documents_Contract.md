# Zvend Estate — Property Documents Contract

**Status:** Proposed boundary; reconcile with the existing Zvend private-file service before wiring routes or persistence  
**Scope:** Landlord access to documents associated with properties they currently own through a verified ownership interest

## 1. Security and relationship rules

- Reuse the existing Zvend private-file storage and authorization service. Do not create public buckets, permanent URLs or a second document store.
- A landlord document list is resolved from the authenticated actor and active estate context. The caller cannot provide an authoritative owner, property, tenant or private storage reference.
- A property document is listable only when its property belongs to the selected estate and the actor has an active, verified ownership interest for that property. Apply that relationship before counting, filtering and pagination.
- Recheck current ownership, document availability and the server-owned access policy each time a file is opened. A previously issued document access identifier is not continuing authorization.
- Property and category summaries are safe metadata. They do not grant access to a tenancy agreement or other file content. The host policy must account for document category and any sensitive third-party content.
- Never return storage keys, bucket paths, private file references, provider credentials, or permanent file URLs in the list response.
- Return only a random, non-sensitive document access identifier from the list. Resolve it server-side.
- Create file grants through the existing private-file service, require HTTPS, and cap expiry at five minutes. Return the grant only to the authenticated API adapter, which should redirect or stream without logging or persisting the URL.
- Audit each successful access with actor, estate, property, document, outcome and time. Do not put file content or the grant URL in audit metadata.

## 2. List operation

Proposed operation: `GET /api/estate/landlord/property-documents`

The authenticated actor and active estate come from the Zvend session. Pagination is bounded. An optional property/category filter is only a narrowing selector after the server has scoped the actor's active verified ownership interests; it never grants access.

The allowlisted result contains a non-sensitive `documentAccessId`, property ID and display label, document display name, category, safe MIME type and update timestamp. Supported categories are `ownership`, `tenancy_agreement`, `inspection`, `maintenance`, `insurance` and `other`. Private references and file URLs are excluded.

`backend/modules/people/list-my-landlord-property-documents.js` implements the framework-independent read seam. The repository adapter must scope documents by estate and current verified property ownership before pagination, and return source ownership/property/document rows alongside a small display projection so the use case can verify those relationships.

## 3. Secure access operation

Proposed operation: `GET /api/estate/landlord/property-documents/:documentAccessId/content`

The handler passes the authenticated actor, active estate and opaque access identifier to `access-landlord-property-document.js`. Its lookup rechecks that the document is available, the property and document belong to the estate, and the actor still has active verified ownership. A policy adapter then applies category/record restrictions. The private-file adapter receives the server-resolved storage reference and creates a short-lived HTTPS grant; the handler redirects or streams the content without exposing that reference to the client.

The use case validates the grant expiry (maximum five minutes), audits successful access, and returns only the short-lived grant to the host API adapter. The host must ensure grant URLs are excluded from application/proxy/request logs and browser analytics.

## 4. UI behavior

- The landlord portal may show the safe document name, property, category and update date returned by the list operation.
- Opening a document invokes the secure access operation at that moment. The UI must not cache grants beyond their expiry or display a permanent download link.
- Empty, unavailable and access-denied states must not reveal whether an unrelated property's document exists.
- Preview data must be labelled illustrative. A preview must not suggest that sample metadata links to real file content.

## 5. Integration checks

Before production, verify cross-estate and cross-property isolation, changed/ended ownership behavior, category-specific third-party privacy, opaque identifier handling, HTTPS and TTL enforcement, audit coverage, and redaction of grant URLs from logs. Confirm the Zvend private-file API and its route, redirect and download conventions before adding controllers or schema.
