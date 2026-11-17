const navLabels = {
  overview: 'Overview',
  properties: 'Properties',
  residents: 'Residents',
  tenancies: 'Tenancies',
  visitors: 'Visitors',
  gate: 'Gate operations',
  billing: 'Billing & rent',
  finance: 'Finance & expenses',
  maintenance: 'Maintenance',
  facilities: 'Facilities',
  announcements: 'Announcements',
  reports: 'Reports',
  team: 'Team & access',
  settings: 'Settings',
  subscriptions: 'Plans & subscriptions',
  applications: 'Estate applications'
};

const sectionCopy = {
  residents: 'Review resident applications, household members and estate access.',
  tenancies: 'Manage tenant agreements, key dates and property occupancy history.',
  visitors: 'Manage visitor invitations and see current gate activity.',
  gate: 'Verify visitor passes, record access events and report incidents.',
  billing: 'Review charges, invoices, rent schedules and payment status.',
  finance: 'Review expense requests, budgets and approved estate spend.',
  maintenance: 'Track resident requests, assignments and resolutions.',
  facilities: 'Manage shared spaces, availability rules and resident bookings.',
  announcements: 'Prepare estate updates and important community notices.',
  reports: 'Review occupancy, collections and estate operations.',
  team: 'Manage estate staff access and role assignments.',
  settings: 'Manage estate profile, documents and operational preferences.',
  applications: 'Review estate registrations and record auditable decisions.',
  subscriptions: 'Manage platform plan versions and estate subscription agreements.'
};

