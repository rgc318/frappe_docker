# Frontend Workspace

This directory contains standalone frontend projects for `apps/myapp`.

- `myapp-mobile/`: mobile and tablet app project
- `myapp-web/`: web admin and dashboard project

The backend business logic remains in `apps/myapp`.
These frontend projects should call the existing `myapp.api.gateway.*` HTTP APIs.

## Frontend Plan

Current frontend split:

- `myapp-mobile`
  - Primary client for sales, purchasing, receiving, delivery, invoicing, and payments
  - Target devices: mobile phones and tablets
  - Recommended stack: React Native + Expo + Expo Router + TypeScript
- `myapp-web`
  - Admin, query, dashboard, and reporting client
  - Target devices: desktop browsers
  - Recommended stack: React + Ant Design Pro + TypeScript

## Current Progress

Current verified state:

- `myapp-mobile`
  - Expo project initialized and verified with `npm run web`
  - route skeleton implemented
  - login/session flow connected to ERPNext built-in auth
  - user module implemented with:
    - login
    - session restore
    - logout
    - me page
    - account info page
    - system info page
    - settings page
  - user context now reads:
    - current username
    - user profile summary
    - current user roles
  - frontend auth handling already reserves optional token mode for future backend support
  - settings page now supports:
    - backend base URL override
    - default company
    - default warehouse
    - sales flow mode
    - purchase flow mode
  - company and warehouse settings already support:
    - candidate search
    - existence validation against backend master data
    - field-level error prompts
  - first real mobile business flow has started:
    - product search
    - sales order draft
    - sales order creation
  - current sales-order page is being reworked toward:
    - document-centered layout
    - inline product search inside the order page
    - editable quantity and price
    - compact order meta area
    - bottom fixed action bar
  - bottom tab icon mapping has been fixed for web/Android fallback icons
  - current UI polishing has expanded from login/user pages to:
    - home workbench page
    - product search page
    - sales order page
- `myapp-web`
  - Ant Design Pro project initialized and verified with `npm run dev`
  - still at starter-template stage
  - business pages have not started yet

## Reference Materials

The mobile design work in this phase should not rely only on abstract discussion. Use the following local folders as the current visual reference source:

- Reference product screenshots:
  - `/home/rgc318/python-project/frappe_docker/reference_photos`
- Current implementation screenshots:
  - `/home/rgc318/python-project/frappe_docker/screenshots`

Current most relevant reference images:

- Home / dashboard:
  - `/home/rgc318/python-project/frappe_docker/reference_photos/home-dashboard-overview.jpg`
  - `/home/rgc318/python-project/frappe_docker/reference_photos/home-dashboard-overview-02.jpg`
  - `/home/rgc318/python-project/frappe_docker/reference_photos/home-dashboard-overview-03.jpg`
- Sales order / billing form:
  - `/home/rgc318/python-project/frappe_docker/reference_photos/sales-order-form-full.jpg`
  - `/home/rgc318/python-project/frappe_docker/reference_photos/sales-order-form-full-02.jpg`
  - `/home/rgc318/python-project/frappe_docker/reference_photos/sales-order-form-full-03.jpg`
  - `/home/rgc318/python-project/frappe_docker/reference_photos/sales-order-form-shipping-section.jpg`
  - `/home/rgc318/python-project/frappe_docker/reference_photos/sales-order-form-shipping-summary.jpg`
- Product / customer / settings related:
  - `/home/rgc318/python-project/frappe_docker/reference_photos/product-list-page.jpg`
  - `/home/rgc318/python-project/frappe_docker/reference_photos/customer-selection-page.jpg`
  - `/home/rgc318/python-project/frappe_docker/reference_photos/settings-page.jpg`
  - `/home/rgc318/python-project/frappe_docker/reference_photos/my-profile-page.jpg`

Use the references as layout and interaction guidance, not as a full visual copy target.

## Current Design Direction

This phase has already clarified several design constraints:

- Do not force all pages into one generic card-heavy shell
- Use references for:
  - information hierarchy
  - spacing density
  - action placement
  - document-first flow
- Do not blindly copy:
  - color style
  - marketing decoration
  - third-party product branding

Current agreed mobile design direction:

