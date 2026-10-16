## Backend contract for Flutter client

This contract was checked against the FastAPI routes and schemas under `backend/app` and the current Flutter call sites under `lib`. The OpenAPI source of truth is the running backend's `/openapi.json`; interactive docs are at `/docs`.

### Registration decision

`POST /auth/register` accepts a JSON body with:

| Field | Requirement |
|---|---|
| `email` | Required, valid email address |
| `password` | Required, at least 8 characters |
| `role` | Required, exactly `seller` or `buyer` |
| `name` | Required, at least 1 character; stored as the user's display name |
| `company_name` | Required by registration service only when `role` is `seller`; otherwise optional |
| `phone` | Optional |
| `address` | Optional; defaults to `Warehouse Address` for sellers and `Business Address` for buyers |
| `warehouse_lat`, `warehouse_lng`, `city` | Seller fields; optional, default to Jakarta coordinates and `Jakarta` |
| `business_type`, `base_lat`, `base_lng`, `pref_categories` | Buyer fields; optional, default to `resto`, Jakarta coordinates, and an empty list |

**Failure confirmed for seller registration.** In `lib/features/auth/screens/register_screen.dart`, the company-name text field is passed only as `name`. `AuthApiService` sends `company_name` only when its `companyName` argument is provided, and the screen does not provide that argument. Thus a seller request contains the required `name`, but omits the conditional `company_name` requirement and receives HTTP 422 with `MISSING_SELLER_INFO` (“Company name is required for seller registration”). The UI defaults to buyer, for which the omitted `company_name` is valid, so this explains seller-specific failures rather than all registration failures.

No backend change is needed for this failure. The client should send the entered company value as `name` and, for seller role, also as `company_name` (or add distinct display-name and company-name inputs). Seller warehouse address, coordinates, and city are not required to register: backend defaults are applied. Buyer profile details are similarly optional and defaulted.

### Auth responses and errors

Successful API responses use `{ "success": true, "data": ... }`. Errors use `{ "success": false, "error": { "code": ..., "message": ... } }`.

- Registration: HTTP 201, `data` is `access_token`, `refresh_token`, `token_type` (`bearer`), `expires_in` (3600 seconds), `user_id`, `role`, and `name`.
- Login: HTTP 200 with the same token shape. Invalid credentials return 401 `INVALID_CREDENTIALS`.
- Refresh: HTTP 200 with rotated access and refresh tokens. Send `{ "refresh_token": "..." }`; invalid/revoked or expired tokens return 401 (`INVALID_REFRESH_TOKEN` / `EXPIRED_REFRESH_TOKEN`).
- Logout: HTTP 200; requires `Authorization: Bearer <access_token>`, optional body `{ "refresh_token": "..." }`. Without a refresh token the server revokes all active refresh tokens for the user.
- Duplicate email: registration returns 409 `EMAIL_ALREADY_EXISTS`.
- Request/schema validation: HTTP 422 `VALIDATION_ERROR`, with field paths and messages joined in `error.message`. Seller missing company name is HTTP 422 `MISSING_SELLER_INFO`.
- Protected endpoints use the access token in `Authorization: Bearer <access_token>`; missing/invalid credentials return 401, and role mismatch returns 403 `FORBIDDEN`.

### Current backend endpoint inventory

All routes below are mounted by `backend/app/main.py`. Success responses use the envelope above unless noted by the endpoint schema.

| Method and path | Access | Purpose |
|---|---|---|
| `POST /auth/register` | Public | Create buyer/seller and issue tokens |
| `POST /auth/login` | Public | Authenticate and issue tokens |
| `POST /auth/refresh` | Public | Rotate refresh token |
| `POST /auth/logout` | Bearer | Revoke one or all active refresh tokens |
| `GET /profile` | Bearer | Fetch current user plus buyer/seller profile |
| `PATCH /profile` | Bearer | Update common and role-specific profile fields |
| `GET /products?category=&search=` | Public | Browse product catalog |
| `POST /products` | Seller | Add product catalog entry |
| `GET /listings` | Public | Browse listings; supports search, category, location/radius, price, shelf life, sort, and pagination filters |
| `POST /listings` | Seller | Create listing for an existing product |
| `GET /listings/my` | Seller | List own listings |
| `GET /listings/{listing_id}` | Public | Fetch listing details and current auction price |
| `PATCH /listings/{listing_id}` | Seller owner | Update quantity, minimum price, or status |
| `POST /listings/{listing_id}/buy` | Buyer | Purchase listing; optional quantity and biometric confirmation |
| `GET /orders` | Bearer | List the caller's sales or purchase history |
| `GET /orders/{order_id}` | Bearer | Fetch order detail, restricted to its buyer/seller |
| `PATCH /orders/{order_id}/status` | Bearer | Update order status |
| `POST /ai/invoice` | Seller | Upload invoice as multipart `file` for OCR |
| `POST /ai/price-advice` | Seller | Request price recommendation |
| `GET /donations/{donation_id}/certificate` | Public | Fetch donation certificate |
| `GET /blockchain/verify/{tx_hash}` | Public | Verify transaction hash |
| `GET /rates` | Public | Fetch exchange rates |
| `GET /notifications` | Bearer | List current user's notifications |
| `PATCH /notifications/{notification_id}/read` | Bearer | Mark own notification as read |
| `POST /devices` | Bearer | Register FCM device token |
| `POST /feedback` | Bearer | Submit course feedback |
| `GET /health` | Public | Health check |

### Flutter call coverage

At this revision, direct Dio calls in `lib` are limited to auth and profile: register, login, refresh, logout, and `GET /profile`. There are no Flutter API calls yet for product/listing/order/AI/donation/rates/notification/device/feedback workflows; those backend routes exist, but their presence alone does not mean the app currently consumes them. Client alignment should use the mounted routes and schemas above as its implementation source of truth.