const moduleViews = {
  residents: `
    <div class="module-heading"><div><span class="eyebrow">PEOPLE &amp; ACCESS</span><h2>Resident management</h2><p>Review membership requests and manage approved residents.</p></div><button class="button button-primary" data-action="invite"><svg viewBox="0 0 24 24"><path d="M12 5v14M5 12h14"/></svg>Invite a resident</button></div>
    <div class="module-stats"><article><span>ACTIVE RESIDENTS</span><strong>1,284</strong><small>Across 229 occupied units</small></article><article><span>AWAITING REVIEW</span><strong>3</strong><small>Oldest request · 2 days ago</small></article><article><span>INVITATIONS SENT</span><strong>18</strong><small>4 not yet accepted</small></article></div>
    <article class="panel module-panel"><div class="module-toolbar"><div class="segmented"><button class="selected" data-resident-filter="pending">Pending requests <b id="residentPendingFilterCount">3</b></button><button data-resident-filter="all">All records</button><button data-resident-filter="active">Active residents</button></div><label class="search-field"><svg viewBox="0 0 24 24"><circle cx="11" cy="11" r="7"/><path d="m20 20-4-4"/></svg><input id="residentSearch" type="search" placeholder="Search name, unit or email" /></label></div><div class="table-wrap module-table"><table><thead><tr><th>PERSON</th><th>PROPERTY</th><th>RELATIONSHIP</th><th>SUBMITTED / APPROVED</th><th>STATUS</th><th>ACTIONS</th></tr></thead><tbody id="residentRows">
      <tr data-resident-row="pending" data-resident-id="r1"><td><span class="person-avatar person-a">NO</span><span class="request-name"><strong>Ngozi Okonkwo</strong><small>ngozi.o@email.com</small></span></td><td>Oakwood · 14</td><td>Tenant</td><td>Today, 9:42 am</td><td class="resident-state"><span class="status-pill status-review"><i></i>Pending review</span></td><td class="row-actions"><button class="table-action approve-action" data-action="resident-details" data-id="r1">Review</button></td></tr>
      <tr data-resident-row="pending" data-resident-id="r2"><td><span class="person-avatar person-b">EA</span><span class="request-name"><strong>Emeka Anozie</strong><small>emeka.a@email.com</small></span></td><td>Block B · 03</td><td>Household member</td><td>Yesterday, 4:16 pm</td><td class="resident-state"><span class="status-pill status-review"><i></i>Pending review</span></td><td class="row-actions"><button class="table-action approve-action" data-action="resident-details" data-id="r2">Review</button></td></tr>
      <tr data-resident-row="pending" data-resident-id="r3"><td><span class="person-avatar person-c">TB</span><span class="request-name"><strong>Tomiwa Balogun</strong><small>tomiwa.b@email.com</small></span></td><td>Maple Street · 11</td><td>Owner</td><td>2 days ago</td><td class="resident-state"><span class="status-pill status-review"><i></i>Pending review</span></td><td class="row-actions"><button class="table-action approve-action" data-action="resident-details" data-id="r3">Review</button></td></tr>
      <tr data-resident-row="active" data-resident-id="r4"><td><span class="person-avatar visitor-avatar">IK</span><span class="request-name"><strong>Ifeoma Kalu</strong><small>ifeoma.k@email.com</small></span></td><td>Cedar Lane · 03</td><td>Landlord</td><td>Approved 31 Oct 2026</td><td class="resident-state"><span class="status-pill status-active"><i></i>Active</span></td><td><button class="row-more" aria-label="Resident actions">···</button></td></tr>
      <tr data-resident-row="active" data-resident-id="r5"><td><span class="person-avatar person-b">YA</span><span class="request-name"><strong>Yusuf Abdullahi</strong><small>yusuf.a@email.com</small></span></td><td>Oakwood · 09</td><td>Tenant</td><td>Approved 30 Oct 2026</td><td class="resident-state"><span class="status-pill status-active"><i></i>Active</span></td><td><button class="row-more" aria-label="Resident actions">···</button></td></tr>
    </tbody></table></div><div class="module-table-foot"><span id="residentResults">Showing 3 pending requests</span><button class="text-button">View approval history ↗</button></div></article>`,
  tenancies: `
    <div class="module-heading"><div><span class="eyebrow">PROPERTY &amp; PEOPLE</span><h2>Tenancies</h2><p>Agreements, rent terms and occupancy history by property.</p></div><button class="button button-primary" data-action="create-tenancy"><svg viewBox="0 0 24 24"><path d="M12 5v14M5 12h14"/></svg>New tenancy</button></div>
    <div class="module-stats"><article><span>ACTIVE TENANCIES</span><strong>146</strong><small>Across 229 occupied units</small></article><article><span>EXPIRING IN 60 DAYS</span><strong>9</strong><small>Renewal follow-up recommended</small></article><article><span>PENDING APPROVAL</span><strong id="tenancyPendingCount">2</strong><small>Awaiting estate review</small></article></div>
    <article class="panel module-panel"><div class="module-toolbar"><div class="segmented"><button class="selected" data-tenancy-filter="all">All tenancies</button><button data-tenancy-filter="active">Active</button><button data-tenancy-filter="pending">Pending <b id="tenancyPendingFilterCount">2</b></button><button data-tenancy-filter="expiring">Expiring</button></div><label class="search-field"><svg viewBox="0 0 24 24"><circle cx="11" cy="11" r="7"/><path d="m20 20-4-4"/></svg><input id="tenancySearch" type="search" placeholder="Search tenant, landlord or unit" /></label></div><div class="table-wrap module-table"><table><thead><tr><th>PROPERTY / TENANT</th><th>LANDLORD</th><th>RENT</th><th>TERM</th><th>NEXT DUE</th><th>STATUS</th><th></th></tr></thead><tbody id="tenancyRows">
      <tr data-tenancy-id="t-oak-01" data-property-id="oak-01" data-tenancy-status="active" data-tenant="Chioma Adebayo" data-landlord="Emeka Okafor" data-rent="2500000" data-frequency="Annual" data-start="2026-01-01" data-end="2026-12-31" data-search="oakwood 01 chioma adebayo emeka okafor"><td><span class="person-avatar person-b">CA</span><span class="request-name"><strong>Oakwood · 01</strong><small>Chioma Adebayo · Tenant</small></span></td><td>Emeka Okafor</td><td class="amount-cell">₦2,500,000 <small class="cell-sub">Annual</small></td><td>Jan 2026 – Dec 2026</td><td>01 Dec 2026</td><td><span class="status-pill status-active"><i></i>Active</span></td><td><button class="row-more" data-action="tenancy-detail" aria-label="View tenancy">···</button></td></tr>
      <tr data-tenancy-id="t-block-c-12" data-property-id="block-c-12" data-tenancy-status="expiring" data-tenant="Daniel Adewale" data-landlord="Fatima Bello" data-rent="1800000" data-frequency="Annual" data-start="2025-12-01" data-end="2026-11-30" data-search="block c 12 daniel adewale fatima bello"><td><span class="person-avatar person-a">DA</span><span class="request-name"><strong>Block C · 12</strong><small>Daniel Adewale · Tenant</small></span></td><td>Fatima Bello</td><td class="amount-cell">₦1,800,000 <small class="cell-sub">Annual</small></td><td>Dec 2025 – Nov 2026</td><td>—</td><td><span class="status-pill status-expiring"><i></i>Expiring soon</span></td><td><button class="table-action" data-action="renew-tenancy">Renew</button><button class="table-action" data-action="tenancy-detail" aria-label="View tenancy details">Details</button></td></tr>
      <tr data-tenancy-id="t-maple-11" data-property-id="maple-11" data-tenancy-status="pending" data-tenant="Mariam Yusuf" data-landlord="Ola Balogun" data-rent="3200000" data-frequency="Annual" data-start="2026-11-01" data-end="2027-10-31" data-search="maple street 11 mariam yusuf ola balogun"><td><span class="person-avatar person-c">MY</span><span class="request-name"><strong>Maple Street · 11</strong><small>Mariam Yusuf · Tenant</small></span></td><td>Ola Balogun</td><td class="amount-cell">₦3,200,000 <small class="cell-sub">Annual</small></td><td>Nov 2026 – Oct 2027</td><td>01 Nov 2026</td><td><span class="status-pill status-review"><i></i>Pending approval</span></td><td><button class="table-action approve-action" data-action="approve-tenancy">Review</button></td></tr>
      <tr data-tenancy-id="t-cedar-03" data-property-id="cedar-03" data-tenancy-status="active" data-tenant="Tunde Okafor" data-landlord="Ifeoma Kalu" data-rent="2100000" data-frequency="Annual" data-start="2026-08-01" data-end="2027-07-31" data-search="cedar lane 03 tunde okafor ifeoma kalu"><td><span class="person-avatar visitor-avatar">TO</span><span class="request-name"><strong>Cedar Lane · 03</strong><small>Tunde Okafor · Tenant</small></span></td><td>Ifeoma Kalu</td><td class="amount-cell">₦2,100,000 <small class="cell-sub">Annual</small></td><td>Aug 2026 – Jul 2027</td><td>01 Aug 2027</td><td><span class="status-pill status-active"><i></i>Active</span></td><td><button class="row-more" data-action="tenancy-detail" aria-label="View tenancy">···</button></td></tr>
    </tbody></table></div><div class="module-table-foot"><span>Historical agreements remain linked to the property and parties.</span><button class="text-button" data-action="tenancy-export">Export tenancies ↗</button></div></article>`,
  visitors: `
    <div class="module-heading"><div><span class="eyebrow">GATE &amp; VISITOR ACCESS</span><h2>Visitor management</h2><p>Track invitations and gate activity across Oakwood Estate.</p></div><button class="button button-primary" data-action="create-pass"><svg viewBox="0 0 24 24"><path d="M12 5v14M5 12h14"/></svg>Create visitor pass</button></div>
    <div class="module-stats"><article><span>EXPECTED TODAY</span><strong>24</strong><small>Across 3 estate gates</small></article><article><span>ON THE ESTATE</span><strong>7</strong><small>Currently checked in</small></article><article><span>EXPIRING SOON</span><strong>5</strong><small>Within the next 24 hours</small></article></div>
    <article class="panel module-panel"><div class="panel-header"><div><h2>Today's visitor passes</h2><p>Pass details stay limited to what gate staff need.</p></div><button class="filter-button" data-action="visitor-filter">All passes <svg class="chevron" viewBox="0 0 16 16"><path d="m4 6 4 4 4-4"/></svg></button></div><div class="table-wrap module-table"><table><thead><tr><th>VISITOR</th><th>HOST / PROPERTY</th><th>EXPECTED</th><th>PASS</th><th>STATUS</th><th></th></tr></thead><tbody>
      <tr><td><span class="person-avatar visitor-avatar">KM</span><span class="request-name"><strong>Kelechi Madu</strong><small>Visitor · no vehicle</small></span></td><td>Amara Okafor <small class="cell-sub">Oakwood · 01</small></td><td>10:30 am – 1:00 pm</td><td><span class="pass-code">••• 482</span></td><td><span class="status-pill status-checked"><i></i>Checked in</span></td><td><button class="row-more" aria-label="Visitor actions">···</button></td></tr>
      <tr><td><span class="person-avatar person-b">SA</span><span class="request-name"><strong>Sarah Adamu</strong><small>Visitor · Lagos 01 AB 234</small></span></td><td>Chika Eze <small class="cell-sub">Block C · 12</small></td><td>11:00 am – 3:00 pm</td><td><span class="pass-code">••• 193</span></td><td><span class="status-pill status-invited"><i></i>Expected</span></td><td><button class="row-more" aria-label="Visitor actions">···</button></td></tr>
      <tr><td><span class="person-avatar person-c">DO</span><span class="request-name"><strong>David Ojo</strong><small>Delivery · Lagos 02 CX 901</small></span></td><td>Facilities team <small class="cell-sub">Service entrance</small></td><td>12:00 pm – 12:30 pm</td><td><span class="pass-code">••• 725</span></td><td><span class="status-pill status-expiring"><i></i>Expiring soon</span></td><td><button class="row-more" aria-label="Visitor actions">···</button></td></tr>
    </tbody></table></div><div class="gate-note"><span class="online-dot"></span><span><strong>Gate verification online</strong> · Pass verification is handled by the estate service.</span><button class="text-button" data-view="gate">Open gate view ↗</button></div></article>`,
  gate: `
    <div class="module-heading"><div><span class="eyebrow">SECURITY OPERATIONS</span><h2>Gate operations</h2><p>Oakwood Main Gate · Assigned shift · 4 Nov 2026</p></div><span class="gate-live"><i></i>Shift active</span></div>
    <div class="security-workspace">
      <article class="panel gate-operations"><div class="panel-header"><div><h2>Currently on the estate</h2><p>Only the visit details needed for gate operations are shown.</p></div><button class="button button-secondary" data-action="report-incident">Report incident</button></div><div class="table-wrap module-table"><table><thead><tr><th>VISITOR</th><th>HOST / PROPERTY</th><th>ENTRY</th><th>ACCESS</th></tr></thead><tbody id="currentVisitors">
        <tr data-visit-id="visit-km"><td><span class="request-name"><strong>Kelechi Madu</strong><small>Visitor · no vehicle</small></span></td><td>Amara Okafor <small class="cell-sub">Oakwood · 01</small></td><td>10:38 am</td><td><button class="table-action reject-action" data-action="record-access" data-kind="check-out" data-visit="visit-km">Record exit</button></td></tr>
        <tr data-visit-id="visit-sa" class="visit-expected"><td><span class="request-name"><strong>Sarah Adamu</strong><small>Visitor · Lagos 01 AB 234</small></span></td><td>Chika Eze <small class="cell-sub">Block C · 12</small></td><td>Not checked in</td><td><button class="table-action approve-action" data-action="record-access" data-kind="check-in" data-visit="visit-sa">Record entry</button></td></tr>
      </tbody></table></div><p class="security-footnote">A live gate device must verify pass validity and staff assignment with the backend before recording access. These controls only update this preview.</p></article>
      <article class="panel incident-panel"><div class="panel-header"><div><span class="eyebrow">SECURITY FOLLOW-UP</span><h2>Recent incidents</h2><p>Updates retain their history and estate scope.</p></div><button class="button button-secondary" data-action="report-incident">Report incident</button></div><div class="incident-list">
        <p class="incident-live-note" role="status" aria-live="polite">Loading incidents for your assigned security scope...</p>
        <div class="incident-row"><span class="incident-mark incident-mark-warm">!</span><div><strong>Unrecognized vehicle at west gate</strong><small>West Gate · Reported 9:14 am by Gate staff</small></div><span class="status-pill status-review"><i></i>Under review</span><button class="table-action" data-action="incident-review">Review</button></div>
        <div class="incident-row"><span class="incident-mark">i</span><div><strong>Streetlight outage near Block B</strong><small>Block B · Reported yesterday by Samuel Nwosu</small></div><span class="status-pill status-active"><i></i>Assigned</span><button class="table-action" data-action="incident-review">Review</button></div>
      </div><div class="module-table-foot"><span>Incident details and attachments are restricted by estate role.</span><button class="text-button" data-action="incident-history">View incident history →</button></div></article>
    </div>`,
  billing: `
    <div class="module-heading"><div><span class="eyebrow">ESTATE FINANCE</span><h2>Billing &amp; rent</h2><p>Track charges, rent invoices and verified payment status.</p></div><button class="button button-primary" data-action="new-invoice"><svg viewBox="0 0 24 24"><path d="M12 5v14M5 12h14"/></svg>Create invoice</button></div><div class="billing-preview-label">Preview data · connect the authenticated estate billing service to view live records.</div>
    <div class="module-stats"><article><span>BILLED THIS MONTH</span><strong>₦22.5m</strong><small>Across 312 invoices</small></article><article><span>COLLECTED</span><strong>₦18.42m</strong><small>82% of amount due</small></article><article><span>OUTSTANDING</span><strong>₦4.08m</strong><small>12 invoices overdue</small></article></div>
    <article class="panel module-panel"><div class="module-toolbar"><div class="segmented"><button class="selected">All invoices <b>312</b></button><button>Overdue <b class="warm-count">12</b></button><button>Drafts <b>4</b></button></div><button class="filter-button" data-action="invoice-filter"><svg viewBox="0 0 24 24"><path d="M4 7h16M7 12h10m-7 5h4"/></svg>Filters</button></div><div class="table-wrap module-table"><table><thead><tr><th>INVOICE</th><th>PAYER / PROPERTY</th><th>ISSUED</th><th>DUE DATE</th><th>AMOUNT</th><th>STATUS</th></tr></thead><tbody>
      <tr><td><strong>OAK-2026-0312</strong><small class="cell-sub">Estate management fee</small></td><td>Emeka Okafor <small class="cell-sub">Oakwood · 01</small></td><td>01 Nov 2026</td><td>07 Nov 2026</td><td class="amount-cell">₦85,000</td><td><span class="status-pill status-paid"><i></i>Paid</span></td></tr>
      <tr><td><strong>OAK-2026-0311</strong><small class="cell-sub">Annual rent</small></td><td>Chioma Adebayo <small class="cell-sub">Block C · 12</small></td><td>28 Oct 2026</td><td>03 Nov 2026</td><td class="amount-cell">₦2,500,000</td><td><span class="status-pill status-overdue"><i></i>Overdue</span></td></tr>
      <tr><td><strong>OAK-2026-0309</strong><small class="cell-sub">Security levy</small></td><td>Fatima Bello <small class="cell-sub">Block A · 06</small></td><td>27 Oct 2026</td><td>10 Nov 2026</td><td class="amount-cell">₦45,000</td><td><span class="status-pill status-partial"><i></i>Part-paid</span></td></tr>
    </tbody></table></div><div class="finance-note"><svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="9"/><path d="M12 11v5M12 8h.01"/></svg><span>Payment status is confirmed by Zvend’s trusted payment service; a browser redirect alone never marks an invoice as paid.</span></div></article>`,
  finance: `
    <div class="module-heading"><div><span class="eyebrow">ESTATE FINANCE</span><h2>Finance &amp; expenses</h2><p>Track operating spend, approval requests and estate budget usage.</p></div><button class="button button-primary" data-action="new-expense"><svg viewBox="0 0 24 24"><path d="M12 5v14M5 12h14"/></svg>Request expense</button></div>
    <div class="module-stats"><article><span>SPEND THIS MONTH</span><strong>₦4.82m</strong><small>Across 38 approved expenses</small></article><article><span>AWAITING APPROVAL</span><strong>3</strong><small>₦1,145,000 requested</small></article><article><span>MONTHLY BUDGET USED</span><strong>68%</strong><small>₦4.82m of ₦7.1m</small></article></div>
    <section class="budget-panel panel"><div class="panel-header"><div><h2>Budget overview</h2><p>November 2026 · Actuals include approved and paid expenses</p></div><button class="text-button" data-action="budget-settings">Manage budgets ↗</button></div><div class="budget-list"><div class="budget-line"><div><span>Maintenance</span><strong>₦1.64m <small>of ₦2.2m</small></strong></div><div class="budget-track"><i style="width:75%"></i></div></div><div class="budget-line"><div><span>Security</span><strong>₦1.28m <small>of ₦1.8m</small></strong></div><div class="budget-track"><i style="width:71%"></i></div></div><div class="budget-line"><div><span>Utilities</span><strong>₦920k <small>of ₦1.5m</small></strong></div><div class="budget-track"><i style="width:61%"></i></div></div><div class="budget-line"><div><span>Cleaning</span><strong>₦540k <small>of ₦900k</small></strong></div><div class="budget-track"><i style="width:60%"></i></div></div></div></section>
    <article class="panel module-panel"><div class="module-toolbar"><div class="segmented"><button class="selected" data-expense-filter="all">All requests</button><button data-expense-filter="pending">Needs approval <b>3</b></button><button data-expense-filter="approved">Approved</button><button data-expense-filter="paid">Paid</button></div><label class="search-field"><svg viewBox="0 0 24 24"><circle cx="11" cy="11" r="7"/><path d="m20 20-4-4"/></svg><input id="expenseSearch" type="search" placeholder="Search description or payee" /></label></div><div class="table-wrap module-table"><table><thead><tr><th>EXPENSE</th><th>CATEGORY</th><th>REQUESTED BY</th><th>PAYEE</th><th>AMOUNT</th><th>DATE</th><th>STATUS / ACTION</th></tr></thead><tbody id="expenseRows">
      <tr data-expense-status="pending" data-search="generator servicing bay power cooling maintenance"><td><span class="expense-type-icon"><svg viewBox="0 0 24 24"><path d="M4 19h16M6 19V8l6-4 6 4v11M9 19v-6h6v6"/></svg></span><span class="request-name"><strong>Generator servicing</strong><small>EXP-2026-041 · 2 invoices attached</small></span></td><td>Maintenance</td><td>Amara Okafor</td><td>Bay Power &amp; Cooling</td><td class="amount-cell">₦420,000</td><td>4 Nov 2026</td><td class="expense-state"><button class="table-action approve-action" data-action="approve-expense">Review</button></td></tr>
      <tr data-expense-status="pending" data-search="gate camera replacement securegate systems security"><td><span class="expense-type-icon security-expense"><svg viewBox="0 0 24 24"><path d="M3 11h18M5 11l1-5h12l1 5v8H5v-8ZM9 19v2m6-2v2M8 9h.01M16 9h.01"/></svg></span><span class="request-name"><strong>Gate camera replacement</strong><small>EXP-2026-040 · 1 quote attached</small></span></td><td>Security</td><td>Samuel Nwosu</td><td>SecureGate Systems</td><td class="amount-cell">₦475,000</td><td>3 Nov 2026</td><td class="expense-state"><button class="table-action approve-action" data-action="approve-expense">Review</button></td></tr>
      <tr data-expense-status="pending" data-search="night patrol overtime sentinel patrol security"><td><span class="expense-type-icon security-expense"><svg viewBox="0 0 24 24"><path d="M12 3v3m0 12v3M4 12h3m10 0h3M5.6 5.6l2.1 2.1m8.6 8.6 2.1 2.1m0-12.8-2.1 2.1m-8.6 8.6-2.1 2.1"/><circle cx="12" cy="12" r="5"/></svg></span><span class="request-name"><strong>Night patrol overtime</strong><small>EXP-2026-039 · Shift report attached</small></span></td><td>Security</td><td>Facilities Manager</td><td>Sentinel Patrol</td><td class="amount-cell">₦250,000</td><td>3 Nov 2026</td><td class="expense-state"><button class="table-action approve-action" data-action="approve-expense">Review</button></td></tr>
      <tr data-expense-status="approved" data-search="waste collection greencycle services cleaning"><td><span class="expense-type-icon cleaning-expense"><svg viewBox="0 0 24 24"><path d="M5 7h14M10 11v6m4-6v6M6 7l1 14h10l1-14M9 7V4h6v3"/></svg></span><span class="request-name"><strong>Waste collection</strong><small>EXP-2026-038 · Approved by Finance</small></span></td><td>Cleaning</td><td>Amara Okafor</td><td>GreenCycle Services</td><td class="amount-cell">₦250,000</td><td>2 Nov 2026</td><td class="expense-state"><span class="status-pill status-active"><i></i>Approved</span></td></tr>
      <tr data-expense-status="paid" data-search="water pump repairs aqua works maintenance"><td><span class="expense-type-icon"><svg viewBox="0 0 24 24"><path d="M4 19h16M6 19V8l6-4 6 4v11M9 19v-6h6v6"/></svg></span><span class="request-name"><strong>Water pump repairs</strong><small>EXP-2026-032 · Payment confirmed</small></span></td><td>Maintenance</td><td>Facility Manager</td><td>Aqua Works Ltd.</td><td class="amount-cell">₦180,000</td><td>29 Oct 2026</td><td class="expense-state"><span class="status-pill status-paid"><i></i>Paid</span></td></tr>
    </tbody></table></div><div class="finance-note"><svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="9"/><path d="M12 11v5M12 8h.01"/></svg><span>Approval does not record payment. Posted transactions are reconciled against verified Zvend/payment records and corrected through audited adjustments.</span></div></article>`,
  maintenance: `
    <div class="module-heading"><div><span class="eyebrow">ESTATE OPERATIONS</span><h2>Maintenance requests</h2><p>Review reported issues, assign a team and track resolution.</p></div><button class="button button-secondary" data-action="maintenance-categories">Manage categories</button></div>
    <div class="module-stats"><article><span>OPEN REQUESTS</span><strong>8</strong><small>2 high priority</small></article><article><span>IN PROGRESS</span><strong>5</strong><small>Assigned to estate staff</small></article><article><span>RESOLVED THIS MONTH</span><strong>31</strong><small>Average 2.4 day resolution</small></article></div>
    <article class="panel module-panel"><div class="module-toolbar"><div class="segmented"><button class="selected" data-maintenance-filter="open">Open <b>8</b></button><button data-maintenance-filter="in_progress">In progress <b>5</b></button><button data-maintenance-filter="resolved">Resolved</button></div><label class="search-field"><svg viewBox="0 0 24 24"><circle cx="11" cy="11" r="7"/><path d="m20 20-4-4"/></svg><input id="maintenanceSearch" type="search" placeholder="Search requests or property" /></label></div><div class="table-wrap module-table"><table><thead><tr><th>REQUEST</th><th>PROPERTY</th><th>REPORTED BY</th><th>ASSIGNED TO</th><th>PRIORITY</th><th>STATUS</th><th></th></tr></thead><tbody id="maintenanceQueueRows">
      <tr data-maintenance-id="m1"><td><span class="request-symbol plumbing">⌁</span><span class="request-name"><strong>Water pressure issue</strong><small>Plumbing · 2 hours ago · REQ-00318</small></span></td><td>Block C · 12</td><td>Chioma Adebayo</td><td>Facilities team</td><td><span class="priority priority-high">High</span></td><td class="maintenance-status"><span class="status-pill status-progress"><i></i>In progress</span></td><td><button class="table-action" data-action="maintenance-review" data-id="m1">Review</button></td></tr>
      <tr data-maintenance-id="m2"><td><span class="request-symbol electrical">ϟ</span><span class="request-name"><strong>Street light repair</strong><small>Electrical · Yesterday · REQ-00317</small></span></td><td>Maple Street</td><td>Daniel Adewale</td><td>Unassigned</td><td><span class="priority priority-medium">Medium</span></td><td class="maintenance-status"><span class="status-pill status-review"><i></i>Under review</span></td><td><button class="table-action" data-action="maintenance-review" data-id="m2">Review</button></td></tr>
      <tr data-maintenance-id="m3"><td><span class="request-symbol general">⌂</span><span class="request-name"><strong>Gate access card</strong><small>Access · 2 days ago · REQ-00316</small></span></td><td>Oakwood · 08</td><td>Musa Abdullahi</td><td>Samuel Nwosu</td><td><span class="priority priority-low">Low</span></td><td class="maintenance-status"><span class="status-pill status-assigned"><i></i>Assigned</span></td><td><button class="table-action" data-action="maintenance-review" data-id="m3">Review</button></td></tr>
    </tbody></table></div><div class="module-table-foot"><span class="maintenance-preview-note">Resident updates and staff-only notes are stored separately. This queue is preview data until connected.</span><div class="maintenance-page-controls"><span id="maintenancePageSummary">Page 1</span><button id="maintenancePagePrevious" type="button" aria-label="Previous maintenance page">‹</button><button id="maintenancePageNext" type="button" aria-label="Next maintenance page">›</button></div></div></article>`,
  facilities: `
    <div class="module-heading"><div><span class="eyebrow">SHARED ESTATE SPACES</span><h2>Facilities &amp; bookings</h2><p>Set availability and review resident booking requests.</p></div><button class="button button-primary" data-action="add-facility"><svg viewBox="0 0 24 24"><path d="M12 5v14M5 12h14"/></svg>Add facility</button></div>
    <div class="module-stats"><article><span>ACTIVE FACILITIES</span><strong>3</strong><small>Community spaces available to residents</small></article><article><span>BOOKING REQUESTS</span><strong>4</strong><small>2 need administrator review</small></article><article><span>UPCOMING BOOKINGS</span><strong>18</strong><small>Next 7 days</small></article></div>
    <section class="facility-card-grid"><article class="facility-admin-card"><div class="facility-admin-art hall-admin-art"><span>COMMUNITY</span><div class="facility-building"><i></i><i></i><i></i></div></div><div class="facility-admin-copy"><div><h3>Community hall</h3><span class="status-pill status-active"><i></i>Available</span></div><p>Capacity 80 · Fee and deposit set by estate policy</p><button class="text-button" data-action="facility-settings">Manage facility ↗</button></div></article><article class="facility-admin-card"><div class="facility-admin-art court-admin-art"><span>RECREATION</span><div class="court-admin-lines"></div></div><div class="facility-admin-copy"><div><h3>Tennis court</h3><span class="status-pill status-active"><i></i>Available</span></div><p>Capacity 4 · 60-minute booking slots</p><button class="text-button" data-action="facility-settings">Manage facility ↗</button></div></article><article class="facility-admin-card"><div class="facility-admin-art pool-admin-art"><span>LEISURE</span><div class="pool-art"><i></i><i></i><i></i></div></div><div class="facility-admin-copy"><div><h3>Swimming pool</h3><span class="status-pill status-active"><i></i>Available</span></div><p>Capacity 20 · Resident guest rules apply</p><button class="text-button" data-action="facility-settings">Manage facility ↗</button></div></article></section>
    <article class="panel module-panel"><div class="panel-header"><div><h2>Booking requests</h2><p>Review requests before confirming shared-space availability.</p></div><div class="segmented"><button class="selected">Needs review <b>2</b></button><button>Upcoming</button></div></div><div class="table-wrap module-table"><table><thead><tr><th>FACILITY / DATE</th><th>RESIDENT</th><th>PROPERTY</th><th>ATTENDEES</th><th>STATUS</th><th>ACTIONS</th></tr></thead><tbody>
      <tr data-booking-id="b1"><td><span class="request-name"><strong>Community hall</strong><small>Saturday, 7 Nov · 10 am–1 pm</small></span></td><td>Amara Okafor</td><td>Oakwood · 01</td><td>35 guests</td><td class="booking-state"><span class="status-pill status-review"><i></i>Pending</span></td><td class="row-actions"><button class="table-action approve-action" data-action="approve-booking" data-id="b1">Approve</button><button class="table-action reject-action" data-action="decline-booking" data-id="b1">Decline</button></td></tr>
      <tr data-booking-id="b2"><td><span class="request-name"><strong>Tennis court</strong><small>Today, 4 Nov · 4–5 pm</small></span></td><td>Tunde Okafor</td><td>Oakwood · 01</td><td>2 players</td><td class="booking-state"><span class="status-pill status-review"><i></i>Pending</span></td><td class="row-actions"><button class="table-action approve-action" data-action="approve-booking" data-id="b2">Approve</button><button class="table-action reject-action" data-action="decline-booking" data-id="b2">Decline</button></td></tr>
    </tbody></table></div><div class="module-table-foot"><span>Booking approval must recheck availability to prevent conflicts.</span><button class="text-button" data-action="booking-calendar">Open booking calendar ↗</button></div></article>`,
  announcements: `
    <div class="module-heading"><div><span class="eyebrow">COMMUNITY COMMUNICATION</span><h2>Announcements</h2><p>Share timely updates with all residents or a specific group.</p></div><button class="button button-primary" data-action="compose-announcement"><svg viewBox="0 0 24 24"><path d="M12 5v14M5 12h14"/></svg>New announcement</button></div>
    <div class="module-stats"><article><span>SENT THIS MONTH</span><strong>12</strong><small>Across 4 resident groups</small></article><article><span>AVERAGE READ RATE</span><strong>78%</strong><small>Across delivered updates</small></article><article><span>SCHEDULED</span><strong>2</strong><small>Next notice · Friday, 8 am</small></article></div>
    <article class="panel module-panel"><div class="module-toolbar"><div class="segmented"><button class="selected" data-announcement-filter="all">All updates</button><button data-announcement-filter="published">Published</button><button data-announcement-filter="scheduled">Scheduled</button><button data-announcement-filter="draft">Drafts</button></div><button class="filter-button" data-action="announcement-audience">Audience <svg class="chevron" viewBox="0 0 16 16"><path d="m4 6 4 4 4-4"/></svg></button></div><div class="table-wrap module-table"><table><thead><tr><th>ANNOUNCEMENT</th><th>AUDIENCE</th><th>DELIVERY</th><th>DATE</th><th>READ RATE</th><th>STATUS</th><th></th></tr></thead><tbody id="announcementRows">
      <tr data-announcement-status="published"><td><span class="announcement-row-icon"><svg viewBox="0 0 24 24"><path d="M4 11v2a2 2 0 0 0 2 2h2l9 5V4l-9 5H6a2 2 0 0 0-2 2Z"/></svg></span><span class="request-name"><strong>Water maintenance this Friday</strong><small>Service update · Posted by Amara</small></span></td><td>All residents</td><td><span class="channel-badge">Push</span><span class="channel-badge">Email</span></td><td>3 Nov 2026</td><td><div class="read-rate"><i><b style="width:84%"></b></i><span>84%</span></div></td><td><span class="status-pill status-active"><i></i>Published</span></td><td><button class="row-more" data-action="announcement-detail" aria-label="Announcement details">···</button></td></tr>
      <tr data-announcement-status="scheduled"><td><span class="announcement-row-icon emergency-row"><svg viewBox="0 0 24 24"><path d="M12 22s8-4 8-11V5l-8-3-8 3v6c0 7 8 11 8 11Z"/><path d="M12 8v4m0 4h.01"/></svg></span><span class="request-name"><strong>Gate access system update</strong><small>Scheduled service notice · Posted by Amara</small></span></td><td>All residents</td><td><span class="channel-badge">Push</span><span class="channel-badge">SMS</span></td><td>6 Nov 2026 · 8:00 am</td><td><span class="muted-value">—</span></td><td><span class="status-pill status-review"><i></i>Scheduled</span></td><td><button class="row-more" data-action="announcement-detail" aria-label="Announcement details">···</button></td></tr>
      <tr data-announcement-status="published"><td><span class="announcement-row-icon"><svg viewBox="0 0 24 24"><path d="M4 11v2a2 2 0 0 0 2 2h2l9 5V4l-9 5H6a2 2 0 0 0-2 2Z"/></svg></span><span class="request-name"><strong>October residents meeting</strong><small>Community event · Posted by Estate Office</small></span></td><td>Landlords</td><td><span class="channel-badge">Email</span></td><td>28 Oct 2026</td><td><div class="read-rate"><i><b style="width:71%"></b></i><span>71%</span></div></td><td><span class="status-pill status-active"><i></i>Published</span></td><td><button class="row-more" data-action="announcement-detail" aria-label="Announcement details">···</button></td></tr>
    </tbody></table></div><div class="module-table-foot"><span>Recipients are resolved from current estate memberships and targeting rules.</span><button class="text-button" data-action="announcement-preferences">Manage notification preferences ↗</button></div></article>`,
  reports: `
    <div class="module-heading"><div><span class="eyebrow">ESTATE INSIGHTS</span><h2>Reports &amp; analytics</h2><p>Estate-scoped summaries from property, billing and operations records.</p></div><button class="button button-secondary" data-action="report-export">Export report</button></div>
    <div class="report-filters"><label>Date range<select><option>1–30 November 2026</option><option>Last 30 days</option><option>Custom range</option></select></label><label>Report area<select><option>Estate overview</option><option>Occupancy</option><option>Collections</option><option>Maintenance</option><option>Facility bookings</option></select></label><span class="report-asof">Sample view · figures must reconcile to source records</span></div>
    <div class="module-stats report-stats"><article><span>OCCUPANCY</span><strong>94.3%</strong><small>234 occupied of 248 properties</small></article><article><span>CHARGES COLLECTED</span><strong>₦18.42m</strong><small>From verified allocations</small></article><article><span>OUTSTANDING</span><strong>₦4.08m</strong><small>Across 12 overdue invoices</small></article><article><span>OPEN MAINTENANCE</span><strong>8</strong><small>2 high priority</small></article></div>
    <article class="panel module-panel"><div class="panel-header"><div><h2>Collection summary</h2><p>November 2026 · Oakwood Estate</p></div><span class="report-freshness"><i></i>Sample data</span></div><div class="table-wrap module-table"><table><thead><tr><th>CHARGE CATEGORY</th><th>INVOICED</th><th>COLLECTED</th><th>OUTSTANDING</th><th>COLLECTION RATE</th></tr></thead><tbody>
      <tr><td>Estate management fee</td><td>₦10,400,000</td><td>₦8,965,000</td><td>₦1,435,000</td><td><div class="report-rate"><i><b style="width:86%"></b></i><span>86%</span></div></td></tr>
      <tr><td>Security fee</td><td>₦6,200,000</td><td>₦5,210,000</td><td>₦990,000</td><td><div class="report-rate"><i><b style="width:84%"></b></i><span>84%</span></div></td></tr>
      <tr><td>Water and services</td><td>₦3,500,000</td><td>₦2,815,000</td><td>₦685,000</td><td><div class="report-rate"><i><b style="width:80%"></b></i><span>80%</span></div></td></tr>
      <tr><td>Other estate charges</td><td>₦2,400,000</td><td>₦1,430,000</td><td>₦970,000</td><td><div class="report-rate"><i><b style="width:60%"></b></i><span>60%</span></div></td></tr>
    </tbody><tfoot><tr><th>Total</th><th>₦22,500,000</th><th>₦18,420,000</th><th>₦4,080,000</th><th>82%</th></tr></tfoot></table></div><div class="report-note">Financial reports must be generated from verified invoices, payments and allocations. Export access is separately permissioned.</div></article>
    <div class="report-card-grid"><button class="report-link-card" data-action="report-open"><span>PROPERTY REGISTER</span><strong>Property and occupancy</strong><small>Unit status, type and occupancy history →</small></button><button class="report-link-card" data-action="report-open"><span>PEOPLE &amp; TENANCIES</span><strong>Tenancy and expiry</strong><small>Authorized tenant and renewal records →</small></button><button class="report-link-card" data-action="report-open"><span>ESTATE OPERATIONS</span><strong>Maintenance performance</strong><small>Priority, assignment and resolution times →</small></button><button class="report-link-card" data-action="report-open"><span>SECURITY &amp; FACILITIES</span><strong>Access and bookings</strong><small>Gate events, incidents and reservations →</small></button></div>`,
  team: `
    <div class="module-heading"><div><span class="eyebrow">STAFF &amp; PERMISSIONS</span><h2>Team &amp; access</h2><p>Manage estate memberships and role assignments.</p></div><button class="button button-primary" data-action="invite-staff">Invite staff</button></div>
    <div class="module-stats"><article><span>ACTIVE STAFF</span><strong>12</strong><small>Across 6 estate roles</small></article><article><span>INVITATIONS PENDING</span><strong id="pendingStaffInvitations">2</strong><small>Waiting for account acceptance</small></article><article><span>RECENT ACCESS CHANGES</span><strong>3</strong><small>Recorded this month</small></article></div>
    <article class="panel module-panel"><div class="module-toolbar"><div class="segmented"><button class="selected" data-team-filter="all">All</button><button data-team-filter="active">Active staff</button><button data-team-filter="pending">Invitations <b id="teamInvitationFilterCount">2</b></button></div><label class="search-field"><svg viewBox="0 0 24 24"><circle cx="11" cy="11" r="7"/><path d="m20 20-4-4"/></svg><input id="teamSearch" type="search" placeholder="Search name, email or role" /></label></div><div class="table-wrap module-table"><table><thead><tr><th>TEAM MEMBER</th><th>ROLE</th><th>ACCESS SCOPE</th><th>STATUS</th><th>LAST ACTIVE</th><th></th></tr></thead><tbody id="teamRows">
      <tr><td><span class="person-avatar person-a">AO</span><span class="request-name"><strong>Amara Okafor</strong><small>amara.o@zvend.example · Estate membership</small></span></td><td>Estate administrator</td><td>Estate-wide · delegated grants</td><td><span class="status-pill status-active"><i></i>Active</span></td><td>Now</td><td><button class="row-more" data-action="member-details" aria-label="Member details">···</button></td></tr>
      <tr><td><span class="person-avatar person-b">SN</span><span class="request-name"><strong>Samuel Nwosu</strong><small>samuel.n@zvend.example</small></span></td><td>Security supervisor</td><td>Assigned gates and incidents</td><td><span class="status-pill status-active"><i></i>Active</span></td><td>Today, 8:12 am</td><td><button class="row-more" data-action="member-details" aria-label="Member details">···</button></td></tr>
      <tr><td><span class="person-avatar person-c">FK</span><span class="request-name"><strong>Fatima Kalu</strong><small>fatima.k@zvend.example</small></span></td><td>Estate accountant</td><td>Billing and finance</td><td><span class="status-pill status-active"><i></i>Active</span></td><td>Yesterday</td><td><button class="row-more" data-action="member-details" aria-label="Member details">···</button></td></tr>
      <tr data-staff-status="pending"><td><span class="person-avatar visitor-avatar">JO</span><span class="request-name"><strong>Joseph Osei</strong><small>joseph.o@zvend.example</small></span></td><td>Maintenance officer</td><td>Assigned work requests</td><td><span class="status-pill status-review"><i></i>Invitation pending</span></td><td>Not accepted</td><td><button class="row-more" data-action="member-details" aria-label="Member details">···</button></td></tr>
    </tbody></table></div><div class="module-table-foot"><span>Effective permissions are resolved and enforced by the backend for each request.</span><button class="text-button" data-action="audit-history">View access history →</button></div></article>
    <section class="permission-template-grid"><article class="panel permission-template"><span class="eyebrow">ROLE TEMPLATE</span><h3>Security personnel</h3><p>Gate verification and assigned-incident updates.</p><div><span>Gate scope</span><span>Assigned only</span></div></article><article class="panel permission-template"><span class="eyebrow">ROLE TEMPLATE</span><h3>Estate accountant</h3><p>Invoices, verified payments and authorized reconciliation.</p><div><span>Financial scope</span><span>Estate only</span></div></article><article class="panel permission-template"><span class="eyebrow">ROLE TEMPLATE</span><h3>Facility manager</h3><p>Facility policy, booking review and assigned work.</p><div><span>Operations scope</span><span>Estate only</span></div></article></section>`,
  settings: `
    <div class="module-heading"><div><span class="eyebrow">ESTATE CONFIGURATION</span><h2>Estate settings</h2><p>Manage estate details and operating preferences.</p></div><button class="button button-primary" data-action="save-settings">Save changes</button></div>
    <div class="settings-layout"><div class="settings-main-column">
      <article class="panel settings-panel"><div class="panel-header"><div><h2>Estate profile</h2><p>Shown to authorized residents and staff.</p></div><span class="settings-version">Version 7</span></div><div class="compose-fields"><div><label class="compose-label" for="settingEstateName">Estate name</label><input class="compose-input" id="settingEstateName" value="Oakwood Estate" /></div><div><label class="compose-label" for="settingEstateType">Estate type</label><select class="compose-input" id="settingEstateType"><option>Gated community</option><option>Apartment complex</option><option>Mixed use</option></select></div><div><label class="compose-label" for="settingEstateEmail">Office email</label><input class="compose-input" id="settingEstateEmail" value="office@oakwood.example" /></div><div><label class="compose-label" for="settingEstatePhone">Office phone</label><input class="compose-input" id="settingEstatePhone" value="+234 800 000 0101" /></div></div></article>
      <article class="panel settings-panel"><div class="panel-header"><div><h2>Regional preferences</h2><p>Used for date presentation and eligible payment options.</p></div></div><div class="compose-fields"><div><label class="compose-label" for="settingTimezone">Estate time zone</label><select class="compose-input" id="settingTimezone"><option>Africa/Lagos (WAT)</option><option>Africa/Accra (GMT)</option></select></div><div><label class="compose-label" for="settingCurrency">Display currency</label><select class="compose-input" id="settingCurrency"><option>NGN · Nigerian naira</option></select></div></div><p class="settings-inline-note">Currency and payment destinations must also be supported by Zvend's payment service.</p></article>
      <article class="panel settings-panel"><div class="panel-header"><div><h2>Resident access</h2><p>Joining requests remain subject to estate review.</p></div></div><div class="setting-row"><div><strong>Resident join requests</strong><small>Require administrator approval before membership is active.</small></div><span class="settings-state">Approval required</span></div><div class="setting-row"><div><strong>Visitor pass maximum duration</strong><small>Default maximum allowed by estate policy.</small></div><span class="settings-state">24 hours</span></div></article>
    </div><aside class="settings-side-column"><article class="panel settings-panel"><span class="eyebrow">CHANGE HISTORY</span><h3>Recent settings updates</h3><div class="setting-history"><div><i></i><span><strong>Resident join review enabled</strong><small>Amara Okafor · 2 Nov 2026</small></span></div><div><i></i><span><strong>Office contact updated</strong><small>Amara Okafor · 20 Oct 2026</small></span></div><div><i></i><span><strong>Estate time zone confirmed</strong><small>Platform operations · 18 Oct 2026</small></span></div></div><p class="settings-inline-note">Historical invoices, passes and bookings keep the policy version used when they were created.</p></article><article class="panel settings-panel"><span class="eyebrow">PLATFORM PLAN</span><h3>Professional</h3><p>Plan limits and subscription billing are managed by Zvend Platform. Estate settings cannot change platform limits.</p><button class="text-button" data-action="plan-details">View plan details →</button></article></aside></div>`,
  subscriptions: `
    <div class="module-heading"><div><span class="eyebrow">ZVEND PLATFORM · COMMERCIAL</span><h2>Plans &amp; subscriptions</h2><p>Manage platform agreements separately from estate resident charges.</p></div><button class="button button-primary" data-action="create-plan">Create plan version</button></div>
    <div class="module-stats"><article><span>ACTIVE SUBSCRIPTIONS</span><strong>38</strong><small>Across 4 plan types</small></article><article><span>ACTIVE TRIALS</span><strong>4</strong><small>Trial terms are configurable</small></article><article><span>RENEWALS IN 30 DAYS</span><strong>6</strong><small>Review upcoming agreements</small></article></div>
    <div class="platform-plan-heading"><div><h2>Plan catalog</h2><p>Example entitlements only · price and limits are configured by version.</p></div><button class="text-button" data-action="plan-history">View plan version history →</button></div>
    <section class="platform-plan-grid"><article class="panel platform-plan-card"><span class="eyebrow">EXAMPLE PLAN</span><h3>Starter</h3><p>Core estate operations for smaller communities.</p><div><span>Property limit</span><strong>Configured per version</strong></div><div><span>Staff limit</span><strong>Configured per version</strong></div><div><span>Modules &amp; storage</span><strong>Configurable</strong></div><div class="plan-card-foot"><span class="plan-version-tag">Published version shown on agreement</span><button class="text-button" data-action="edit-plan">Manage version →</button></div></article><article class="panel platform-plan-card platform-plan-featured"><span class="eyebrow">EXAMPLE PLAN</span><h3>Professional</h3><p>Expanded operations and reporting for active estates.</p><div><span>Property limit</span><strong>Configured per version</strong></div><div><span>Staff limit</span><strong>Configured per version</strong></div><div><span>Modules &amp; storage</span><strong>Configurable</strong></div><div class="plan-card-foot"><span class="plan-version-tag">Oakwood uses a sample agreement</span><button class="text-button" data-action="edit-plan">Manage version →</button></div></article><article class="panel platform-plan-card"><span class="eyebrow">EXAMPLE PLAN</span><h3>Enterprise / Custom</h3><p>Negotiated scope, price and support terms.</p><div><span>Limits</span><strong>Contract-defined</strong></div><div><span>Billing interval</span><strong>Contract-defined</strong></div><div><span>Modules &amp; support</span><strong>Contract-defined</strong></div><div class="plan-card-foot"><span class="plan-version-tag">Terms require platform approval</span><button class="text-button" data-action="edit-plan">Manage version →</button></div></article></section>
    <article class="panel module-panel platform-subscription-panel"><div class="panel-header"><div><h2>Estate subscriptions</h2><p>Platform billing status and effective agreement version.</p></div><button class="filter-button" data-action="subscription-filter">All subscriptions</button></div><div class="table-wrap module-table"><table><thead><tr><th>ESTATE / BILLING CONTACT</th><th>AGREEMENT</th><th>BILLING CYCLE</th><th>NEXT REVIEW</th><th>SUBSCRIPTION</th><th>PAYMENT</th><th></th></tr></thead><tbody>
      <tr><td><span class="estate-table-avatar estate-alt">O</span><span class="request-name"><strong>Oakwood Estate</strong><small>Billing contact · estate owner</small></span></td><td>Professional · v2</td><td>Annual</td><td>1 Dec 2026</td><td><span class="status-pill status-active"><i></i>Active</span></td><td><span class="platform-payment-state">Current</span></td><td><button class="row-more" data-action="subscription-details" aria-label="Oakwood subscription details">···</button></td></tr>
      <tr><td><span class="estate-table-avatar">G</span><span class="request-name"><strong>Greenfield Gardens</strong><small>Billing contact · Ola Williams</small></span></td><td>Starter · v1</td><td>Monthly</td><td>Trial ends 30 Nov</td><td><span class="status-pill status-review"><i></i>Trial</span></td><td><span class="platform-payment-state platform-payment-pending">Not yet due</span></td><td><button class="row-more" data-action="subscription-details" aria-label="Greenfield subscription details">···</button></td></tr>
      <tr><td><span class="estate-table-avatar estate-gold">H</span><span class="request-name"><strong>Harbour Point Estate</strong><small>Billing contact · Bisola Adeyemi</small></span></td><td>Custom · contract v3</td><td>Quarterly</td><td>15 Nov 2026</td><td><span class="status-pill status-active"><i></i>Active</span></td><td><span class="platform-payment-state">Current</span></td><td><button class="row-more" data-action="subscription-details" aria-label="Harbour Point subscription details">···</button></td></tr>
      <tr><td><span class="estate-table-avatar estate-gold">M</span><span class="request-name"><strong>Maple Court</strong><small>Billing contact · estate administrator</small></span></td><td>Professional · v1</td><td>Annual</td><td>8 Nov 2026</td><td><span class="status-pill status-expiring"><i></i>Renewal due</span></td><td><span class="platform-payment-state platform-payment-pending">Invoice pending</span></td><td><button class="row-more" data-action="subscription-details" aria-label="Maple Court subscription details">···</button></td></tr>
    </tbody></table></div><div class="platform-billing-note">Sample records only. Platform invoices and payment states must come from Zvend's existing billing and payment services.</div></article>`,
  applications: `
    <div class="module-heading"><div><span class="eyebrow">ZVEND PLATFORM</span><h2>Estate applications</h2><p>Review new estates, verify documents and record an approval decision.</p></div><div class="application-heading-actions"><a class="button button-secondary" href="./apply.html">Preview applicant form ↗</a><button class="filter-button" data-action="application-filter">All statuses <svg class="chevron" viewBox="0 0 16 16"><path d="m4 6 4 4 4-4"/></svg></button></div></div>
    <div class="module-stats"><article><span>AWAITING REVIEW</span><strong>6</strong><small>Oldest application · 4 days ago</small></article><article><span>UNDER REVIEW</span><strong>3</strong><small>Assigned to platform reviewers</small></article><article><span>APPROVED THIS MONTH</span><strong>12</strong><small>Across 4 estate types</small></article></div>
    <article class="panel module-panel"><div class="panel-header"><div><h2>Applications requiring review</h2><p>Confirm estate and applicant details before activation.</p></div><span class="review-sla">Typical review · 2 business days</span></div><div class="table-wrap module-table"><table><thead><tr><th>ESTATE</th><th>APPLICANT</th><th>LOCATION</th><th>TYPE</th><th>SUBMITTED</th><th>STATUS</th><th></th></tr></thead><tbody>
      <tr data-application-id="e1"><td><span class="estate-table-avatar">G</span><span class="request-name"><strong>Greenfield Gardens</strong><small>Application · ZVE-1048</small></span></td><td>Ola Williams</td><td>Lekki, Lagos</td><td>Residential</td><td>Today</td><td class="application-state"><span class="status-pill status-review"><i></i>Pending</span></td><td><button class="table-action approve-action" data-action="review-estate" data-id="e1">Review</button></td></tr>
      <tr class="application-details hidden" data-details-for="e1"><td colspan="7"><div class="application-detail-grid"><div><span>APPLICANT / OPERATOR</span><strong>Ola Williams · Management company</strong><small>Greenfield Property Services Ltd. · RC 1849201</small></div><div><span>CONTACT</span><strong>ola.williams@example.com</strong><small>+234 803 555 0148 · Existing Zvend account</small></div><div><span>ESTATE LOCATION</span><strong>Plot 18, Freedom Way, Lekki Phase 1</strong><small>Lekki, Lagos · Map pin not supplied</small></div><div><span>ESTATE STRUCTURE</span><strong>126 homes · 4 phases</strong><small>Residential gated community · estate type: Gated community</small></div><div><span>SUPPORTING DOCUMENTS</span><strong>3 files listed in this preview</strong><small>CAC certificate · Land title · Management authorization. Private files require the authorized document service.</small></div><div class="application-actions"><button class="table-action" data-action="request-info" data-id="e1">Request information</button><button class="table-action reject-action" data-action="reject-estate" data-id="e1">Reject</button><button class="table-action approve-action" data-action="approve-estate" data-id="e1">Approve estate</button></div></div></td></tr>
      <tr data-application-id="e2"><td><span class="estate-table-avatar estate-alt">O</span><span class="request-name"><strong>Oakview Residences</strong><small>Application · ZVE-1047</small></span></td><td>Chinedu Nwosu</td><td>Abuja, FCT</td><td>Mixed-use</td><td>Yesterday</td><td class="application-state"><span class="status-pill status-review"><i></i>Pending</span></td><td><button class="table-action approve-action" data-action="review-estate" data-id="e2">Review</button></td></tr>
      <tr class="application-details hidden" data-details-for="e2"><td colspan="7"><div class="application-detail-grid"><div><span>APPLICANT / OPERATOR</span><strong>Chinedu Nwosu · Developer</strong><small>Oakview Community Managers · Registration details pending</small></div><div><span>CONTACT</span><strong>chinedu.nwosu@example.com</strong><small>+234 809 222 1870 · Existing Zvend account</small></div><div><span>ESTATE LOCATION</span><strong>Airport Road, Central Area</strong><small>Abuja, FCT · Map pin provided in application</small></div><div><span>ESTATE STRUCTURE</span><strong>84 homes · 12 retail units</strong><small>Mixed-use development · 3 blocks</small></div><div><span>SUPPORTING DOCUMENTS</span><strong>2 files listed in this preview</strong><small>Development approval · Management authorization. Private files require the authorized document service.</small></div><div class="application-actions"><button class="table-action" data-action="request-info" data-id="e2">Request information</button><button class="table-action reject-action" data-action="reject-estate" data-id="e2">Reject</button><button class="table-action approve-action" data-action="approve-estate" data-id="e2">Approve estate</button></div></div></td></tr>
      <tr data-application-id="e3"><td><span class="estate-table-avatar estate-gold">H</span><span class="request-name"><strong>Harbour Point Estate</strong><small>Application · ZVE-1043</small></span></td><td>Bisola Adeyemi</td><td>Victoria Island, Lagos</td><td>Apartment</td><td>31 Oct 2026</td><td class="application-state"><span class="status-pill status-review"><i></i>Under review</span></td><td><button class="table-action approve-action" data-action="review-estate" data-id="e3">Review</button></td></tr>
      <tr class="application-details hidden" data-details-for="e3"><td colspan="7"><div class="application-detail-grid"><div><span>APPLICANT / OPERATOR</span><strong>Bisola Adeyemi · Management company</strong><small>Harbour Point Facilities Ltd. · RC 2047810</small></div><div><span>CONTACT</span><strong>bisola.adeyemi@example.com</strong><small>+234 809 124 0832 · Existing Zvend account</small></div><div><span>ESTATE LOCATION</span><strong>14 Ahmadu Bello Way, Victoria Island</strong><small>Victoria Island, Lagos · Map pin supplied</small></div><div><span>ESTATE STRUCTURE</span><strong>210 apartments · 2 towers</strong><small>Residential apartment community · 12 floors per tower</small></div><div><span>SUPPORTING DOCUMENTS</span><strong>4 files listed in this preview</strong><small>CAC certificate · Land documents · Management authorization · Development approval</small></div><div class="application-actions"><button class="table-action" data-action="request-info" data-id="e3">Request information</button><button class="table-action reject-action" data-action="reject-estate" data-id="e3">Reject</button><button class="table-action approve-action" data-action="approve-estate" data-id="e3">Approve estate</button></div></div></td></tr>
    </tbody></table></div><div class="module-table-foot"><span>Estate activation is recorded with reviewer, decision and timestamp.</span><button class="text-button" data-action="application-history">View decision history ↗</button></div></article>`
};