- Home page:
  - top search
  - quick shortcuts
  - detailed data modules below
- Sales order page:
  - order document as the core object
  - product area should dominate the page
  - customer/company/warehouse/date are supporting information, not the visual main body
  - bottom fixed action area is acceptable
- Me/settings pages:
  - grouped list structure
  - avoid excessive nested cards
  - field-level validation should be obvious

## Current Design Issues Already Identified

The following issues were explicitly discovered during this round and should continue to guide later changes:

- Search pages should not waste the first screen on oversized title headers
- Home shortcuts should use icon-above/text-below alignment and stable grid spacing
- Search boxes must be real searchable inputs, not fake navigation placeholders
- Sales order flow must be document-centered; product search is a sub-step inside order creation
- Company/warehouse validation should be shown at the field level, not only as weak page-level messages
- App-side settings are local operator preferences, not backend master-data management pages
- Warehouse/company creation and broader master-data maintenance are not current mobile priorities

## Related Backend Docs

Use the backend docs under `apps/myapp` as the single source of truth.

- API reference:
  - `/home/rgc318/python-project/frappe_docker/apps/myapp/API_GATEWAY.zh-CN.md`
- Backend overview:
  - `/home/rgc318/python-project/frappe_docker/apps/myapp/README.zh-CN.md`
- Current handoff/context:
  - `/home/rgc318/python-project/frappe_docker/apps/myapp/HANDOFF.zh-CN.md`
- Sales module design:
  - `/home/rgc318/python-project/frappe_docker/apps/myapp/WHOLESALE_TECH_DESIGN.zh-CN.md`
- Purchase module design:
  - `/home/rgc318/python-project/frappe_docker/apps/myapp/PURCHASE_TECH_DESIGN.zh-CN.md`

Frontend docs should not duplicate the full API spec. They should only describe:

- which pages call which APIs
- which fields the page cares about
- what business flow the page follows

## First Phase

The first frontend phase should focus on core business flows, not dashboards.

- Mobile first:
  - login
  - product search
  - create sales order
  - submit delivery
  - create sales invoice
  - record payment
  - create purchase order
  - receive purchase order
  - create purchase invoice from receipt
  - record supplier payment
- Web later:
  - document list and detail
  - status tracking
  - query pages
  - finance and inventory dashboards

## Frontend Delivery Order

Recommended implementation order:

1. Mobile login and home navigation
2. Mobile sales flow
3. Mobile purchase flow
4. Mobile return flow
5. Web document query pages
6. Web reporting and dashboard pages

Reason:

- current backend APIs are already strongest around core sales and purchase workflows
- mobile is the primary operational client
- web is better used as a management and lookup client after transaction pages are stable

## Shared Business Rules

These rules should be treated as frontend-level requirements, not only backend behavior.

- Sales and purchase flows both support step-by-step execution
- Sales and purchase quantities and prices may be adjusted in later steps
- Purchase receipt is the factual inbound document
- Sales invoice and purchase invoice are the main accounting settlement documents
- Returns must be created as dedicated return documents instead of editing original documents
- Frontend should always display company-aware data and default to `rgc (Demo)` in the current test environment

## Frontend Output Standard

Each frontend page spec should clearly state:

- page goal
- target user
- upstream and downstream steps
- APIs used
- required fields
- key actions
- success result
- common failure cases

## Mobile Route Direction

The mobile project should use Expo Router with this structure direction:

- `login.tsx` for authentication
- `(tabs)` for first-level navigation
- `sales/*` for sales flow pages
- `purchase/*` for purchase flow pages
- `common/*` for shared picker and helper pages

The tab layer should stay shallow. Detailed transaction pages should not all be placed directly inside tabs.

The current mobile route plan also includes user-module subpages:

- `account-info.tsx`
- `system-info.tsx`
- `settings.tsx`

The intended structure is:

- `Me` page:
  - overview and entry page only
- `Account Info`:
  - account-facing details
- `System Info`:
  - environment/runtime details
- `Settings`:
  - backend address and later client-side configuration

The current settings design follows this boundary:

- app-side operator preferences remain local to frontend
- system-level master data maintenance is not moved into mobile yet
- company and warehouse settings must still match backend master data before they can be saved