const overviewParts = [
  document.querySelector('.summary-grid'),
  document.querySelector('.content-grid'),
  document.querySelector('.bottom-grid')
];
const propertyRegister = document.getElementById('propertyRegister');
const placeholder = document.getElementById('sectionPlaceholder');
const moduleContent = document.getElementById('moduleContent');
const toast = document.getElementById('toast');
const decisionModal = document.getElementById('decisionModal');
const residentDecisionModal = document.getElementById('residentDecisionModal');
const staffInviteModal = document.getElementById('staffInviteModal');
const staffMembershipModal = document.getElementById('staffMembershipModal');
const staffRoleChangeModal = document.getElementById('staffRoleChangeModal');
const propertyDetailModal = document.getElementById('propertyDetailModal');
const structureNodeModal = document.getElementById('structureNodeModal');
const propertyCreateModal = document.getElementById('propertyCreateModal');
const ownershipModal = document.getElementById('ownershipModal');
const propertyArchiveModal = document.getElementById('propertyArchiveModal');
const maintenanceReviewModal = document.getElementById('maintenanceReviewModal');
const estateApprovalModal = document.getElementById('estateApprovalModal');
const announcementModal = document.getElementById('announcementModal');
const expenseModal = document.getElementById('expenseModal');
const expenseApprovalModal = document.getElementById('expenseApprovalModal');
let toastTimer;
let selectedApplication = null;
let selectedApprovalApplication = null;
let selectedDecision = null;
let selectedResidentDecisionId = null;
let selectedStaffMembershipRow = null;
let selectedExpenseRow = null;
let tenancyStatusFilter = 'all';
let tenancyQuery = '';
let expenseStatusFilter = 'all';
let expenseQuery = '';
let selectedPropertyForArchive = null;
let selectedPropertyForOwnership = null;
let selectedPropertyForOccupancy = null;
let occupancySequence = 1;
let structureNodeSequence = 20;
let propertyPreviewCount = 248;
let newPropertySequence = 1;
let structureNodes = [
  { id: 'north-gardens', name: 'North Gardens', type: 'zone', code: 'NG', parentId: null, linkedProperties: 96, status: 'active' },
  { id: 'oakwood-drive', name: 'Oakwood Drive', type: 'street', code: 'OD', parentId: 'north-gardens', linkedProperties: 24, status: 'active' },
  { id: 'oakwood-court', name: 'Oakwood Court', type: 'building', code: 'OC', parentId: 'north-gardens', linkedProperties: 72, status: 'active' },
  { id: 'oakwood-court-level-1', name: 'Level 1', type: 'floor', code: 'OC-L1', parentId: 'oakwood-court', linkedProperties: 18, status: 'active' },
  { id: 'maple-phase', name: 'Maple Phase', type: 'zone', code: 'MP', parentId: null, linkedProperties: 52, status: 'active' },
  { id: 'maple-street', name: 'Maple Street', type: 'street', code: 'MS', parentId: 'maple-phase', linkedProperties: 32, status: 'active' },
  { id: 'cedar-lane', name: 'Cedar Lane', type: 'zone', code: 'CL', parentId: null, linkedProperties: 100, status: 'active' }
];

function notify(message) {
  toast.textContent = message;
  toast.classList.add('show');
  window.clearTimeout(toastTimer);
  toastTimer = window.setTimeout(() => toast.classList.remove('show'), 2600);
}

function renderEstateStructure() {
  const body = document.getElementById('structureRows');
  if (!body) return;
  body.replaceChildren();
  structureNodes.forEach((node) => {
    const row = document.createElement('tr');
    const nameCell = document.createElement('td');
    const nameWrap = document.createElement('span');
    nameWrap.className = `structure-name structure-depth-${node.type}`;
    const glyph = document.createElement('i');
    glyph.className = 'structure-node-glyph';
    glyph.setAttribute('aria-hidden', 'true');
    const name = document.createElement('strong');
    name.textContent = node.name;
    const code = document.createElement('small');
    code.textContent = node.code || 'No code';
    nameWrap.append(glyph, name, code);
    nameCell.append(nameWrap);
    const typeCell = document.createElement('td');
    typeCell.textContent = ({ zone: 'Zone / phase', street: 'Street', building: 'Building', floor: 'Floor' })[node.type];
    const parentCell = document.createElement('td');
    parentCell.textContent = structureNodes.find((candidate) => candidate.id === node.parentId)?.name || 'Estate';
    const linkedCell = document.createElement('td');
    linkedCell.textContent = `${node.linkedProperties} ${node.type === 'floor' ? 'units' : 'properties'}`;
    const statusCell = document.createElement('td');
    const status = document.createElement('span');
    status.className = `structure-status ${node.status === 'active' ? '' : 'is-archived'}`;
    status.textContent = node.status === 'active' ? 'Active' : 'Archived';
    statusCell.append(status);
    const actionsCell = document.createElement('td');
    if (node.status === 'active') {
      const edit = document.createElement('button');
      edit.type = 'button';
      edit.className = 'table-action';
      edit.dataset.action = 'edit-structure-node';
      edit.dataset.nodeId = node.id;
      edit.textContent = 'Edit';
      const archive = document.createElement('button');
      archive.type = 'button';
      archive.className = 'table-action reject-action';
      archive.dataset.action = 'archive-structure-node';
      archive.dataset.nodeId = node.id;
      archive.textContent = 'Archive';
      actionsCell.append(edit, archive);
    }
    row.append(nameCell, typeCell, parentCell, linkedCell, statusCell, actionsCell);
    body.append(row);
  });
  document.getElementById('structureNodeCount').textContent = String(structureNodes.filter((node) => node.status === 'active').length);
  const tabCount = document.querySelector('[data-register-tab="structure"] span');
  if (tabCount) tabCount.textContent = `${structureNodes.filter((node) => node.status === 'active').length} nodes`;
}

function selectPropertyRegisterTab(tab) {
  const isStructure = tab === 'structure';
  document.getElementById('propertyAssetsPanel').classList.toggle('hidden', isStructure);
  document.getElementById('estateStructurePanel').classList.toggle('hidden', !isStructure);
  document.getElementById('propertyAssetsPanel').setAttribute('aria-hidden', String(isStructure));
  document.getElementById('estateStructurePanel').setAttribute('aria-hidden', String(!isStructure));
  document.querySelectorAll('[data-register-tab]').forEach((button) => {
    const selected = button.dataset.registerTab === tab;
    button.classList.toggle('selected', selected);
    button.setAttribute('aria-selected', String(selected));
  });
  if (isStructure) {
    if (typeof window.refreshEstateStructure !== 'function') renderEstateStructure();
  }
  window.dispatchEvent(new CustomEvent('estate:property-tab-changed', { detail: { tab } }));
}

function openStructureNodeForm() {
  document.getElementById('structureNodeForm').reset();
  document.getElementById('structureNodeError').textContent = '';
  const parent = document.getElementById('structureNodeParent');
  parent.replaceChildren(new Option('No parent', ''));
  structureNodes.filter((node) => node.status === 'active').forEach((node) => parent.add(new Option(`${node.name} · ${node.type}`, node.id)));
  structureNodeModal.classList.remove('hidden');
  document.getElementById('structureNodeName').focus();
}

function closeStructureNodeForm() {
  structureNodeModal.classList.add('hidden');
}

function saveStructureNodePreview(event) {
  event.preventDefault();
  const name = document.getElementById('structureNodeName').value.trim();
  const code = document.getElementById('structureNodeCode').value.trim();
  const type = document.getElementById('structureNodeType').value;
  const parentId = document.getElementById('structureNodeParent').value || null;
  const error = document.getElementById('structureNodeError');
  if (!name) { error.textContent = 'Enter a name for this structure node.'; return; }
  if (code && structureNodes.some((node) => node.type === type && node.code?.toLowerCase() === code.toLowerCase() && node.status === 'active')) {
    error.textContent = 'An active node of this type already uses that code.';
    return;
  }
  structureNodes.push({ id: `structure-${structureNodeSequence++}`, name, type, code: code || null, parentId, linkedProperties: 0, status: 'active' });
  closeStructureNodeForm();
  renderEstateStructure();
  notify('Structure node added to this page preview only. Estate policy and audit checks require the connected service.');
}

function editStructureNodePreview(nodeId) {
  const node = structureNodes.find((item) => item.id === nodeId);
  if (!node || node.status !== 'active') return;
  const updatedName = window.prompt('Update structure name', node.name);
  if (updatedName === null) return;
  if (!updatedName.trim()) { notify('Structure name cannot be empty.'); return; }
  node.name = updatedName.trim();
  renderEstateStructure();
  notify('Structure edit shown in this page preview only.');
}

function archiveStructureNodePreview(nodeId) {
  const node = structureNodes.find((item) => item.id === nodeId);
  if (!node || node.status !== 'active') return;
  if (node.linkedProperties > 0 || structureNodes.some((item) => item.status === 'active' && item.parentId === nodeId)) {
    notify('Move or archive child nodes and linked properties before archiving this structure node.');
    return;
  }
  if (!window.confirm(`Archive ${node.name}? Its history will be retained.`)) return;
  node.status = 'archived';
  renderEstateStructure();
  notify('Structure node archived in this page preview only.');
}

function openPropertyCreateForm() {
  document.getElementById('propertyCreateForm').reset();
  document.getElementById('propertyCreateError').textContent = '';
  const parent = document.getElementById('propertyParentInput');
  parent.replaceChildren(new Option('No hierarchy link', ''));
  structureNodes.filter((node) => node.status === 'active').forEach((node) => parent.add(new Option(`${node.name} · ${node.type}`, node.id)));
  propertyCreateModal.classList.remove('hidden');
  document.getElementById('propertyNameInput').focus();
}

function closePropertyCreateForm() {
  propertyCreateModal.classList.add('hidden');
}

function savePropertyPreview(event) {
  event.preventDefault();
  const name = document.getElementById('propertyNameInput').value.trim();
  const code = document.getElementById('propertyCodeInput').value.trim();
  const unitNumber = document.getElementById('propertyUnitInput').value.trim();
  const type = document.getElementById('propertyTypeInput').value;
  const status = document.getElementById('propertyStatusInput').value;
  const parentId = document.getElementById('propertyParentInput').value || null;
  const address = document.getElementById('propertyAddressInput').value.trim();
  const description = document.getElementById('propertyDescriptionInput').value.trim();
  const latitudeValue = document.getElementById('propertyLatitudeInput').value.trim();
  const longitudeValue = document.getElementById('propertyLongitudeInput').value.trim();
  const error = document.getElementById('propertyCreateError');
  if (!name || !code) { error.textContent = 'Enter a property name and estate-unique code.'; return; }
  if (Object.values(propertyDetailRecords).some((record) => record.code.toLowerCase() === code.toLowerCase())) {
    error.textContent = 'That code already appears in the property register.';
    return;
  }
  if (Boolean(latitudeValue) !== Boolean(longitudeValue)) { error.textContent = 'Provide both map coordinates, or leave both blank.'; return; }
  const latitude = latitudeValue ? Number(latitudeValue) : null;
  const longitude = longitudeValue ? Number(longitudeValue) : null;
  if (latitudeValue && (!Number.isFinite(latitude) || latitude < -90 || latitude > 90
    || !Number.isFinite(longitude) || longitude < -180 || longitude > 180)) {
    error.textContent = 'Enter valid latitude (−90 to 90) and longitude (−180 to 180).';
    return;
  }
  const parentNode = structureNodes.find((node) => node.id === parentId && node.status === 'active');
  if (parentId && !parentNode) { error.textContent = 'Choose an active structure node from this estate.'; return; }
  const propertyId = `new-property-${newPropertySequence++}`;
  const statusLabel = ({ active: 'Operational', under_development: 'Under development', reserved: 'Reserved', under_maintenance: 'Under maintenance', inactive: 'Inactive' })[status];
  const zone = parentNode?.name || 'Estate grounds';
  propertyDetailRecords[propertyId] = {
    name, code, unitNumber: unitNumber || null, address: address || zone, type, zone, status: statusLabel, occupancy: 'Vacant',
    coordinates: latitude === null ? 'Not recorded' : `${latitude}, ${longitude}`,
    owners: [], occupants: [], history: [{ date: 'Just now', title: 'Property created', detail: 'Local preview only' }],
    description,
    documents: description ? `Property note: ${description}` : 'Property documents and charges will appear through authorized estate services.'
  };
  const row = document.createElement('tr');
  row.dataset.propertyId = propertyId;
  row.dataset.search = `${name} ${code} ${type} ${zone}`.toLowerCase();
  const propertyCell = document.createElement('td');
  const thumb = document.createElement('span');
  thumb.className = 'property-thumb thumb-new';
  thumb.textContent = 'NEW';
  const nameWrap = document.createElement('span');
  nameWrap.className = 'request-name';
  const label = document.createElement('strong'); label.textContent = name;
  const addressLabel = document.createElement('small'); addressLabel.textContent = address || zone;
  nameWrap.append(label, addressLabel); propertyCell.append(thumb, nameWrap);
  const typeCell = document.createElement('td'); typeCell.textContent = type;
  const ownerCell = document.createElement('td'); ownerCell.textContent = '—';
  const occupancyCell = document.createElement('td'); occupancyCell.textContent = 'Vacant';
  const statusCell = document.createElement('td');
  const statusPill = document.createElement('span'); statusPill.className = `status-pill ${status === 'active' ? 'status-active' : status === 'under_maintenance' ? 'status-maint' : status === 'inactive' ? 'status-vacant' : status === 'reserved' ? 'status-review' : 'status-assigned'}`;
  const indicator = document.createElement('i'); statusPill.append(indicator, document.createTextNode(statusLabel)); statusCell.append(statusPill);
  const actionCell = document.createElement('td');
  const detail = document.createElement('button'); detail.type = 'button'; detail.className = 'table-action property-detail-action'; detail.dataset.action = 'property-detail'; detail.dataset.propertyId = propertyId; detail.textContent = 'Details'; actionCell.append(detail);
  row.append(propertyCell, typeCell, ownerCell, occupancyCell, statusCell, actionCell);
  document.getElementById('propertyRows').prepend(row);
  propertyPreviewCount += 1;
  document.getElementById('resultsCount').textContent = `Showing ${document.querySelectorAll('#propertyRows tr:not(.hidden)').length} of ${propertyPreviewCount} properties`;
  document.querySelector('[data-register-tab="properties"] span').textContent = String(propertyPreviewCount);
  document.querySelector('[data-view="properties"] .nav-count').textContent = String(propertyPreviewCount);
  const propertySummary = document.querySelector('#estateStructurePanel .structure-summary article:nth-child(2) strong');
  if (propertySummary) propertySummary.textContent = String(propertyPreviewCount);
  closePropertyCreateForm();
  notify('Property added to this page preview only. A connected service must verify estate scope, code uniqueness and audit history.');
}

const residentRequestNotes = {
  r1: { note: 'I recently moved into Oakwood 14 and would like resident access for my household.', proof: 'Tenancy agreement reference listed · open only through the authorized private document service.' },
  r2: { note: 'I live at Block B 03 with the primary resident and need household access.', proof: 'No supporting document reference in this sample request.' },
  r3: { note: 'I own Maple Street 11 and am requesting an owner relationship with the estate.', proof: 'Ownership evidence reference listed · review through the authorized private document service.' }
};

function openResidentDecision(requestId) {
  const row = document.querySelector(`[data-resident-id="${requestId}"]`);
  if (!row || row.dataset.residentRow !== 'pending') return;
  selectedResidentDecisionId = requestId;
  const applicant = row.children[0];
  document.getElementById('residentApplicantName').textContent = applicant.querySelector('strong')?.textContent || 'Applicant';
  document.getElementById('residentApplicantEmail').textContent = applicant.querySelector('small')?.textContent || 'Contact details unavailable';
  document.getElementById('residentRequestedProperty').textContent = row.children[1].textContent.trim();
  document.getElementById('residentRequestedRelationship').textContent = row.children[2].textContent.trim();
  document.getElementById('residentSubmittedAt').textContent = row.children[3].textContent.trim();
  const requestNote = residentRequestNotes[requestId] || { note: 'No applicant note supplied.', proof: 'No supporting document reference in this sample request.' };
  document.getElementById('residentApplicantNote').textContent = requestNote.note;
  document.getElementById('residentProofSummary').textContent = requestNote.proof;
  document.getElementById('residentDecisionReason').value = '';
  document.getElementById('residentDecisionError').textContent = '';
  document.getElementById('residentReasonField').classList.add('hidden');
  residentDecisionModal.classList.remove('hidden');
}

function closeResidentDecision() {
  residentDecisionModal.classList.add('hidden');
  selectedResidentDecisionId = null;
}

function renderResidentRows() {
  if (document.getElementById('residentRows')?.dataset.live === 'true') return;
  const rows = [...document.querySelectorAll('#residentRows [data-resident-row]')];
  const activeFilter = document.querySelector('[data-resident-filter].selected')?.dataset.residentFilter || 'pending';
  const search = document.getElementById('residentSearch')?.value.trim().toLowerCase() || '';
  let visible = 0;
  rows.forEach((row) => {
    const matchesFilter = activeFilter === 'all'
      || (activeFilter === 'active' ? row.dataset.residentRow === 'active' : row.dataset.residentRow === 'pending');
    const matchesSearch = !search || row.textContent.toLowerCase().includes(search);
    const show = matchesFilter && matchesSearch;
    row.classList.toggle('hidden', !show);
    if (show) visible += 1;
  });
  document.getElementById('residentRows')?.querySelector('#residentEmptyRow')?.remove();
  if (!visible) {
    const empty = document.createElement('tr');
    empty.id = 'residentEmptyRow';
    const cell = document.createElement('td');
    cell.colSpan = 6;
    cell.className = 'resident-empty-cell';
    cell.textContent = 'No records match this view. Try a different filter or search.';
    empty.append(cell);
    document.getElementById('residentRows')?.append(empty);
  }
  const label = activeFilter === 'pending' ? 'pending request' : activeFilter === 'active' ? 'active resident' : 'record';
  document.getElementById('residentResults').textContent = `Showing ${visible} ${label}${visible === 1 ? '' : 's'}`;
}

function renderTeamRows() {
  const rows = [...document.querySelectorAll('#teamRows tr')].filter((row) => row.dataset.staffStatus || row.querySelector('.status-pill'));
  const filter = document.querySelector('[data-team-filter].selected')?.dataset.teamFilter || 'all';
  const search = document.getElementById('teamSearch')?.value.trim().toLowerCase() || '';
  let visible = 0;
  rows.forEach((row) => {
    const statusText = row.querySelector('.status-pill')?.textContent.toLowerCase() || '';
    const state = row.dataset.staffStatus || (statusText.includes('active') ? 'active' : 'pending');
    const matchesFilter = filter === 'all' || (filter === 'active' ? state === 'active' : state === 'pending');
    const show = matchesFilter && (!search || row.textContent.toLowerCase().includes(search));
    row.classList.toggle('hidden', !show);
    if (show) visible += 1;
  });
  document.getElementById('teamRows')?.querySelector('#teamEmptyRow')?.remove();
  if (!visible) {
    const empty = document.createElement('tr');
    empty.id = 'teamEmptyRow';
    const cell = document.createElement('td');
    cell.colSpan = 6;
    cell.className = 'resident-empty-cell';
    cell.textContent = 'No team records match this view. Try a different filter or search.';
    empty.append(cell);
    document.getElementById('teamRows')?.append(empty);
  }
}

const staffRoleScopes = Object.freeze({
  general_manager: ['General manager', 'Estate operations · grants confirmed by estate policy'],
  estate_accountant: ['Estate accountant', 'Billing, invoices and authorized reconciliation'],
  estate_secretary: ['Estate secretary', 'Resident records and estate communications'],
  security_supervisor: ['Security supervisor', 'Assigned gates, access events and incidents'],
  security_personnel: ['Security personnel', 'Assigned gate only'],
  facility_manager: ['Facility manager', 'Facilities and booking review'],
  maintenance_officer: ['Maintenance officer', 'Assigned work requests'],
});

function updateStaffInviteScope() {
  const role = document.getElementById('staffInviteRole').value;
  document.getElementById('staffInviteScope').textContent = staffRoleScopes[role]?.[1] || 'Choose a role to preview its scope';
}

function openStaffInvite() {
  document.getElementById('staffInviteEmail').value = '';
  document.getElementById('staffInviteRole').value = '';
  document.getElementById('staffInviteError').textContent = '';
  updateStaffInviteScope();
  staffInviteModal.classList.remove('hidden');
  document.getElementById('staffInviteEmail').focus();
}

function closeStaffInvite() {
  staffInviteModal.classList.add('hidden');
}

function submitStaffInvitePreview() {
  const emailInput = document.getElementById('staffInviteEmail');
  const roleInput = document.getElementById('staffInviteRole');
  const error = document.getElementById('staffInviteError');
  const email = emailInput.value.trim().toLowerCase();
  const role = staffRoleScopes[roleInput.value];
  if (!emailInput.checkValidity() || !email) {
    error.textContent = 'Enter a valid email for an existing Zvend account.';
    emailInput.focus();
    return;
  }
  if (!role) {
    error.textContent = 'Choose an estate role to continue.';
    roleInput.focus();
    return;
  }
  const duplicate = [...document.querySelectorAll('#teamRows tr')]
    .some((row) => (row.dataset.email || row.querySelector('.request-name small')?.textContent.trim().split(/\s·\s/)[0].toLowerCase()) === email);
  if (duplicate) {
    error.textContent = 'This account already appears in the estate team or invitation list.';
    emailInput.focus();
    return;
  }

  const row = document.createElement('tr');
  row.dataset.staffStatus = 'pending';
  row.dataset.email = email;
  const personCell = document.createElement('td');
  const avatar = document.createElement('span');
  avatar.className = 'person-avatar person-a';
  avatar.textContent = email.slice(0, 2).toUpperCase();
  const person = document.createElement('span');
  person.className = 'request-name';
  const name = document.createElement('strong');
  name.textContent = email;
  const emailLabel = document.createElement('small');
  emailLabel.textContent = 'Existing Zvend account';
  person.append(name, emailLabel);
  personCell.append(avatar, person);
  const roleCell = document.createElement('td');
  roleCell.textContent = role[0];
  const scopeCell = document.createElement('td');
  scopeCell.textContent = role[1];
  const statusCell = document.createElement('td');
  const status = document.createElement('span');
  status.className = 'status-pill status-review';
  const dot = document.createElement('i');
  status.append(dot, document.createTextNode('Invitation preview'));
  statusCell.append(status);
  const activityCell = document.createElement('td');
  activityCell.textContent = 'Not accepted';
  const actionCell = document.createElement('td');
  const details = document.createElement('button');
  details.type = 'button';
  details.className = 'row-more';
  details.dataset.action = 'member-details';
  details.setAttribute('aria-label', 'Invitation details');
  details.textContent = '···';
  actionCell.append(details);
  row.append(personCell, roleCell, scopeCell, statusCell, activityCell, actionCell);
  document.getElementById('teamRows').prepend(row);
  const pendingCount = document.getElementById('pendingStaffInvitations');
  pendingCount.textContent = String(Number(pendingCount.textContent) + 1);
  const invitationFilterCount = document.getElementById('teamInvitationFilterCount');
  if (invitationFilterCount) invitationFilterCount.textContent = String(Number(invitationFilterCount.textContent) + 1);
  renderTeamRows();
  closeStaffInvite();
  notify('Invitation preview added. No message or access grant was sent.');
}

function openStaffMembershipModal(actionControl) {
  const row = actionControl.closest('#teamRows tr');
  if (!row) return false;
  const status = row.querySelector('.status-pill')?.textContent.trim() || '';
  if (/revoked/i.test(status)) {
    notify('This membership is revoked in the preview and cannot be changed here.');
    return true;
  }
  if (!/active|suspended/i.test(status)) {
    notify('Invitation details and acceptance are handled through the invitee’s Zvend account.');
    return true;
  }
  selectedStaffMembershipRow = row;
  const name = row.querySelector('.request-name strong')?.textContent.trim() || 'Team member';
  const email = row.querySelector('.request-name small')?.textContent.trim() || '';
  document.getElementById('staffMembershipName').textContent = name;
  document.getElementById('staffMembershipEmail').textContent = email;
  document.getElementById('staffMembershipRole').textContent = row.children[1].textContent.trim();
  document.getElementById('staffMembershipScope').textContent = row.children[2].textContent.trim();
  document.getElementById('staffMembershipStatus').textContent = status;
  document.getElementById('staffMembershipReason').value = '';
  const warning = document.getElementById('staffMembershipWarning');
  const currentUser = document.querySelector('.profile-meta strong')?.textContent.trim();
  const isSelf = Boolean(currentUser && currentUser === name);
  document.querySelector('[data-action="open-staff-role-change"]').disabled = isSelf || /suspended/i.test(status);
  warning.textContent = isSelf ? 'You cannot suspend or revoke your own access from this screen.' : '';
  document.querySelector('[data-action="suspend-staff-membership"]').classList.toggle('hidden', /suspended/i.test(status));
  document.querySelectorAll('[data-action="suspend-staff-membership"], [data-action="revoke-staff-membership"]')
    .forEach((button) => { button.disabled = isSelf; });
  staffMembershipModal.classList.remove('hidden');
  document.getElementById('staffMembershipReason').focus();
  return true;
}

function closeStaffMembershipModal() {
  staffMembershipModal.classList.add('hidden');
  selectedStaffMembershipRow = null;
}

const staffRoleScopePreview = Object.freeze({
  general_manager: 'Estate operations and delegated staff access',
  estate_accountant: 'Estate billing, payments and authorized finance',
  estate_secretary: 'Resident records and estate administration',
  security_supervisor: 'Assigned gates, staff and incident oversight',
  security_personnel: 'Assigned gates and incidents',
  facility_manager: 'Facilities, bookings and assigned work',
  maintenance_officer: 'Assigned maintenance work requests',
});

function closeStaffRoleChange() {
  staffRoleChangeModal.classList.add('hidden');
}

function openStaffRoleChange() {
  if (!selectedStaffMembershipRow) return;
  const currentUser = document.querySelector('.profile-meta strong')?.textContent.trim();
  const memberName = selectedStaffMembershipRow.querySelector('.request-name strong')?.textContent.trim() || '';
  if (currentUser && currentUser === memberName) {
    document.getElementById('staffMembershipWarning').textContent = 'You cannot change your own effective role.';
    return;
  }
  document.getElementById('staffRoleChangeMember').textContent = memberName;
  document.getElementById('staffRoleChangeSelect').value = '';
  document.getElementById('staffRoleChangeScope').textContent = 'Choose a role to preview its estate scope';
  document.getElementById('staffRoleChangeReason').value = '';
  document.getElementById('staffRoleChangeWarning').textContent = '';
  staffRoleChangeModal.classList.remove('hidden');
  document.getElementById('staffRoleChangeSelect').focus();
}

function submitStaffRoleChangePreview() {
  const row = selectedStaffMembershipRow;
  const roleSelect = document.getElementById('staffRoleChangeSelect');
  const role = roleSelect.value;
  const reason = document.getElementById('staffRoleChangeReason').value.trim();
  const warning = document.getElementById('staffRoleChangeWarning');
  if (!row) return closeStaffRoleChange();
  if (!role || !staffRoleScopePreview[role]) {
    warning.textContent = 'Choose an available estate role.';
    roleSelect.focus();
    return;
  }
  if (!reason || reason.length > 500) {
    warning.textContent = 'Provide a reason of up to 500 characters.';
    document.getElementById('staffRoleChangeReason').focus();
    return;
  }
  const label = roleSelect.selectedOptions[0].textContent;
  row.children[1].textContent = label;
  row.children[2].textContent = staffRoleScopePreview[role];
  closeStaffRoleChange();
  closeStaffMembershipModal();
  renderTeamRows();
  notify('Role change shown in this preview only. No grant, membership or audit record was changed.');
}

function applyStaffMembershipPreview(action) {
  const row = selectedStaffMembershipRow;
  if (!row) return closeStaffMembershipModal();
  const reason = document.getElementById('staffMembershipReason').value.trim();
  if (!reason || reason.length > 500) {
    document.getElementById('staffMembershipWarning').textContent = 'Provide a reason of up to 500 characters.';
    document.getElementById('staffMembershipReason').focus();
    return;
  }
  const previousStatus = row.dataset.staffStatus || 'active';
  const nextStatus = action === 'suspend' ? 'suspended' : 'revoked';
  const statusPill = row.querySelector('.status-pill');
  row.dataset.staffStatus = nextStatus;
  statusPill.className = `status-pill ${nextStatus === 'suspended' ? 'status-review' : 'status-overdue'}`;
  const dot = document.createElement('i');
  statusPill.replaceChildren(dot, document.createTextNode(nextStatus === 'suspended' ? 'Suspended in preview' : 'Revoked in preview'));
  if (previousStatus === 'active') {
    const activeStaff = document.querySelector('#moduleContent .module-stats article strong');
    if (activeStaff) activeStaff.textContent = String(Math.max(0, Number(activeStaff.textContent.replace(/,/g, '')) - 1));
  }
  closeStaffMembershipModal();
  renderTeamRows();
  notify(`${nextStatus === 'suspended' ? 'Suspension' : 'Revocation'} shown in this preview only. No access grant or audit record was changed.`);
}

function decideResidentPreview(decision) {
  const row = document.querySelector(`[data-resident-id="${selectedResidentDecisionId}"]`);
  if (!row || row.dataset.residentRow !== 'pending') { closeResidentDecision(); return; }
  const reason = document.getElementById('residentDecisionReason').value.trim();
  if (decision === 'reject' && !reason) {
    document.getElementById('residentReasonField').classList.remove('hidden');
    document.getElementById('residentDecisionError').textContent = 'Provide a reason before rejecting this request.';
    document.getElementById('residentDecisionReason').focus();
    return;
  }
  const approved = decision === 'approve';
  row.dataset.residentRow = approved ? 'active' : 'rejected';
  row.dataset.decisionReason = approved ? '' : reason;
  const pill = document.createElement('span');
  pill.className = `status-pill ${approved ? 'status-active' : 'status-overdue'}`;
  const dot = document.createElement('i');
  pill.append(dot, document.createTextNode(approved ? 'Approved in preview' : 'Rejected in preview'));
  row.querySelector('.resident-state').replaceChildren(pill);
  const outcome = document.createElement('span');
  outcome.className = 'local-change';
  outcome.textContent = approved ? 'Membership previewed' : 'Reason recorded locally';
  row.querySelector('.row-actions').replaceChildren(outcome);
  const pendingCount = document.querySelectorAll('[data-resident-row="pending"]').length;
  const pendingFilter = document.getElementById('residentPendingFilterCount');
  if (pendingFilter) pendingFilter.textContent = String(pendingCount);
  const stats = document.querySelectorAll('#moduleContent .module-stats article');
  if (stats[0]) stats[0].querySelector('strong').textContent = String(Number(stats[0].querySelector('strong').textContent.replace(/,/g, '')) + (approved ? 1 : 0));
  if (stats[1]) {
    stats[1].querySelector('strong').textContent = String(pendingCount);
    stats[1].querySelector('small').textContent = pendingCount ? 'Requests awaiting estate review' : 'All sample requests reviewed';
  }
  renderResidentRows();
  closeResidentDecision();
  notify(approved
    ? 'Membership approval shown in this page preview. Property occupancy is a separate linked effect when requested.'
    : 'Request rejection and reason shown in this page preview. No notification or audit event was written.');
}

function openDecision(action, applicationId) {
  selectedDecision = action;
  selectedApplication = applicationId;
  const isReject = action === 'reject-estate';
  document.getElementById('decisionTitle').textContent = isReject ? 'Reject application' : 'Request more information';
  document.getElementById('decisionDescription').textContent = isReject
    ? 'Explain why this application cannot be approved. The reason will be included in the decision record.'
    : 'Tell the applicant what needs to be corrected or provided before review can continue.';
  document.getElementById('submitDecision').textContent = isReject ? 'Record rejection' : 'Send request';
  document.getElementById('decisionReason').value = '';
  decisionModal.classList.remove('hidden');
  document.getElementById('decisionReason').focus();
}

function closeDecision() {
  decisionModal.classList.add('hidden');
  selectedDecision = null;
  selectedApplication = null;
}

function openEstateApproval(applicationId) {
  const application = document.querySelector(`[data-application-id="${applicationId}"]`);
  const applicantName = application.children[1].textContent.trim();
  const administratorSelect = document.getElementById('initialAdminUser');
  administratorSelect.replaceChildren(
    new Option('Choose an existing Zvend account', ''),
    new Option(`${applicantName} · applicant account example`, 'sample-applicant'),
    new Option('Fatima Kalu · platform account example', 'sample-account')
  );
  document.getElementById('approvalEstateName').textContent = application.querySelector('.request-name strong').textContent;
  administratorSelect.value = '';
  selectedApprovalApplication = applicationId;
  estateApprovalModal.classList.remove('hidden');
  administratorSelect.focus();
}

function closeEstateApproval() {
  estateApprovalModal.classList.add('hidden');
  selectedApprovalApplication = null;
}

function confirmEstateApproval() {
  const administratorSelect = document.getElementById('initialAdminUser');
  if (!selectedApprovalApplication || !administratorSelect.value) {
    administratorSelect.focus();
    notify('Choose the initial Estate Administrator before approval.');
    return;
  }
  const application = document.querySelector(`[data-application-id="${selectedApprovalApplication}"]`);
  const details = document.querySelector(`[data-details-for="${selectedApprovalApplication}"]`);
  const administratorName = administratorSelect.selectedOptions[0].textContent.split(' · ')[0];
  application.querySelector('.application-state').innerHTML = '<span class="status-pill status-active"><i></i>Approved</span>';
  const reviewButton = application.querySelector('[data-action="review-estate"]');
  reviewButton.textContent = 'Approved';
  reviewButton.disabled = true;
  details.querySelector('.application-actions').innerHTML = `<span class="local-change">Approved in preview · Initial administrator: ${escapeHtml(administratorName)}. Estate activation and membership would be committed together.</span>`;
  closeEstateApproval();
  notify('Approval and first administrator assignment shown in preview only.');
}

function openAnnouncementComposer() {
  document.getElementById('announcementTitle').value = '';
  document.getElementById('announcementMessage').value = '';
  document.getElementById('announcementSchedule').value = '';
  document.getElementById('announcementAudience').value = 'All residents';
  document.getElementById('announcementEmergency').checked = false;
  document.querySelectorAll('.channel-fieldset input[type="checkbox"]').forEach((input, index) => {
    input.checked = index === 0;
  });
  announcementModal.classList.remove('hidden');
  document.getElementById('announcementTitle').focus();
}

function closeAnnouncementComposer() {
  announcementModal.classList.add('hidden');
}

function saveAnnouncement(mode) {
  const title = document.getElementById('announcementTitle').value.trim();
  const message = document.getElementById('announcementMessage').value.trim();
  const audience = document.getElementById('announcementAudience').value;
  const schedule = document.getElementById('announcementSchedule').value;
  const emergency = document.getElementById('announcementEmergency').checked;
  const channels = [...document.querySelectorAll('.channel-fieldset input[type="checkbox"]:checked')]
    .map((input) => input.value);
  if (!title || !message) {
    notify('Add a title and message before saving the announcement.');
    return;
  }
  if (mode === 'publish' && channels.length === 0) {
    notify('Select at least one delivery channel.');
    return;
  }
  if (mode === 'publish' && schedule && new Date(schedule).getTime() <= Date.now()) {
    notify('Choose a future time or clear the schedule to publish now.');
    return;
  }
  const status = mode === 'draft' ? 'Draft' : schedule ? 'Scheduled' : 'Published';
  const statusClass = status === 'Published' ? 'status-active' : status === 'Scheduled' ? 'status-review' : 'status-draft';
  const dateLabel = mode === 'draft' ? 'Not published' : schedule ? schedule.replace('T', ' · ') : 'Just now';
  const iconClass = emergency ? 'announcement-row-icon emergency-row' : 'announcement-row-icon';
  const safeTitle = escapeHtml(title);
  const channelsHtml = channels.map((channel) => `<span class="channel-badge">${escapeHtml(channel.toUpperCase())}</span>`).join(' ');
  document.getElementById('announcementRows').insertAdjacentHTML('afterbegin', `
    <tr data-announcement-status="${status.toLowerCase()}">
      <td><span class="${iconClass}"><svg viewBox="0 0 24 24"><path d="M4 11v2a2 2 0 0 0 2 2h2l9 5V4l-9 5H6a2 2 0 0 0-2 2Z"/></svg></span><span class="request-name"><strong>${safeTitle}</strong><small>${emergency ? 'Emergency alert' : 'Community update'} · Posted by Amara</small></span></td>
      <td>${escapeHtml(audience)}</td><td>${channelsHtml || '<span class="muted-value">—</span>'}</td><td>${escapeHtml(dateLabel)}</td><td><span class="muted-value">—</span></td><td><span class="status-pill ${statusClass}"><i></i>${status}</span></td><td><button class="row-more" data-action="announcement-detail" aria-label="Announcement details">···</button></td>
    </tr>`);
  closeAnnouncementComposer();
  notify(`${status} added to local preview. Delivery will use the Zvend notification service when integrated.`);
}

function openExpenseComposer() {
  ['expenseTitle', 'expenseAmount', 'expensePayee', 'expenseDate', 'expenseNote'].forEach((id) => {
    document.getElementById(id).value = '';
  });
  document.getElementById('expenseCategory').value = 'Maintenance';
  expenseModal.classList.remove('hidden');
  document.getElementById('expenseTitle').focus();
}

function closeExpenseComposer() {
  expenseModal.classList.add('hidden');
}

function submitExpenseRequest() {
  const title = document.getElementById('expenseTitle').value.trim();
  const category = document.getElementById('expenseCategory').value;
  const amountValue = document.getElementById('expenseAmount').value;
  const payee = document.getElementById('expensePayee').value.trim();
  const date = document.getElementById('expenseDate').value;
  if (!title || !payee || !amountValue || Number(amountValue) <= 0) {
    notify('Add a description, payee and positive amount before submitting.');
    return;
  }
  const amount = new Intl.NumberFormat('en-NG', { maximumFractionDigits: 2 }).format(Number(amountValue));
  const row = document.createElement('tr');
  row.dataset.expenseStatus = 'pending';
  row.dataset.search = `${title} ${payee} ${category}`.toLowerCase();
  row.innerHTML = `<td><span class="expense-type-icon"><svg viewBox="0 0 24 24"><path d="M4 19h16M6 19V8l6-4 6 4v11M9 19v-6h6v6"/></svg></span><span class="request-name"><strong>${escapeHtml(title)}</strong><small>New request · Submitted just now</small></span></td><td>${escapeHtml(category)}</td><td>Amara Okafor</td><td>${escapeHtml(payee)}</td><td class="amount-cell">₦${amount}</td><td>${escapeHtml(date || 'Today')}</td><td class="expense-state"><button class="table-action approve-action" data-action="approve-expense">Review</button></td>`;
  document.getElementById('expenseRows').prepend(row);
  closeExpenseComposer();
  notify('Expense request added to local preview. No payment or approval was recorded.');
}

function openExpenseApproval(button) {
  selectedExpenseRow = button.closest('tr');
  document.getElementById('approvalExpenseName').textContent = selectedExpenseRow.querySelector('.request-name strong').textContent;
  document.getElementById('approvalExpensePayee').textContent = selectedExpenseRow.children[3].textContent;
  document.getElementById('approvalExpenseAmount').textContent = selectedExpenseRow.querySelector('.amount-cell').textContent;
  document.getElementById('expenseApprovalNote').value = '';
  expenseApprovalModal.classList.remove('hidden');
}

function closeExpenseApproval() {
  expenseApprovalModal.classList.add('hidden');
  selectedExpenseRow = null;
}

function confirmExpenseApproval() {
  if (!selectedExpenseRow) return;
  selectedExpenseRow.dataset.expenseStatus = 'approved';
  const note = document.getElementById('expenseApprovalNote').value.trim();
  selectedExpenseRow.querySelector('.expense-state').innerHTML = `<span class="status-pill status-active"><i></i>Approved</span><small class="local-approval-note">${note ? `Note: ${escapeHtml(note)}` : 'Approved in preview'}</small>`;
  filterExpenses();
  closeExpenseApproval();
  notify('Approval shown in preview. The real service must enforce limits and audit the decision.');
}

async function saveDecision() {
  const reason = document.getElementById('decisionReason').value.trim();
  if (!reason) {
    document.getElementById('decisionReason').focus();
    notify('Add a reason before recording this decision.');
    return;
  }
  const liveApplication = [...document.querySelectorAll('#moduleContent [data-application-id]')]
    .find((row) => row.dataset.applicationId === String(selectedApplication) && row.dataset.liveApplication === 'true');
  if (liveApplication) {
    const config = window.ZvendEstateConfig || {};
    const apiBase = typeof config.apiBaseUrl === 'string' ? config.apiBaseUrl.replace(/\/$/, '') : '';
    const queueUrl = typeof config.applicationQueueUrl === 'string'
      ? config.applicationQueueUrl.replace(/\/$/, '')
      : apiBase ? `${apiBase}/api/estate/platform/applications` : '';
    if (!queueUrl) {
      notify('The live application service is not configured.');
      return;
    }
    const decisionAction = selectedDecision === 'reject-estate' ? 'reject' : 'request-information';
    const requestBody = decisionAction === 'reject' ? { reason } : { message: reason };
    const submitButton = document.getElementById('submitDecision');
    submitButton.disabled = true;
    try {
      const response = await fetch(`${queueUrl}/${encodeURIComponent(selectedApplication)}/${decisionAction}`, {
        method: 'POST',
        credentials: 'same-origin',
        headers: { Accept: 'application/json', 'Content-Type': 'application/json' },
        body: JSON.stringify(requestBody),
      });
      if (!response.ok) {
        const message = response.status === 401 ? 'Sign in to record this decision.'
          : response.status === 403 ? 'You are not authorized to decide on this application.'
            : response.status === 409 ? 'This application has changed. Refresh the queue and review it again.'
              : `The decision could not be saved (${response.status}).`;
        throw new Error(message);
      }
      closeDecision();
      notify(`${decisionAction === 'reject' ? 'Rejection' : 'Information request'} recorded.`);
      if (typeof window.refreshEstateApplicationQueue === 'function') await window.refreshEstateApplicationQueue();
    } catch (error) {
      notify(error.message || 'The decision could not be saved.');
    } finally {
      submitButton.disabled = false;
    }
    return;
  }
  const application = document.querySelector(`[data-application-id="${selectedApplication}"]`);
  const isReject = selectedDecision === 'reject-estate';
  application.querySelector('.application-state').innerHTML = isReject
    ? '<span class="status-pill status-overdue"><i></i>Rejected</span>'
    : '<span class="status-pill status-review"><i></i>More information</span>';
  const details = document.querySelector(`[data-details-for="${selectedApplication}"]`);
  details.querySelector('.application-actions').innerHTML = `<span class="local-change">${isReject ? 'Rejected' : 'Information requested'} in preview · Reason: ${escapeHtml(reason)}</span>`;
  application.querySelector('[data-action="review-estate"]').textContent = isReject ? 'Rejected' : 'Review';
  closeDecision();
  notify(isReject ? 'Rejection recorded in preview with a reason.' : 'Information request recorded in preview.');
}

function escapeHtml(value) {
  return value.replace(/[&<>"']/g, (character) => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
  })[character]);
}

function filterTenancies() {
  if (document.getElementById('tenancyRows')?.dataset.live === 'true') return;
  const rows = [...document.querySelectorAll('#tenancyRows tr')];
  rows.forEach((row) => {
    const rowStatus = row.dataset.tenancyStatus;
    const matchesStatus = tenancyStatusFilter === 'all' || rowStatus === tenancyStatusFilter
      || (tenancyStatusFilter === 'pending' && ['draft', 'pending_approval'].includes(rowStatus));
    const matchesSearch = (row.dataset.search || '').includes(tenancyQuery);
    row.classList.toggle('hidden', !(matchesStatus && matchesSearch));
  });
  const pendingCount = rows.filter((row) => row.dataset.tenancyStatus === 'pending').length;
  document.getElementById('tenancyPendingCount').textContent = String(pendingCount);
  document.getElementById('tenancyPendingFilterCount').textContent = String(pendingCount);
}

let selectedTenancyRowId = null;
let selectedRenewalRowId = null;

function openTenancyCreate() {
  document.getElementById('tenancyCreateForm').reset();
  document.getElementById('tenancyCreateError').textContent = '';
  document.getElementById('tenancyCreateModal').classList.remove('hidden');
}

function tenancyDateLabel(value) {
  const date = new Date(`${value}T12:00:00`);
  return Number.isNaN(date.getTime()) ? value : new Intl.DateTimeFormat('en-NG', { day: '2-digit', month: 'short', year: 'numeric' }).format(date);
}

function occupancyIsCurrent(occupant, today = new Date().toISOString().slice(0, 10)) {
  return occupant?.active === true && occupant.effectiveFrom <= today
    && (!occupant.effectiveTo || occupant.effectiveTo >= today);
}

function openTenancyReview(row, readOnly = false) {
  if (!row) return;
  selectedTenancyRowId = row.dataset.tenancyId;
  const conflicts = [...document.querySelectorAll('#tenancyRows tr')].filter((candidate) => candidate !== row
    && candidate.dataset.propertyId === row.dataset.propertyId
    && ['active', 'expiring'].includes(candidate.dataset.tenancyStatus));
  document.getElementById('reviewTenancyProperty').textContent = row.querySelector('.request-name strong').textContent;
  document.getElementById('reviewTenancyTenant').textContent = row.dataset.tenant || row.querySelector('.request-name small').textContent;
  document.getElementById('reviewTenancyLandlord').textContent = row.dataset.landlord || row.children[1].textContent;
  document.getElementById('reviewTenancyRent').textContent = `${row.children[2].childNodes[0].textContent.trim()} · ${row.dataset.frequency || 'Frequency shown in row'}`;
  document.getElementById('reviewTenancyTerm').textContent = `${tenancyDateLabel(row.dataset.start)} – ${row.dataset.end ? tenancyDateLabel(row.dataset.end) : 'Open ended'}`;
  const conflict = document.getElementById('reviewTenancyConflict');
  conflict.textContent = conflicts.length ? `Potential conflict · ${conflicts.map((item) => item.dataset.tenant).join(', ')}` : 'No sample conflict found';
  conflict.classList.toggle('is-conflict', conflicts.length > 0);
  document.getElementById('tenancyReviewError').textContent = conflicts.length ? 'Approval is blocked in this preview while another active tenancy is shown for the property.' : '';
  const approve = document.querySelector('[data-action="confirm-tenancy-approval"]');
  approve.classList.toggle('hidden', readOnly || row.dataset.tenancyStatus !== 'pending');
  approve.disabled = conflicts.length > 0;
  document.querySelector('[data-action="open-tenancy-termination"]').classList.toggle('hidden', !['active', 'expiring'].includes(row.dataset.tenancyStatus));
  document.querySelector('[data-action="open-tenancy-edit"]').classList.toggle('hidden', !['draft', 'pending'].includes(row.dataset.tenancyStatus));
  const revisions = Number(row.dataset.termRevisionCount || 0);
  document.getElementById('tenancyChangeSummary').textContent = revisions
    ? `${revisions} local term change${revisions === 1 ? '' : 's'} recorded for this agreement.`
    : 'No term changes recorded in this preview.';
  document.getElementById('tenancyReviewModal').classList.remove('hidden');
}

function closeTenancyWorkflow() {
  document.getElementById('tenancyCreateModal').classList.add('hidden');
  document.getElementById('tenancyReviewModal').classList.add('hidden');
  document.getElementById('tenancyEditModal').classList.add('hidden');
  document.getElementById('tenancyTerminationModal').classList.add('hidden');
  document.getElementById('tenancyRenewalModal').classList.add('hidden');
  selectedTenancyRowId = null;
  selectedRenewalRowId = null;
}

function openTenancyEdit() {
  const row = [...document.querySelectorAll('#tenancyRows tr')].find((candidate) => candidate.dataset.tenancyId === selectedTenancyRowId);
  if (!row || !['draft', 'pending'].includes(row.dataset.tenancyStatus)) return;
  document.getElementById('tenancyEditSummary').textContent = `${row.querySelector('.request-name strong').textContent} · ${row.dataset.tenant} · Tenant and property links remain fixed.`;
  const payee = document.getElementById('editTenancyPayee');
  if (![...payee.options].some((option) => option.value === row.dataset.landlord)) payee.add(new Option(row.dataset.landlord, row.dataset.landlord));
  payee.value = row.dataset.landlord;
  document.getElementById('editTenancyRent').value = row.dataset.rent;
  document.getElementById('editTenancyFrequency').value = row.dataset.frequency || 'Annual';
  document.getElementById('editTenancyStart').value = row.dataset.start;
  document.getElementById('editTenancyEnd').value = row.dataset.end || '';
  document.getElementById('tenancyEditError').textContent = '';
  document.getElementById('tenancyReviewModal').classList.add('hidden');
  document.getElementById('tenancyEditModal').classList.remove('hidden');
}

function closeTenancyEdit() {
  document.getElementById('tenancyEditModal').classList.add('hidden');
  if (selectedTenancyRowId) openTenancyReview([...document.querySelectorAll('#tenancyRows tr')].find((candidate) => candidate.dataset.tenancyId === selectedTenancyRowId));
}

function saveTenancyTermsPreview(event) {
  event.preventDefault();
  const row = [...document.querySelectorAll('#tenancyRows tr')].find((candidate) => candidate.dataset.tenancyId === selectedTenancyRowId);
  const payee = document.getElementById('editTenancyPayee').value;
  const rent = Number(document.getElementById('editTenancyRent').value);
  const frequency = document.getElementById('editTenancyFrequency').value;
  const start = document.getElementById('editTenancyStart').value;
  const end = document.getElementById('editTenancyEnd').value;
  if (!row || !['draft', 'pending'].includes(row.dataset.tenancyStatus)
    || !payee || !Number.isFinite(rent) || rent <= 0 || !start || (end && end < start)) {
    document.getElementById('tenancyEditError').textContent = 'Enter a valid payee, positive rent and term dates.';
    return;
  }
  const previous = { landlord: row.dataset.landlord, rent: row.dataset.rent, frequency: row.dataset.frequency, start: row.dataset.start, end: row.dataset.end || '' };
  const next = { landlord: payee, rent: String(rent), frequency, start, end };
  if (JSON.stringify(previous) === JSON.stringify(next)) {
    document.getElementById('tenancyEditError').textContent = 'No term changes to save.';
    return;
  }
  const history = JSON.parse(row.dataset.termHistory || '[]');
  history.push({ before: previous, after: next, changedAt: new Date().toISOString() });
  row.dataset.termHistory = JSON.stringify(history);
  row.dataset.termRevisionCount = String(history.length);
  row.dataset.landlord = payee;
  row.dataset.rent = String(rent);
  row.dataset.frequency = frequency;
  row.dataset.start = start;
  row.dataset.end = end;
  row.dataset.search = `${row.querySelector('.request-name strong').textContent} ${row.dataset.tenant} ${payee}`.toLowerCase();
  const rentCell = row.children[2];
  rentCell.replaceChildren(document.createTextNode(new Intl.NumberFormat('en-NG', { style: 'currency', currency: 'NGN', maximumFractionDigits: 0 }).format(rent)), document.createTextNode(' '));
  const frequencyLabel = document.createElement('small');
  frequencyLabel.className = 'cell-sub';
  frequencyLabel.textContent = frequency;
  rentCell.append(frequencyLabel);
  row.children[1].textContent = payee;
  row.children[3].textContent = `${tenancyDateLabel(start)} – ${end ? tenancyDateLabel(end) : 'Open ended'}`;
  closeTenancyEdit();
  filterTenancies();
  notify('Updated terms and prior values recorded in this page preview only.');
}

function openTenancyTermination() {
  const row = [...document.querySelectorAll('#tenancyRows tr')].find((candidate) => candidate.dataset.tenancyId === selectedTenancyRowId);
  if (!row || !['active', 'expiring'].includes(row.dataset.tenancyStatus)) return;
  document.getElementById('tenancyTerminationSummary').textContent = `${row.querySelector('.request-name strong').textContent} · ${row.dataset.tenant} · ${row.dataset.landlord}`;
  document.getElementById('tenancyTerminationDate').value = new Date().toISOString().slice(0, 10);
  document.getElementById('tenancyTerminationReason').value = '';
  document.getElementById('tenancyTerminationError').textContent = '';
  document.getElementById('tenancyReviewModal').classList.add('hidden');
  document.getElementById('tenancyTerminationModal').classList.remove('hidden');
}

function closeTenancyTermination() {
  document.getElementById('tenancyTerminationModal').classList.add('hidden');
  if (selectedTenancyRowId) document.getElementById('tenancyReviewModal').classList.remove('hidden');
}

function terminateTenancyPreview(event) {
  event.preventDefault();
  const row = [...document.querySelectorAll('#tenancyRows tr')].find((candidate) => candidate.dataset.tenancyId === selectedTenancyRowId);
  const effectiveTo = document.getElementById('tenancyTerminationDate').value;
  const reason = document.getElementById('tenancyTerminationReason').value.trim();
  const error = document.getElementById('tenancyTerminationError');
  if (!row || !['active', 'expiring'].includes(row.dataset.tenancyStatus)
    || !effectiveTo || effectiveTo < row.dataset.start || !reason) {
    error.textContent = 'Enter an effective date on or after the tenancy start and a reason.';
    return;
  }
  row.dataset.tenancyStatus = 'terminated';
  row.dataset.end = effectiveTo;
  row.dataset.terminationReason = reason;
  row.children[3].textContent = `${tenancyDateLabel(row.dataset.start)} – ended ${tenancyDateLabel(effectiveTo)}`;
  const pill = document.createElement('span');
  pill.className = 'status-pill status-overdue';
  pill.innerHTML = '<i></i>Terminated';
  row.querySelector('.status-pill').replaceWith(pill);
  const actions = row.lastElementChild;
  actions.replaceChildren();
  const history = document.createElement('span');
  history.className = 'local-change';
  history.textContent = 'History retained';
  actions.append(history);
  closeTenancyWorkflow();
  filterTenancies();
  notify('Termination shown locally. The live service must close the linked occupancy and record the reason and audit event.');
}

function createTenancyPreview(event) {
  event.preventDefault();
  const propertySelect = document.getElementById('newTenancyProperty');
  const propertyId = propertySelect.value;
  const tenant = document.getElementById('newTenancyTenant').value;
  const payee = document.getElementById('newTenancyPayee').value;
  const rent = Number(document.getElementById('newTenancyRent').value);
  const frequency = document.getElementById('newTenancyFrequency').selectedOptions[0].textContent;
  const start = document.getElementById('newTenancyStart').value;
  const end = document.getElementById('newTenancyEnd').value;
  const initialStatus = document.getElementById('newTenancyStatus').value;
  if (!propertyId || !tenant || !payee || !Number.isFinite(rent) || rent <= 0 || !start
    || (end && end < start)) {
    document.getElementById('tenancyCreateError').textContent = 'Choose valid parties and property, enter a positive rent, and check the term dates.';
    return;
  }

  const propertyName = propertySelect.selectedOptions[0].textContent;
  const id = `tenancy-${Date.now()}`;
  const row = document.createElement('tr');
  row.dataset.tenancyId = id;
  row.dataset.propertyId = propertyId;
  row.dataset.tenancyStatus = initialStatus;
  row.dataset.tenant = tenant;
  row.dataset.landlord = payee;
  row.dataset.rent = String(rent);
  row.dataset.frequency = frequency;
  row.dataset.start = start;
  row.dataset.end = end;
  row.dataset.search = `${propertyName} ${tenant} ${payee}`.toLowerCase();
  const initials = tenant.split(/\s+/).map((part) => part[0]).join('').slice(0, 2);
  const rentLabel = new Intl.NumberFormat('en-NG', { style: 'currency', currency: 'NGN', maximumFractionDigits: 0 }).format(rent);
  const statusLabel = initialStatus === 'draft' ? 'Draft' : 'Pending approval';
  const statusClass = initialStatus === 'draft' ? 'status-expiring' : 'status-review';
  const term = `${tenancyDateLabel(start)} – ${end ? tenancyDateLabel(end) : 'Open ended'}`;
  row.innerHTML = `<td><span class="person-avatar person-a">${escapeHtml(initials)}</span><span class="request-name"><strong>${escapeHtml(propertyName)}</strong><small>${escapeHtml(tenant)} · Tenant</small></span></td><td>${escapeHtml(payee)}</td><td class="amount-cell">${escapeHtml(rentLabel)} <small class="cell-sub">${escapeHtml(frequency)}</small></td><td>${escapeHtml(term)}</td><td>—</td><td><span class="status-pill ${statusClass}"><i></i>${statusLabel}</span></td><td>${initialStatus === 'pending' ? '<button class="table-action approve-action" data-action="approve-tenancy">Review</button>' : '<button class="table-action" data-action="tenancy-detail">View / edit</button>'}</td>`;
  document.getElementById('tenancyRows').prepend(row);
  closeTenancyWorkflow();
  document.querySelector('[data-tenancy-filter="all"]').click();
  notify('Tenancy added to this page preview only. No record or audit event was saved to Zvend.');
}

function approveTenancyPreview() {
  const row = [...document.querySelectorAll('#tenancyRows tr')].find((candidate) => candidate.dataset.tenancyId === selectedTenancyRowId);
  if (!row || row.dataset.tenancyStatus !== 'pending') return closeTenancyWorkflow();
  const conflict = [...document.querySelectorAll('#tenancyRows tr')].some((candidate) => candidate !== row
    && candidate.dataset.propertyId === row.dataset.propertyId
    && ['active', 'expiring'].includes(candidate.dataset.tenancyStatus));
  if (conflict) {
    document.getElementById('tenancyReviewError').textContent = 'A conflicting active tenancy appeared. Refresh and resolve it before approval.';
    return;
  }
  row.dataset.tenancyStatus = 'active';
  const pill = document.createElement('span');
  pill.className = 'status-pill status-active';
  pill.innerHTML = '<i></i>Active';
  row.querySelector('.status-pill').replaceWith(pill);
  const action = row.querySelector('[data-action="approve-tenancy"]');
  if (action) {
    const reviewed = document.createElement('span');
    reviewed.className = 'local-change';
    reviewed.textContent = 'Approved in preview';
    action.replaceWith(reviewed);
  }
  closeTenancyWorkflow();
  filterTenancies();
  notify('Tenancy activation previewed locally. The live service must recheck conflicts and write the audit event.');
}

function openTenancyRenewal(row) {
  if (!row || !['active', 'expiring'].includes(row.dataset.tenancyStatus)) return;
  selectedRenewalRowId = row.dataset.tenancyId;
  document.getElementById('renewalPriorSummary').textContent = `${row.querySelector('.request-name strong').textContent} · ${row.dataset.tenant} · Current term ${tenancyDateLabel(row.dataset.start)} – ${tenancyDateLabel(row.dataset.end)}`;
  document.getElementById('renewalRent').value = row.dataset.rent;
  document.getElementById('renewalFrequency').value = row.dataset.frequency || 'Annual';
  document.getElementById('renewalStart').value = row.dataset.end;
  document.getElementById('renewalEnd').value = '';
  document.getElementById('tenancyRenewalError').textContent = '';
  document.getElementById('tenancyRenewalModal').classList.remove('hidden');
}

function createTenancyRenewalPreview(event) {
  event.preventDefault();
  const prior = [...document.querySelectorAll('#tenancyRows tr')].find((candidate) => candidate.dataset.tenancyId === selectedRenewalRowId);
  const start = document.getElementById('renewalStart').value;
  const end = document.getElementById('renewalEnd').value;
  if (!prior || !start || !end || end <= start || Number(document.getElementById('renewalRent').value) <= 0) {
    document.getElementById('tenancyRenewalError').textContent = 'Enter a positive rent amount and a valid new term.';
    return;
  }
  const row = document.createElement('tr');
  const id = `renewal-${Date.now()}`;
  const property = prior.querySelector('.request-name strong').textContent;
  const tenant = prior.dataset.tenant;
  const landlord = prior.dataset.landlord;
  const rent = Number(document.getElementById('renewalRent').value);
  const frequency = document.getElementById('renewalFrequency').value;
  row.dataset.tenancyId = id;
  row.dataset.renewalOf = prior.dataset.tenancyId;
  row.dataset.propertyId = prior.dataset.propertyId;
  row.dataset.tenancyStatus = 'pending';
  row.dataset.tenant = tenant;
  row.dataset.landlord = landlord;
  row.dataset.rent = String(rent);
  row.dataset.frequency = frequency;
  row.dataset.start = start;
  row.dataset.end = end;
  row.dataset.search = `${property} ${tenant} ${landlord} renewal` .toLowerCase();
  const initials = tenant.split(/\s+/).map((part) => part[0]).join('').slice(0, 2);
  const rentLabel = new Intl.NumberFormat('en-NG', { style: 'currency', currency: 'NGN', maximumFractionDigits: 0 }).format(rent);
  row.innerHTML = `<td><span class="person-avatar person-a">${escapeHtml(initials)}</span><span class="request-name"><strong>${escapeHtml(property)}</strong><small>${escapeHtml(tenant)} · Linked renewal</small></span></td><td>${escapeHtml(landlord)}</td><td class="amount-cell">${escapeHtml(rentLabel)} <small class="cell-sub">${escapeHtml(frequency)}</small></td><td>${escapeHtml(tenancyDateLabel(start))} – ${escapeHtml(tenancyDateLabel(end))}</td><td>—</td><td><span class="status-pill status-review"><i></i>Pending approval</span></td><td><button class="table-action approve-action" data-action="approve-tenancy">Review</button></td>`;
  document.getElementById('tenancyRows').append(row);
  closeTenancyWorkflow();
  document.querySelector('[data-tenancy-filter="all"]').click();
  notify('Linked renewal added to the local preview. The previous agreement remains unchanged.');
}

function filterExpenses() {
  document.querySelectorAll('#expenseRows tr').forEach((row) => {
    const matchesStatus = expenseStatusFilter === 'all' || row.dataset.expenseStatus === expenseStatusFilter;
    const matchesSearch = row.dataset.search.includes(expenseQuery);
    row.classList.toggle('hidden', !(matchesStatus && matchesSearch));
  });
}

function setPropertyDisplay(mode) {
  const showMap = mode === 'map';
  document.querySelectorAll('[data-property-view]').forEach((button) => {
    button.classList.toggle('selected', button.dataset.propertyView === mode);
    button.setAttribute('aria-pressed', String(button.dataset.propertyView === mode));
  });
  document.getElementById('propertyMapPanel').classList.toggle('hidden', !showMap);
  document.querySelector('#propertyRegister .table-wrap.full-table').classList.toggle('hidden', showMap);
  document.querySelector('#propertyRegister .pagination').classList.toggle('hidden', showMap);
}

function updatePropertyMapDetail(marker) {
  document.querySelectorAll('[data-property-marker]').forEach((item) => {
    item.classList.toggle('selected', item === marker);
  });
  document.getElementById('mapPropertyTitle').textContent = marker.dataset.propertyName;
  document.getElementById('mapPropertyMeta').textContent = marker.dataset.propertyMeta;
  document.getElementById('mapPropertyStatus').textContent = marker.dataset.propertyStatus;
  document.getElementById('mapPropertyStatus').className = `map-detail-status map-status-${marker.dataset.propertyStatusClass}`;
  document.getElementById('mapPropertyOpen').dataset.propertyId = marker.dataset.propertyRecord;
}

const maintenanceWorkRecords = {
  m1: { title: 'Water pressure issue', reference: 'REQ-00318', property: 'Block C · 12', requester: 'Chioma Adebayo', assignee: 'Samuel Nwosu · Facilities', category: 'Plumbing', priority: 'High', status: 'In progress', description: 'Bathroom tap pressure has been low since yesterday. Resident reports the issue affects the kitchen and main bathroom.', allowed: ['Awaiting parts', 'Resolved'], updates: [{ date: 'Today · 9:20 am', text: 'The facilities team is checking the building water line.' }, { date: 'Today · 8:05 am', text: 'Your request was assigned to the estate facilities team.' }] },
  m2: { title: 'Street light repair', reference: 'REQ-00317', property: 'Maple Street · 08', requester: 'Daniel Adewale', assignee: '', category: 'Electrical', priority: 'Medium', status: 'Under review', description: 'Street light outside the property has not been working since yesterday evening.', allowed: ['Assigned', 'Rejected'], updates: [{ date: 'Yesterday · 6:12 pm', text: 'The estate team received your request. It is waiting for review.' }] },
  m3: { title: 'Gate access card', reference: 'REQ-00316', property: 'Oakwood · 08', requester: 'Musa Abdullahi', assignee: 'Samuel Nwosu · Facilities', category: 'Access', priority: 'Low', status: 'Assigned', description: 'A replacement access card was requested for an approved household member.', allowed: ['In progress', 'Resolved'], updates: [{ date: '2 Nov · 11:30 am', text: 'Your request was assigned to the security team.' }] }
};
let selectedMaintenanceRequestId = null;

function openMaintenanceReview(requestId) {
  if (typeof window.openLiveMaintenanceReview === 'function') {
    window.openLiveMaintenanceReview(requestId);
    return;
  }
  const request = maintenanceWorkRecords[requestId];
  if (!request) return;
  selectedMaintenanceRequestId = requestId;
  document.getElementById('maintenanceReviewTitle').textContent = request.title;
  document.getElementById('maintenanceReviewSummary').textContent = `${request.reference} · ${request.property} · ${request.requester}`;
  const status = document.getElementById('maintenanceReviewStatus');
  status.innerHTML = `<i></i>${escapeHtml(request.status)}`;
  status.className = `status-pill ${request.status === 'In progress' ? 'status-progress' : request.status === 'Resolved' ? 'status-paid' : request.status === 'Assigned' ? 'status-assigned' : 'status-review'}`;
  document.getElementById('maintenanceReviewDescription').textContent = request.description;
  document.getElementById('maintenanceReviewCategory').textContent = request.category;
  document.getElementById('maintenanceReviewPriority').textContent = `${request.priority} priority`;
  document.getElementById('maintenanceReviewCreated').textContent = `Reference ${request.reference}`;
  document.getElementById('maintenanceAssignee').value = request.assignee;
  const nextStatus = document.getElementById('maintenanceNextStatus');
  nextStatus.replaceChildren(new Option('No status change', ''), ...request.allowed.map((value) => new Option(value, value)));
  document.getElementById('maintenanceTransitionReason').value = '';
  document.getElementById('maintenancePublicUpdate').value = '';
  document.getElementById('maintenanceInternalNote').value = '';
  const history = document.getElementById('maintenanceReviewHistory');
  history.replaceChildren();
  request.updates.forEach((update) => {
    const item = document.createElement('article');
    const date = document.createElement('small');
    date.textContent = update.date;
    const content = document.createElement('p');
    content.textContent = update.text;
    item.append(date, content);
    history.append(item);
  });
  maintenanceReviewModal.classList.remove('hidden');
}

function closeMaintenanceReview() {
  maintenanceReviewModal.classList.add('hidden');
  selectedMaintenanceRequestId = null;
  window.__liveMaintenanceRequestId = '';
}

function saveMaintenanceReview() {
  if (typeof window.saveLiveMaintenanceReview === 'function') {
    window.saveLiveMaintenanceReview();
    return;
  }
  const request = maintenanceWorkRecords[selectedMaintenanceRequestId];
  if (!request) return;
  const nextStatus = document.getElementById('maintenanceNextStatus').value;
  const reason = document.getElementById('maintenanceTransitionReason').value.trim();
  const update = document.getElementById('maintenancePublicUpdate').value.trim();
  const internalNote = document.getElementById('maintenanceInternalNote').value.trim();
  if (['Resolved', 'Rejected', 'Closed'].includes(nextStatus) && !reason) {
    notify('Add a resolution summary or reason before changing this status.');
    document.getElementById('maintenanceTransitionReason').focus();
    return;
  }
  request.assignee = document.getElementById('maintenanceAssignee').value;
  if (nextStatus) request.status = nextStatus;
  if (update) request.updates.unshift({ date: 'Just now', text: update });
  if (internalNote) request.internalNotes = [...(request.internalNotes || []), { date: 'Just now', text: internalNote }];
  const row = document.querySelector(`[data-maintenance-id="${selectedMaintenanceRequestId}"]`);
  row.children[3].textContent = request.assignee || 'Unassigned';
  const statusClass = request.status === 'In progress' ? 'status-progress' : request.status === 'Resolved' ? 'status-paid' : request.status === 'Assigned' ? 'status-assigned' : 'status-review';
  row.querySelector('.maintenance-status').innerHTML = `<span class="status-pill ${statusClass}"><i></i>${escapeHtml(request.status)}</span>`;
  closeMaintenanceReview();
  notify('Assignment and updates changed in this page preview only. A live service must validate and audit every change.');
}

const propertyDetailRecords = {
  'oakwood-01': {
    name: 'Oakwood · 01', code: 'OAK-NG-001', address: '18 Oakwood Drive, North Gardens, Lekki, Lagos',
    type: 'Detached house', zone: 'North Gardens', status: 'Operational', occupancy: 'Owner occupied', coordinates: 'Not recorded',
    owners: [{ name: 'Emeka Okafor', share: '100%', effective: 'Effective 18 May 2021', effectiveFrom: '2021-05-18', status: 'Verified', active: true }],
    occupants: [{ name: 'Emeka Okafor', relationship: 'Owner occupant', effectiveFrom: '2026-01-12', effectiveTo: '', active: true }],
    history: [{ date: '18 May 2021', title: 'Ownership recorded', detail: 'Emeka Okafor · sole owner' }, { date: '12 Jan 2026', title: 'Occupancy confirmed', detail: 'Owner occupied' }],
    documents: 'Property documents are available through authorized private links. Charge rules are configured by the estate.'
  },
  'block-c-12': {
    name: 'Block C · 12', code: 'OAK-OC-C12', address: 'Block C, Oakwood Court, Lekki, Lagos',
    type: 'Apartment', zone: 'Oakwood Court', status: 'Operational', occupancy: 'Tenant occupied', coordinates: 'Not recorded',
    owners: [{ name: 'Chioma Adebayo', share: '100%', effective: 'Effective 3 March 2020', effectiveFrom: '2020-03-03', status: 'Verified', active: true }],
    occupants: [{ name: 'Daniel Adewale', relationship: 'Tenant', effectiveFrom: '2026-02-01', effectiveTo: '', active: true }],
    history: [{ date: '3 Mar 2020', title: 'Ownership recorded', detail: 'Chioma Adebayo · sole owner' }, { date: '2 Sep 2026', title: 'Occupancy updated', detail: 'Tenant occupied' }],
    documents: 'Property documents are available through authorized private links. Charge rules are configured by the estate.'
  },
  'maple-08': {
    name: 'Maple Street · 08', code: 'OAK-MP-008', address: '8 Maple Street, Maple Phase, Lekki, Lagos',
    type: 'Townhouse', zone: 'Maple Phase', status: 'Operational', occupancy: 'Vacant', coordinates: 'Not recorded',
    owners: [{ name: 'Daniel Adewale', share: '100%', effective: 'Effective 20 June 2024', effectiveFrom: '2024-06-20', status: 'Verified', active: true }],
    occupants: [],
    history: [{ date: '20 Jun 2024', title: 'Ownership recorded', detail: 'Daniel Adewale · sole owner' }, { date: '31 Oct 2026', title: 'Occupancy ended', detail: 'Property marked vacant' }],
    documents: 'Property documents are available through authorized private links. Charge rules are configured by the estate.'
  },
  'block-a-06': {
    name: 'Block A · 06', code: 'OAK-OC-A06', address: 'Block A, Oakwood Court, Lekki, Lagos',
    type: 'Apartment', zone: 'Oakwood Court', status: 'Operational', occupancy: 'Tenant occupied', coordinates: 'Not recorded',
    owners: [{ name: 'Fatima Bello', share: '100%', effective: 'Effective 9 August 2022', effectiveFrom: '2022-08-09', status: 'Verified', active: true }],
    occupants: [{ name: 'Mariam Yusuf', relationship: 'Tenant', effectiveFrom: '2026-01-15', effectiveTo: '', active: true }],
    history: [{ date: '9 Aug 2022', title: 'Ownership recorded', detail: 'Fatima Bello · sole owner' }, { date: '5 Oct 2026', title: 'Occupancy confirmed', detail: 'Tenant occupied' }],
    documents: 'Property documents are available through authorized private links. Charge rules are configured by the estate.'
  },
  'cedar-03': {
    name: 'Cedar Lane · 03', code: 'OAK-CL-003', address: '3 Cedar Lane, Lekki, Lagos',
    type: 'Duplex', zone: 'Cedar Lane', status: 'Under maintenance', occupancy: 'Tenant occupied', coordinates: 'Not recorded',
    owners: [{ name: 'Musa Abdullahi', share: '100%', effective: 'Effective 14 February 2023', effectiveFrom: '2023-02-14', status: 'Verified', active: true }],
    occupants: [{ name: 'Tunde Okafor', relationship: 'Tenant', effectiveFrom: '2026-08-01', effectiveTo: '', active: true }],
    history: [{ date: '14 Feb 2023', title: 'Ownership recorded', detail: 'Musa Abdullahi · sole owner' }, { date: '2 Nov 2026', title: 'Maintenance status set', detail: 'Operational status changed; tenancy occupancy remains recorded' }],
    documents: 'Property documents are available through authorized private links. Charge rules are configured by the estate.'
  }
};

function appendPropertyFact(label, value) {
  const fact = document.createElement('div');
  fact.className = 'property-detail-fact';
  const heading = document.createElement('span');
  heading.textContent = label;
  const content = document.createElement('strong');
  content.textContent = value;
  fact.append(heading, content);
  document.getElementById('propertyDetailFacts').append(fact);
}

function openPropertyDetail(propertyId) {
  if (typeof window.openLivePropertyDetail === 'function' && window.openLivePropertyDetail(propertyId)) return;
  const record = propertyDetailRecords[propertyId];
  if (!record) return;
  document.querySelector('[data-action="archive-property"]').dataset.propertyId = propertyId;
  document.getElementById('propertyDetailTitle').textContent = record.name;
  document.getElementById('propertyDetailAddress').textContent = record.address;
  document.getElementById('propertyDetailCode').textContent = record.code;
  const facts = document.getElementById('propertyDetailFacts');
  facts.replaceChildren();
  appendPropertyFact('PROPERTY TYPE', record.type);
  if (record.unitNumber) appendPropertyFact('UNIT / HOUSE NUMBER', record.unitNumber);
  appendPropertyFact('ZONE / PHASE', record.zone);
  appendPropertyFact('OPERATIONAL STATUS', record.status);
  const currentOccupants = (record.occupants || []).filter((occupant) => occupancyIsCurrent(occupant));
  const derivedOccupancy = currentOccupants.some((occupant) => occupant.relationship === 'Tenant')
    ? 'Tenant occupied'
    : currentOccupants.some((occupant) => occupant.relationship === 'Owner occupant')
      ? 'Owner occupied'
      : currentOccupants.length ? 'Household occupied' : 'Vacant';
  appendPropertyFact('OCCUPANCY', derivedOccupancy);
  appendPropertyFact('GPS COORDINATES', record.coordinates);

  const owners = document.getElementById('propertyOwnershipRecords');
  owners.replaceChildren();
  record.owners.forEach((owner) => {
    const item = document.createElement('article');
    item.className = 'property-owner-record';
    const person = document.createElement('div');
    const name = document.createElement('strong');
    name.textContent = owner.name;
    const effective = document.createElement('small');
    effective.textContent = owner.effective;
    person.append(name, effective);
    const actions = document.createElement('div');
    actions.className = 'ownership-record-actions';
    const status = document.createElement('span');
    status.className = `ownership-status ${owner.status === 'Pending verification' ? 'is-pending' : owner.status === 'Ended' ? 'is-ended' : ''}`;
    status.textContent = owner.status || 'Verified';
    actions.append(status);
    const share = document.createElement('span');
    share.className = 'ownership-share';
    share.textContent = owner.share || 'Share not tracked';
    actions.append(share);
    if (owner.status === 'Pending verification') {
      const verify = document.createElement('button');
      verify.className = 'table-action';
      verify.type = 'button';
      verify.dataset.action = 'verify-ownership';
      verify.dataset.ownerIndex = String(record.owners.indexOf(owner));
      verify.textContent = 'Verify';
      actions.append(verify);
    }
    if (owner.active !== false) {
      const end = document.createElement('button');
      end.className = 'table-action reject-action';
      end.type = 'button';
      end.dataset.action = 'end-ownership';
      end.dataset.ownerIndex = String(record.owners.indexOf(owner));
      end.textContent = 'End interest';
      actions.append(end);
    }
    item.append(person, actions);
    owners.append(item);
  });

  const occupancyRecords = document.getElementById('propertyOccupancyRecords');
  occupancyRecords.replaceChildren();
  (record.occupants || []).forEach((occupant) => {
    const item = document.createElement('article');
    item.className = 'property-owner-record';
    const person = document.createElement('div');
    const name = document.createElement('strong');
    name.textContent = occupant.name;
    const effective = document.createElement('small');
    effective.textContent = `${occupant.relationship} · ${tenancyDateLabel(occupant.effectiveFrom)} – ${occupant.effectiveTo ? tenancyDateLabel(occupant.effectiveTo) : 'Current'}`;
    person.append(name, effective);
    const actions = document.createElement('div');
    actions.className = 'ownership-record-actions';
    const status = document.createElement('span');
    const today = new Date().toISOString().slice(0, 10);
    const isCurrent = occupancyIsCurrent(occupant, today);
    const isUpcoming = occupant.active && occupant.effectiveFrom > today;
    status.className = `ownership-status ${isCurrent ? '' : 'is-ended'}`;
    status.textContent = isCurrent ? 'Current' : isUpcoming ? 'Upcoming' : 'Ended';
    actions.append(status);
    if (occupant.active && occupant.relationship !== 'Owner occupant' && (isCurrent || isUpcoming)) {
      const end = document.createElement('button');
      end.className = 'table-action reject-action';
      end.type = 'button';
      end.dataset.action = 'end-occupancy';
      end.dataset.occupancyIndex = String(record.occupants.indexOf(occupant));
      end.textContent = 'End occupancy';
      actions.append(end);
    }
    item.append(person, actions);
    occupancyRecords.append(item);
  });
  if (!occupancyRecords.children.length) {
    const empty = document.createElement('p');
    empty.className = 'property-occupancy-empty';
    empty.textContent = 'No occupant records. Add an approved resident relationship to record who lives here.';
    occupancyRecords.append(empty);
  }

  const history = document.getElementById('propertyLifecycleHistory');
  history.replaceChildren();
  record.history.forEach((entry) => {
    const item = document.createElement('article');
    item.className = 'property-history-entry';
    const date = document.createElement('time');
    date.textContent = entry.date;
    const title = document.createElement('strong');
    title.textContent = entry.title;
    const detail = document.createElement('small');
    detail.textContent = entry.detail;
    item.append(date, title, detail);
    history.append(item);
  });
  document.getElementById('propertyDetailDocuments').textContent = record.documents;
  propertyDetailModal.classList.remove('hidden');
}

function closePropertyDetail() {
  window.cancelLivePropertyDetail?.();
  propertyDetailModal.classList.add('hidden');
}

function openOwnershipForm(propertyId) {
  if (!propertyDetailRecords[propertyId]) return;
  selectedPropertyForOwnership = propertyId;
  document.getElementById('ownershipForm').reset();
  document.getElementById('ownershipFormError').textContent = '';
  document.getElementById('ownershipFrom').value = new Date().toISOString().slice(0, 10);
  document.getElementById('ownershipEmail').required = true;
  syncOwnershipPartyFields();
  ownershipModal.classList.remove('hidden');
  document.getElementById('ownershipName').focus();
}

function closeOwnershipForm() {
  ownershipModal.classList.add('hidden');
  selectedPropertyForOwnership = null;
}

function openOccupancyForm(propertyId) {
  if (!propertyDetailRecords[propertyId]) return;
  selectedPropertyForOccupancy = propertyId;
  document.getElementById('occupancyForm').reset();
  document.getElementById('occupancyFormError').textContent = '';
  document.getElementById('occupancyModalTitle').textContent = `Add occupant · ${propertyDetailRecords[propertyId].name}`;
  document.getElementById('occupancyFrom').value = new Date().toISOString().slice(0, 10);
  document.getElementById('occupancyModal').classList.remove('hidden');
}

function closeOccupancyForm() {
  document.getElementById('occupancyModal').classList.add('hidden');
  selectedPropertyForOccupancy = null;
}

function saveOccupancyPreview(event) {
  event.preventDefault();
  const record = propertyDetailRecords[selectedPropertyForOccupancy];
  const name = document.getElementById('occupancyResident').value;
  const relationship = document.getElementById('occupancyRelationship').selectedOptions[0].textContent;
  const effectiveFrom = document.getElementById('occupancyFrom').value;
  const effectiveTo = document.getElementById('occupancyTo').value;
  if (!record || !name || !effectiveFrom || (effectiveTo && effectiveTo < effectiveFrom)) {
    document.getElementById('occupancyFormError').textContent = 'Select a resident and valid effective dates.';
    return;
  }
  record.occupants ||= [];
  record.occupants.unshift({ id: `occupancy-${occupancySequence++}`, name, relationship, effectiveFrom, effectiveTo, active: !effectiveTo || effectiveTo >= new Date().toISOString().slice(0, 10) });
  record.history.unshift({ date: effectiveFrom, title: 'Occupancy relationship recorded', detail: `${name} · ${relationship} · local preview only` });
  const propertyId = selectedPropertyForOccupancy;
  closeOccupancyForm();
  openPropertyDetail(propertyId);
  notify('Occupancy added to this page preview only. The live service must verify membership, policy and audit history.');
}

function endOccupancyPreview(propertyId, occupancyIndex) {
  const record = propertyDetailRecords[propertyId];
  const occupant = record?.occupants?.[Number(occupancyIndex)];
  if (!occupant?.active) return;
  const effectiveTo = window.prompt('Enter the effective end date (YYYY-MM-DD):');
  if (effectiveTo === null) return;
  if (!/^\d{4}-\d{2}-\d{2}$/.test(effectiveTo) || effectiveTo < occupant.effectiveFrom
    || Number.isNaN(new Date(`${effectiveTo}T00:00:00Z`).getTime())
    || new Date(`${effectiveTo}T00:00:00Z`).toISOString().slice(0, 10) !== effectiveTo) {
    notify('Enter a valid effective end date under estate date policy.');
    return;
  }
  occupant.active = false;
  occupant.effectiveTo = effectiveTo;
  record.history.unshift({ date: effectiveTo, title: 'Occupancy ended', detail: `${occupant.name} · history retained · local preview only` });
  openPropertyDetail(propertyId);
  notify('Occupancy end shown in this page preview only. No access or membership record was changed.');
}

function saveOwnershipPreview(event) {
  event.preventDefault();
  const record = propertyDetailRecords[selectedPropertyForOwnership];
  if (!record) return;
  const name = document.getElementById('ownershipName').value.trim();
  const partyType = document.getElementById('ownershipPartyType').value;
  const email = document.getElementById('ownershipEmail').value.trim();
  const share = document.getElementById('ownershipShare').value.trim();
  const from = document.getElementById('ownershipFrom').value;
  const to = document.getElementById('ownershipTo').value;
  const error = document.getElementById('ownershipFormError');
  if (!name || (partyType === 'user' && !email.includes('@'))) {
    error.textContent = partyType === 'user' ? 'Enter the name and email for an existing Zvend user.' : 'Enter the approved legal entity name.';
    return;
  }
  if (!from || (to && to < from)) {
    error.textContent = 'Enter valid ownership dates. The end date cannot be before the start date.';
    return;
  }
  if (share && (!/^\d{1,3}(?:\.\d{1,2})?$/.test(share) || Number(share) <= 0 || Number(share) > 100)) {
    error.textContent = 'Share must be a number greater than 0 and no more than 100.';
    return;
  }
  record.owners.push({
    name: partyType === 'entity' ? `${name} · legal entity` : name,
    share: share ? `${share}%` : 'Share not tracked',
    effective: `Effective ${new Date(`${from}T00:00:00`).toLocaleDateString('en-NG', { day: 'numeric', month: 'short', year: 'numeric' })}${to ? ` to ${new Date(`${to}T00:00:00`).toLocaleDateString('en-NG', { day: 'numeric', month: 'short', year: 'numeric' })}` : ''}`,
    effectiveFrom: from,
    effectiveTo: to || null,
    status: document.getElementById('ownershipEvidence').value.trim() ? 'Pending verification' : 'Verification not required',
    active: !to,
    email: partyType === 'user' ? email : null,
    evidence: document.getElementById('ownershipEvidence').value.trim() || null,
  });
  record.history.unshift({ date: 'Just now', title: 'Ownership interest added', detail: `${name} · ${partyType === 'user' ? 'existing Zvend user' : 'legal entity'} · local preview only` });
  const propertyId = selectedPropertyForOwnership;
  closeOwnershipForm();
  openPropertyDetail(propertyId);
  notify('Ownership preview added on this page only. A live service must verify the party, policy, evidence and permissions.');
}

function updateOwnershipPreview(propertyId, ownerIndex, decision) {
  const record = propertyDetailRecords[propertyId];
  const owner = record?.owners[Number(ownerIndex)];
  if (!owner) return;
  if (decision === 'verify') {
    if (!owner.evidence) {
      notify('A live document service must verify ownership evidence before approval.');
      return;
    }
    owner.status = 'Verified';
    record.history.unshift({ date: 'Just now', title: 'Ownership evidence verified', detail: `${owner.name} · preview only` });
  } else {
    const endDate = window.prompt('Enter the effective end date (YYYY-MM-DD):');
    if (endDate === null) return;
    if (!/^\d{4}-\d{2}-\d{2}$/.test(endDate) || endDate < owner.effectiveFrom
      || Number.isNaN(new Date(`${endDate}T00:00:00Z`).getTime())
      || new Date(`${endDate}T00:00:00Z`).toISOString().slice(0, 10) !== endDate) {
      notify('Enter a valid effective end date under estate date policy.');
      return;
    }
    owner.active = false;
    owner.status = 'Ended';
    owner.effectiveTo = endDate;
    owner.effective = `Effective ${new Date(`${owner.effectiveFrom}T00:00:00`).toLocaleDateString('en-NG', { day: 'numeric', month: 'short', year: 'numeric' })} to ${new Date(`${endDate}T00:00:00`).toLocaleDateString('en-NG', { day: 'numeric', month: 'short', year: 'numeric' })}`;
    record.history.unshift({ date: endDate, title: 'Ownership interest ended', detail: `${owner.name} · history retained · local preview only` });
  }
  openPropertyDetail(propertyId);
  notify('Ownership lifecycle preview updated in this page only. No Zvend records or audit events were written.');
}

function syncOwnershipPartyFields() {
  const isUser = document.getElementById('ownershipPartyType').value === 'user';
  document.getElementById('ownershipNameLabel').firstChild.textContent = isUser ? 'Owner full name' : 'Approved legal entity name';
  document.getElementById('ownershipEmailLabel').classList.toggle('hidden', !isUser);
  document.getElementById('ownershipEmail').required = isUser;
}

function openPropertyArchive(propertyId) {
  const record = propertyDetailRecords[propertyId];
  if (!record) return;
  selectedPropertyForArchive = propertyId;
  document.getElementById('propertyArchiveTitle').textContent = `Archive ${record.name}?`;
  propertyArchiveModal.classList.remove('hidden');
}

function closePropertyArchive() {
  propertyArchiveModal.classList.add('hidden');
  selectedPropertyForArchive = null;
}

function showView(view) {
  const label = navLabels[view] || 'Overview';
  document.getElementById('crumbCurrent').textContent = label;
  document.querySelectorAll('.nav-item').forEach((item) => {
    item.classList.toggle('active', item.dataset.view === view);
  });

  const isOverview = view === 'overview';
  const isProperties = view === 'properties';
  const hasModule = Boolean(moduleViews[view]);
  if (view === 'tenancies') {
    tenancyStatusFilter = 'all';
    tenancyQuery = '';
  }
  if (view === 'finance') {
    expenseStatusFilter = 'all';
    expenseQuery = '';
  }
  if (view === 'properties') {
    selectPropertyRegisterTab('properties');
    const search = document.getElementById('propertySearch');
    if (search) search.value = '';
    document.querySelectorAll('#propertyRows tr').forEach((row) => row.classList.remove('hidden'));
    document.querySelectorAll('[data-property-marker]').forEach((marker) => marker.classList.remove('hidden'));
    document.getElementById('resultsCount').textContent = `Showing ${document.querySelectorAll('#propertyRows tr').length} of ${propertyPreviewCount} properties`;
    setPropertyDisplay('list');
  }
  overviewParts.forEach((part) => part.classList.toggle('hidden', !isOverview));
  propertyRegister.classList.toggle('hidden', !isProperties);
  placeholder.classList.toggle('hidden', isOverview || isProperties || hasModule);
  moduleContent.classList.toggle('hidden', !hasModule);
  moduleContent.innerHTML = hasModule ? moduleViews[view] : '';
  moduleContent.dataset.view = view;
  if (view === 'applications' && typeof window.initializeEstateApplicationQueue === 'function') {
    window.initializeEstateApplicationQueue();
  }
  if (view === 'residents') renderResidentRows();
  if (view === 'team') renderTeamRows();
  document.querySelector('.page-heading').classList.toggle('hidden', isProperties || hasModule);

  const title = document.getElementById('pageTitle');
  const subtitle = document.getElementById('pageSubtitle');
  const estateName = document.querySelector('.estate-meta strong');
  const estateLocation = document.querySelector('.estate-meta small');
  const estateAvatar = document.querySelector('.estate-avatar');
  const isPlatform = view === 'applications' || view === 'subscriptions';
  const hostConfig = window.ZvendEstateConfig || {};
  const hostEstate = hostConfig.currentEstate || {};
  const hostUser = hostConfig.currentUser || {};
  const hasHostEstateContext = Boolean(hostConfig.currentEstateId);
  const resolvedEstateName = isPlatform ? 'Platform workspace'
    : (typeof hostEstate.name === 'string' && hostEstate.name.trim() ? hostEstate.name.trim() : hasHostEstateContext ? 'Selected estate' : 'Oakwood Estate');
  const resolvedLocation = isPlatform ? 'All estates'
    : (typeof hostEstate.locationLabel === 'string' && hostEstate.locationLabel.trim() ? hostEstate.locationLabel.trim() : hasHostEstateContext ? 'Estate details unavailable' : 'Lekki, Lagos');
  const resolvedUserName = typeof hostUser.displayName === 'string' && hostUser.displayName.trim()
    ? hostUser.displayName.trim() : hasHostEstateContext ? 'there' : 'Amara';
  const today = new Date();
  const dateLabel = new Intl.DateTimeFormat(undefined, { day: 'numeric', month: 'short', year: 'numeric' }).format(today);
  const longDateLabel = new Intl.DateTimeFormat(undefined, { weekday: 'long', month: 'long', day: 'numeric', year: 'numeric' }).format(today).toUpperCase();
  const workspaceDate = document.getElementById('workspaceDate');
  const workspaceDateLong = document.getElementById('workspaceDateLong');
  if (workspaceDate) workspaceDate.textContent = `Today, ${dateLabel}`;
  if (workspaceDateLong) workspaceDateLong.textContent = longDateLabel;
  estateName.textContent = resolvedEstateName;
  estateLocation.textContent = resolvedLocation;
  estateAvatar.textContent = isPlatform ? 'Z' : [...resolvedEstateName][0].toUpperCase();
  document.querySelector('.breadcrumb > span').textContent = isPlatform ? 'Zvend Platform' : resolvedEstateName;
  const estateStatus = document.getElementById('estateWorkspaceStatus');
  if (estateStatus) {
    const statusLabel = hostEstate.status === 'active' ? 'ESTATE ACTIVE' : isPlatform ? 'PLATFORM WORKSPACE' : 'PREVIEW ESTATE';
    estateStatus.replaceChildren(document.createElement('i'), document.createTextNode(statusLabel));
  }
  const profileName = document.querySelector('.profile-meta strong');
  const profileRole = document.querySelector('.profile-meta small');
  const profileAvatar = document.querySelector('.profile-avatar');
  if (profileName) profileName.textContent = hostUser.displayName || (hasHostEstateContext ? 'Signed-in user' : 'Preview user');
  if (profileRole) profileRole.textContent = hostUser.estateRole || (hasHostEstateContext ? 'Estate member' : 'Local preview');
  if (profileAvatar) profileAvatar.textContent = (hostUser.displayName || 'Preview user').split(/\s+/).map((part) => part[0]).join('').slice(0, 2).toUpperCase();
  if (isOverview) {
    title.textContent = `Good morning, ${resolvedUserName}`;
    subtitle.textContent = `Here’s what’s happening at ${resolvedEstateName} today.`;
  } else {
    title.textContent = label;
    subtitle.textContent = isProperties
      ? 'A clear view of every home and unit in your estate.'
      : sectionCopy[view] || 'Manage your estate workspace.';
  }
  if (!isOverview && !isProperties && !hasModule) {
    document.getElementById('placeholderTitle').textContent = label;
    document.getElementById('placeholderText').textContent = sectionCopy[view] || 'This section will connect to the estate services.';
  }
  if (!isOverview) (hasModule ? moduleContent : isProperties ? propertyRegister : title)
    .scrollIntoView({ block: 'nearest', behavior: 'smooth' });
  closeSidebar();
  window.dispatchEvent(new CustomEvent('estate:view-changed', { detail: { view } }));
}

function closeSidebar() {
  document.getElementById('sidebar').classList.remove('open');
  document.getElementById('sidebarScrim').classList.remove('open');
}

document.addEventListener('click', (event) => {
  const registerTab = event.target.closest('[data-register-tab]');
  if (registerTab) {
    selectPropertyRegisterTab(registerTab.dataset.registerTab);
    return;
  }
  const propertyView = event.target.closest('[data-property-view]');
  if (propertyView) {
    setPropertyDisplay(propertyView.dataset.propertyView);
    return;
  }
  const propertyMarker = event.target.closest('[data-property-marker]');
  if (propertyMarker) {
    updatePropertyMapDetail(propertyMarker);
    return;
  }
  const viewControl = event.target.closest('[data-view]');
  if (viewControl) {
    event.preventDefault();
    showView(viewControl.dataset.view);
    return;
  }

  const actionControl = event.target.closest('[data-action]');
  if (actionControl) {
    if (actionControl.dataset.action === 'report-incident' && typeof window.openSecurityIncidentForm === 'function') { window.openSecurityIncidentForm(); return; }
    if (actionControl.dataset.action === 'close-security-incident') { window.closeSecurityIncidentForm?.(); return; }
    if (actionControl.dataset.action === 'submit-security-incident') { window.submitSecurityIncidentReport?.(); return; }
    if (actionControl.dataset.action === 'invite-staff') {
      openStaffInvite();
      return;
    }
    if (actionControl.dataset.action === 'close-staff-invite') {
      closeStaffInvite();
      return;
    }
    if (actionControl.dataset.action === 'submit-staff-invite') {
      submitStaffInvitePreview();
      return;
    }
    if (actionControl.dataset.action === 'member-details' && openStaffMembershipModal(actionControl)) return;
    if (actionControl.dataset.action === 'close-staff-membership') {
      closeStaffMembershipModal();
      return;
    }
    if (actionControl.dataset.action === 'open-staff-role-change') {
      openStaffRoleChange();
      return;
    }
    if (actionControl.dataset.action === 'close-staff-role-change') {
      closeStaffRoleChange();
      return;
    }
    if (actionControl.dataset.action === 'submit-staff-role-change') {
      submitStaffRoleChangePreview();
      return;
    }
    if (actionControl.dataset.action === 'suspend-staff-membership') {
      applyStaffMembershipPreview('suspend');
      return;
    }
    if (actionControl.dataset.action === 'revoke-staff-membership') {
      applyStaffMembershipPreview('revoke');
      return;
    }
    const messages = {
      invite: 'Resident invitations will connect to the estate membership service.',
      report: 'Report export will connect to estate reporting.',
      'create-pass': 'Visitor pass creation will connect to server-side pass issuance.',
      'new-invoice': 'Invoice creation will connect to estate billing and payment services.',
      'visitor-filter': 'Visitor filters will use estate, gate and pass status permissions.',
      'gate-view': 'The gate view will be scoped to the staff member’s assigned gate.',
      'incident-review': 'Incident detail, evidence and follow-up actions will be available only to authorized estate staff. This preview does not change incident records.',
      'incident-history': 'Incident history will be filtered by estate and the staff member’s incident permissions.',
      'invoice-filter': 'Invoice filters will use estate and payer permissions.',
      'maintenance-categories': 'Maintenance categories will use estate configuration.',
      'maintenance-export': 'Request exports will use the authorized estate scope.',
      'tenancy-export': 'Tenancy exports will use the authorized estate scope.',
      'add-facility': 'Facility setup will use estate-defined hours, capacity, fees and booking rules.',
      'facility-settings': 'Facility settings will connect to estate hours, capacity and fee configuration.',
      'booking-calendar': 'The calendar will use server-confirmed facility availability.',
      'announcement-audience': 'Audience selection will resolve current estate membership and property groups.',
      'announcement-detail': 'Announcement detail and delivery/read receipts will be scoped to the estate.',
      'announcement-preferences': 'Notification preferences will connect to the existing Zvend notification service.',
      'new-expense': 'Open an expense request form.',
      'close-expense': 'Close expense request form.',
      'submit-expense': 'Submit the expense for review.',
      'approve-expense': 'Review expense approval.',
      'close-expense-approval': 'Close expense approval dialog.',
      'confirm-expense-approval': 'Confirm an expense approval.',
      'application-filter': 'Application filters will include draft, pending, review and decision statuses.',
      'application-history': 'Decision history will show reviewer, reason and timestamp.',
      'preview-document': 'Private document preview will use an authorized, short-lived link.',
      'review-estate': 'Review application details.',
      'request-info': 'Request information from the applicant.',
      'reject-estate': 'Record an application rejection.',
      'approve-estate': 'Approve this estate application.',
      'close-modal': 'Close review dialog.',
      'compose-announcement': 'Open announcement composer.',
      'close-announcement': 'Close announcement composer.',
      'save-announcement': 'Save announcement as draft.',
      'schedule-announcement': 'Publish or schedule announcement.',
      'invite-staff': 'Staff invitations will use existing Zvend identities and estate-scoped permission grants.',
      'team-filter': 'Member filters will be applied within the active estate context.',
      'member-details': 'Member detail and access history require estate staff-view permission.',
      'audit-history': 'Role and membership changes will be loaded from the estate audit service.',
      'report-export': 'Exports will be generated by the authorized reporting service as private, time-limited files.',
      'report-open': 'This report will use estate-scoped source records and the active date filter.',
      'plan-details': 'Subscription terms and limits are managed in the Zvend platform billing service.',
      'create-plan': 'A new plan starts as a draft version and requires platform approval before use.',
      'plan-history': 'Plan version history will be loaded from the platform subscription service.',
      'edit-plan': 'Plan edits create a new approved version; existing estate agreements keep their terms.',
      'subscription-filter': 'Subscription filters will use the authorized platform finance or operations scope.',
      'subscription-details': 'Subscription details will show only fields allowed by the platform role.'
    };
    if (actionControl.dataset.action === 'new-expense') {
      openExpenseComposer();
      return;
    }
    if (actionControl.dataset.action === 'close-expense') {
      closeExpenseComposer();
      return;
    }
    if (actionControl.dataset.action === 'submit-expense') {
      submitExpenseRequest();
      return;
    }
    if (actionControl.dataset.action === 'approve-expense') {
      openExpenseApproval(actionControl);
      return;
    }
    if (actionControl.dataset.action === 'close-expense-approval') {
      closeExpenseApproval();
      return;
    }
    if (actionControl.dataset.action === 'confirm-expense-approval') {
      confirmExpenseApproval();
      return;
    }
    if (actionControl.dataset.action === 'compose-announcement') {
      openAnnouncementComposer();
      return;
    }
    if (actionControl.dataset.action === 'close-announcement') {
      closeAnnouncementComposer();
      return;
    }
    if (actionControl.dataset.action === 'save-announcement') {
      saveAnnouncement('draft');
      return;
    }
    if (actionControl.dataset.action === 'schedule-announcement') {
      saveAnnouncement('publish');
      return;
    }
    if (actionControl.dataset.action === 'save-settings') {
      const name = document.getElementById('settingEstateName').value.trim();
      const email = document.getElementById('settingEstateEmail').value.trim();
      if (!name || !email || !email.includes('@')) {
        notify('Add an estate name and a valid office email before saving.');
        return;
      }
      notify('Settings preview saved for this page only. A live update must be validated and audited by the estate service.');
      return;
    }
    if (actionControl.dataset.action === 'review-estate') {
      const details = document.querySelector(`[data-details-for="${actionControl.dataset.id}"]`);
      details.classList.toggle('hidden');
      actionControl.textContent = details.classList.contains('hidden') ? 'Review' : 'Close';
      return;
    }
    if (actionControl.dataset.action === 'property-detail') {
      openPropertyDetail(actionControl.dataset.propertyId);
      return;
    }
    if (actionControl.dataset.action === 'add-property') {
      openPropertyCreateForm();
      return;
    }
    if (actionControl.dataset.action === 'close-property-create') {
      closePropertyCreateForm();
      return;
    }
    if (actionControl.dataset.action === 'add-structure-node') {
      openStructureNodeForm();
      return;
    }
    if (actionControl.dataset.action === 'close-structure-node') {
      closeStructureNodeForm();
      return;
    }
    if (actionControl.dataset.action === 'edit-structure-node') {
      editStructureNodePreview(actionControl.dataset.nodeId);
      return;
    }
    if (actionControl.dataset.action === 'archive-structure-node') {
      archiveStructureNodePreview(actionControl.dataset.nodeId);
      return;
    }
    if (actionControl.dataset.action === 'add-ownership') {
      openOwnershipForm(propertyDetailModal.querySelector('[data-action="archive-property"]').dataset.propertyId);
      return;
    }
    if (actionControl.dataset.action === 'add-occupant') {
      openOccupancyForm(propertyDetailModal.querySelector('[data-action="archive-property"]').dataset.propertyId);
      return;
    }
    if (actionControl.dataset.action === 'close-occupancy') {
      closeOccupancyForm();
      return;
    }
    if (actionControl.dataset.action === 'end-occupancy') {
      endOccupancyPreview(propertyDetailModal.querySelector('[data-action="archive-property"]').dataset.propertyId, actionControl.dataset.occupancyIndex);
      return;
    }
    if (actionControl.dataset.action === 'close-ownership') {
      closeOwnershipForm();
      return;
    }
    if (actionControl.dataset.action === 'verify-ownership' || actionControl.dataset.action === 'end-ownership') {
      updateOwnershipPreview(
        propertyDetailModal.querySelector('[data-action="archive-property"]').dataset.propertyId,
        actionControl.dataset.ownerIndex,
        actionControl.dataset.action === 'verify-ownership' ? 'verify' : 'end'
      );
      return;
    }
    if (actionControl.dataset.action === 'maintenance-review') {
      openMaintenanceReview(actionControl.dataset.id);
      return;
    }
    if (actionControl.dataset.action === 'close-maintenance-review') {
      closeMaintenanceReview();
      return;
    }
    if (actionControl.dataset.action === 'save-maintenance-review') {
      saveMaintenanceReview();
      return;
    }
    if (actionControl.dataset.action === 'close-property-detail') {
      closePropertyDetail();
      return;
    }
    if (actionControl.dataset.action === 'archive-property') {
      openPropertyArchive(actionControl.dataset.propertyId);
      return;
    }
    if (actionControl.dataset.action === 'close-property-archive') {
      closePropertyArchive();
      return;
    }
    if (actionControl.dataset.action === 'check-property-archive') {
      const record = propertyDetailRecords[selectedPropertyForArchive];
      if (record) notify(`${record.name}: a live estate service must check occupants, tenancies, unpaid charges and access links before archiving. No preview data was changed.`);
      return;
    }
    if (actionControl.dataset.action === 'request-info' || actionControl.dataset.action === 'reject-estate') {
      openDecision(actionControl.dataset.action, actionControl.dataset.id);
      return;
    }
    if (actionControl.dataset.action === 'approve-estate') {
      openEstateApproval(actionControl.dataset.id);
      return;
    }
    if (actionControl.dataset.action === 'close-estate-approval') {
      closeEstateApproval();
      return;
    }
    if (actionControl.dataset.action === 'confirm-estate-approval') {
      confirmEstateApproval();
      return;
    }
    if (actionControl.dataset.action === 'close-modal') {
      closeDecision();
      return;
    }
    if (actionControl.dataset.action === 'resident-details') {
      openResidentDecision(actionControl.dataset.id);
      return;
    }
    if (actionControl.dataset.action === 'close-resident-decision') {
      closeResidentDecision();
      return;
    }
    if (actionControl.dataset.action === 'approve-resident-decision') {
      decideResidentPreview('approve');
      return;
    }
    if (actionControl.dataset.action === 'reject-resident-decision') {
      decideResidentPreview('reject');
      return;
    }
    if (actionControl.dataset.action === 'create-tenancy') { openTenancyCreate(); return; }
    if (actionControl.dataset.action === 'approve-tenancy') { openTenancyReview(actionControl.closest('tr')); return; }
    if (actionControl.dataset.action === 'renew-tenancy') { openTenancyRenewal(actionControl.closest('tr')); return; }
    if (actionControl.dataset.action === 'tenancy-detail') { openTenancyReview(actionControl.closest('tr'), true); return; }
    if (actionControl.dataset.action === 'close-tenancy-workflow') { closeTenancyWorkflow(); return; }
    if (actionControl.dataset.action === 'open-tenancy-termination') { openTenancyTermination(); return; }
    if (actionControl.dataset.action === 'close-tenancy-termination') { closeTenancyTermination(); return; }
    if (actionControl.dataset.action === 'open-tenancy-edit') { openTenancyEdit(); return; }
    if (actionControl.dataset.action === 'close-tenancy-edit') { closeTenancyEdit(); return; }
    if (actionControl.dataset.action === 'confirm-tenancy-approval') { approveTenancyPreview(); return; }
    if (actionControl.dataset.action === 'record-access') {
      const row = document.querySelector(`[data-visit-id="${actionControl.dataset.visit}"]`);
      const isCheckIn = actionControl.dataset.kind === 'check-in';
      const accessCell = row.lastElementChild;
      const timeCell = row.children[2];
      if (isCheckIn) {
        timeCell.textContent = 'Just now';
        row.classList.remove('visit-expected');
        accessCell.innerHTML = '<span class="status-pill status-checked"><i></i>On estate</span>';
      } else {
        row.remove();
      }
      notify(`${isCheckIn ? 'Entry' : 'Exit'} recorded in local preview only. The live service must validate the pass and assigned gate.`);
      return;
    }
    if (actionControl.dataset.action === 'approve-booking' || actionControl.dataset.action === 'decline-booking') {
      const row = document.querySelector(`[data-booking-id="${actionControl.dataset.id}"]`);
      const approved = actionControl.dataset.action === 'approve-booking';
      row.querySelector('.booking-state').innerHTML = approved
        ? '<span class="status-pill status-active"><i></i>Approved</span>'
        : '<span class="status-pill status-overdue"><i></i>Declined</span>';
      row.querySelector('.row-actions').innerHTML = `<span class="local-change">${approved ? 'Approved' : 'Declined'} in preview</span>`;
      notify(`Booking ${approved ? 'approval' : 'decline'} shown in preview. Live availability must be checked by the service.`);
      return;
    }
    notify(messages[actionControl.dataset.action] || 'This action will connect to the estate service.');
    return;
  }

  if (event.target.closest('#propertyFilter')) {
    notify('Property filters will be available with the property service.');
  }
});

document.addEventListener('click', (event) => {
  const expenseFilter = event.target.closest('[data-expense-filter]');
  if (expenseFilter) {
    if (typeof window.refreshEstateExpenses === 'function') return;
    document.querySelectorAll('[data-expense-filter]').forEach((button) => button.classList.toggle('selected', button === expenseFilter));
    expenseStatusFilter = expenseFilter.dataset.expenseFilter;
    filterExpenses();
    return;
  }
  const announcementFilter = event.target.closest('[data-announcement-filter]');
  if (announcementFilter) {
    document.querySelectorAll('[data-announcement-filter]').forEach((button) => button.classList.toggle('selected', button === announcementFilter));
    const status = announcementFilter.dataset.announcementFilter;
    document.querySelectorAll('#announcementRows tr').forEach((row) => {
      row.classList.toggle('hidden', status !== 'all' && row.dataset.announcementStatus !== status);
    });
    return;
  }
  const tenancyFilter = event.target.closest('[data-tenancy-filter]');
  if (tenancyFilter) {
    document.querySelectorAll('[data-tenancy-filter]').forEach((button) => button.classList.toggle('selected', button === tenancyFilter));
    tenancyStatusFilter = tenancyFilter.dataset.tenancyFilter;
    window.dispatchEvent(new CustomEvent('estate:tenancy-filter', { detail: { filter: tenancyStatusFilter } }));
    filterTenancies();
    return;
  }
  const filter = event.target.closest('[data-resident-filter]');
  if (filter) {
    document.querySelectorAll('[data-resident-filter]').forEach((button) => button.classList.toggle('selected', button === filter));
    window.dispatchEvent(new CustomEvent('estate:resident-filter', { detail: { filter: filter.dataset.residentFilter } }));
    renderResidentRows();
    return;
  }
  const teamFilter = event.target.closest('[data-team-filter]');
  if (!teamFilter) return;
  document.querySelectorAll('[data-team-filter]').forEach((button) => button.classList.toggle('selected', button === teamFilter));
  renderTeamRows();
});

document.addEventListener('input', (event) => {
  if (event.target.id === 'residentSearch') {
    window.dispatchEvent(new CustomEvent('estate:resident-search', { detail: { search: event.target.value } }));
    renderResidentRows();
  }
  if (event.target.id === 'teamSearch') renderTeamRows();
});
document.getElementById('staffInviteRole').addEventListener('change', updateStaffInviteScope);
document.getElementById('staffRoleChangeSelect').addEventListener('change', (event) => {
  document.getElementById('staffRoleChangeScope').textContent = staffRoleScopePreview[event.target.value] || 'Choose a role to preview its estate scope';
});
staffInviteModal.addEventListener('click', (event) => {
  if (event.target === staffInviteModal) closeStaffInvite();
});
staffMembershipModal.addEventListener('click', (event) => {
  if (event.target === staffMembershipModal) closeStaffMembershipModal();
});
staffRoleChangeModal.addEventListener('click', (event) => {
  if (event.target === staffRoleChangeModal) closeStaffRoleChange();
});

document.getElementById('submitDecision').addEventListener('click', saveDecision);
document.getElementById('tenancyCreateForm').addEventListener('submit', createTenancyPreview);
document.getElementById('tenancyEditForm').addEventListener('submit', saveTenancyTermsPreview);
document.getElementById('tenancyTerminationForm').addEventListener('submit', terminateTenancyPreview);
document.getElementById('tenancyRenewalForm').addEventListener('submit', createTenancyRenewalPreview);
document.getElementById('tenancyCreateModal').addEventListener('click', (event) => { if (event.target.id === 'tenancyCreateModal') closeTenancyWorkflow(); });
document.getElementById('tenancyReviewModal').addEventListener('click', (event) => { if (event.target.id === 'tenancyReviewModal') closeTenancyWorkflow(); });
document.getElementById('tenancyEditModal').addEventListener('click', (event) => { if (event.target.id === 'tenancyEditModal') closeTenancyEdit(); });
document.getElementById('tenancyTerminationModal').addEventListener('click', (event) => { if (event.target.id === 'tenancyTerminationModal') closeTenancyTermination(); });
document.getElementById('tenancyRenewalModal').addEventListener('click', (event) => { if (event.target.id === 'tenancyRenewalModal') closeTenancyWorkflow(); });
decisionModal.addEventListener('click', (event) => {
  if (event.target === decisionModal) closeDecision();
});
residentDecisionModal.addEventListener('click', (event) => {
  if (event.target === residentDecisionModal) closeResidentDecision();
});
estateApprovalModal.addEventListener('click', (event) => {
  if (event.target === estateApprovalModal) closeEstateApproval();
});
announcementModal.addEventListener('click', (event) => {
  if (event.target === announcementModal) closeAnnouncementComposer();
});
expenseModal.addEventListener('click', (event) => {
  if (event.target === expenseModal) closeExpenseComposer();
});
expenseApprovalModal.addEventListener('click', (event) => {
  if (event.target === expenseApprovalModal) closeExpenseApproval();
});

document.getElementById('propertySearch').addEventListener('input', (event) => {
  if (typeof window.refreshEstateProperties === 'function') return;
  const query = event.target.value.trim().toLowerCase();
  const rows = [...document.querySelectorAll('#propertyRows tr')];
  let visible = 0;
  rows.forEach((row) => {
    const matches = row.dataset.search.includes(query);
    row.classList.toggle('hidden', !matches);
    if (matches) visible += 1;
  });
  document.querySelectorAll('[data-property-marker]').forEach((marker) => {
    marker.classList.toggle('hidden', !marker.dataset.mapSearch.includes(query));
  });
  document.getElementById('resultsCount').textContent = query
    ? `Showing ${visible} matching properties`
    : 'Showing 5 of 248 properties';
});

propertyDetailModal.addEventListener('click', (event) => {
  if (event.target === propertyDetailModal) closePropertyDetail();
});
ownershipModal.addEventListener('click', (event) => {
  if (event.target === ownershipModal) closeOwnershipForm();
});
structureNodeModal.addEventListener('click', (event) => {
  if (event.target === structureNodeModal) closeStructureNodeForm();
});
propertyCreateModal.addEventListener('click', (event) => {
  if (event.target === propertyCreateModal) closePropertyCreateForm();
});
document.getElementById('propertyCreateForm').addEventListener('submit', savePropertyPreview);
document.getElementById('structureNodeForm').addEventListener('submit', saveStructureNodePreview);
document.getElementById('ownershipForm').addEventListener('submit', saveOwnershipPreview);
document.getElementById('occupancyForm').addEventListener('submit', saveOccupancyPreview);
document.getElementById('occupancyModal').addEventListener('click', (event) => { if (event.target.id === 'occupancyModal') closeOccupancyForm(); });
document.getElementById('ownershipPartyType').addEventListener('change', syncOwnershipPartyFields);
propertyArchiveModal.addEventListener('click', (event) => {
  if (event.target === propertyArchiveModal) closePropertyArchive();
});
maintenanceReviewModal.addEventListener('click', (event) => {
  if (event.target === maintenanceReviewModal) closeMaintenanceReview();
});

document.addEventListener('input', (event) => {
  if (event.target.matches('#tenancySearch')) {
    tenancyQuery = event.target.value.trim().toLowerCase();
    window.dispatchEvent(new CustomEvent('estate:tenancy-search', { detail: { search: event.target.value.trim() } }));
    filterTenancies();
  } else if (event.target.matches('#expenseSearch')) {
    expenseQuery = event.target.value.trim().toLowerCase();
    filterExpenses();
  }
});

document.getElementById('menuToggle').addEventListener('click', () => {
  document.getElementById('sidebar').classList.add('open');
  document.getElementById('sidebarScrim').classList.add('open');
});
document.querySelector('.property-register-tabs').addEventListener('keydown', (event) => {
  const tabs = [...document.querySelectorAll('[data-register-tab]')];
  const current = tabs.indexOf(event.target.closest('[data-register-tab]'));
  if (current < 0) return;
  const next = event.key === 'ArrowRight' ? (current + 1) % tabs.length
    : event.key === 'ArrowLeft' ? (current - 1 + tabs.length) % tabs.length
      : event.key === 'Home' ? 0 : event.key === 'End' ? tabs.length - 1 : current;
  if (next === current) return;
  event.preventDefault();
  tabs[next].focus();
  selectPropertyRegisterTab(tabs[next].dataset.registerTab);
});
document.getElementById('sidebarScrim').addEventListener('click', closeSidebar);
document.addEventListener('keydown', (event) => {
  if (event.key === 'Escape') {
    closeSidebar();
    closeDecision();
    closeResidentDecision();
    closeStaffInvite();
    closeStaffMembershipModal();
    closeEstateApproval();
    closeAnnouncementComposer();
    closeExpenseComposer();
    closeExpenseApproval();
    closePropertyArchive();
    closePropertyDetail();
    closeMaintenanceReview();
  }
});

document.querySelector('.estate-switcher').addEventListener('click', () => {
  if (typeof window.openEstateContextSelector === 'function') return window.openEstateContextSelector();
  notify('Estate switching will use the signed-in user’s memberships.');
});

showView('overview');
