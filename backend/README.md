# Recovera Backend API

FastAPI backend service for **Recovera (B2B Near-Expiry Food Liquidation & Diversion Platform)**.

Designed with a modular, scalable architecture supporting both local development (SQLite/PostgreSQL) and production deployment (Docker & Docker Compose).

---

## 1. Architecture & Project Structure

The project follows domain-driven separation of concerns:

```
backend/
├── app/
│   ├── core/                  # Security (bcrypt, JWT), dependencies, custom error handlers
│   │   ├── dependencies.py    # Annotated dependencies (DbSessionDep, CurrentUserDep, role guards)
│   │   ├── exceptions.py      # Standard envelope error handlers
│   │   └── security.py        # Password hashing, JWT token handling (HS256)
│   ├── models/                # SQLAlchemy ORM models (13 tables from schema spec)
│   │   ├── donation.py        # Offtaker, Donation
│   │   ├── feedback.py        # CourseFeedback
│   │   ├── listing.py         # Listing, Offer
│   │   ├── notification.py    # Notification
│   │   ├── order.py           # Order
│   │   ├── product.py         # Product
│   │   └── user.py            # User, Seller, Buyer, RefreshToken, DeviceToken
│   ├── routers/               # API route controllers with router-level tags and prefixes
│   │   ├── ai.py              # /ai/invoice, /ai/price-advice
│   │   ├── auth.py            # /auth/register, /auth/login, /auth/refresh, /auth/logout
│   │   ├── blockchain.py      # /blockchain/verify/{tx_hash}
│   │   ├── devices.py         # /devices
│   │   ├── donations.py       # /donations/{id}/certificate
│   │   ├── feedback.py        # /feedback
│   │   ├── listings.py        # /listings, /listings/my, /listings/{id}, /listings/{id}/buy
│   │   ├── notifications.py   # /notifications, /notifications/{id}/read
│   │   ├── orders.py          # /orders, /orders/{id}, /orders/{id}/status
│   │   ├── products.py        # /products
│   │   ├── profile.py         # /profile (GET, PATCH)
│   │   └── rates.py           # /rates
│   ├── schemas/               # Pydantic v2 validation models and response envelopes
│   │   ├── envelope.py        # Standard API envelope response models
│   │   └── ...
│   ├── services/              # Pure business logic separated from HTTP controllers
│   │   ├── ai_service.py      # OCR parsing & price advisor logic
│   │   ├── auth_service.py    # Registration, login, token rotation
│   │   ├── donation_service.py# ESG certificate & blockchain verification
│   │   ├── listing_service.py # Dutch auction dynamic pricing & multi-timezone
│   │   └── order_service.py   # Concurrency-safe Buy Now transactions
│   ├── config.py              # Environment configuration via Pydantic Settings
│   ├── database.py            # SQLAlchemy database engine and session factory
│   └── main.py                # FastAPI app entrypoint, CORS, lifespan
├── alembic/                   # Database migrations
├── tests/                     # Automated pytest suite
├── Dockerfile                 # Container image specification
├── docker-compose.yml         # Container orchestration (API + PostgreSQL)
├── requirements.txt           # Python package dependencies
├── pyproject.toml             # Project metadata and tooling config
└── README.md
```

---

## 2. API Envelope Specification

All API endpoints return consistent envelope JSON responses following `docs/recovera-prd-full-platform.md`:

### Success Envelope
```json
{
  "success": true,
  "data": { ... }
}
```

### Error Envelope
```json
{
  "success": false,
  "error": {
    "code": "ERROR_CODE",
    "message": "Human-readable explanation of error"
  }
}
```

---

## 3. Endpoints Overview

| Tag | Method | Path | Role | Description |
|---|---|---|---|---|
| `auth` | `POST` | `/auth/register` | Public | Register seller or buyer account |
| `auth` | `POST` | `/auth/login` | Public | Authenticate and obtain JWT access & refresh tokens |
| `auth` | `POST` | `/auth/refresh` | Public | Rotate refresh token and obtain new access token |
| `auth` | `POST` | `/auth/logout` | Authenticated | Revoke refresh token session |
| `profile` | `GET` | `/profile` | Authenticated | Retrieve current user profile (seller/buyer info) |
| `profile` | `PATCH` | `/profile` | Authenticated | Update user and profile details |
| `products` | `GET` | `/products` | Public / All | Browse master product catalog |
| `products` | `POST` | `/products` | Seller | Add new master product |
| `listings` | `GET` | `/listings` | Buyer / All | Search listings with distance/price/expiry filters |
| `listings` | `POST` | `/listings` | Seller | Create a new Dutch auction lot |
| `listings` | `GET` | `/listings/my` | Seller | Retrieve listings owned by authenticated seller |
| `listings` | `GET` | `/listings/{id}` | All | Listing detail with real-time Dutch price & timezones |
| `listings` | `PATCH` | `/listings/{id}` | Seller | Update stock quantity or reserve price |
| `listings` | `POST` | `/listings/{id}/buy` | Buyer | Buy Now purchase with biometric confirmation |
| `ai` | `POST` | `/ai/invoice` | Seller | Multipart invoice upload -> extracted products |
| `ai` | `POST` | `/ai/price-advice` | Seller | Rule-based dynamic price recommendation & rationale |
| `orders` | `GET` | `/orders` | Authenticated | List purchase or sales history |
| `orders` | `GET` | `/orders/{id}` | Authenticated | Order detail and pickup coordinates |
| `orders` | `PATCH` | `/orders/{id}/status` | Authenticated | Update status (`picked_up`, `completed`) |
| `donations` | `GET` | `/donations/{id}/certificate` | All | ESG certificate (London time, USD/EUR/GBP, TX hash) |
| `blockchain`| `GET` | `/blockchain/verify/{tx_hash}`| All | Verify certificate hash on BOT Chain Testnet |
| `rates` | `GET` | `/rates` | All | Cached exchange rates (IDR -> USD, EUR, GBP) |
| `notifications` | `GET` | `/notifications` | Authenticated | In-app notification inbox |
| `notifications` | `PATCH`| `/notifications/{id}/read`| Authenticated | Mark notification as read |
| `devices` | `POST` | `/devices` | Authenticated | Register FCM device token |
| `feedback` | `POST` | `/feedback` | Authenticated | Submit PAM course feedback |

Interactive Swagger documentation is available at `/docs` and ReDoc at `/redoc`.

---

## 4. Local Development Setup

### Prerequisites
- Python 3.10+
- `pip`

### Step 1: Install Dependencies
```bash
pip install -r requirements.txt
```

### Step 2: Environment Configuration
Copy `.env.example` to `.env`:
```bash
cp .env.example .env
```
By default, `DATABASE_URL` is set to `sqlite:///./recovera.db`, so no local PostgreSQL installation is required to start developing immediately.

### Step 3: Run the Development Server
Using FastAPI CLI:
```bash
fastapi dev app/main.py
```
Or with Uvicorn:
```bash
uvicorn app.main:app --reload --port 8000
```
The API will be accessible at `http://localhost:8000`.

### Step 4: Run Tests
```bash
pytest tests -v
```

---

## 5. Docker & Containerization

### Run with Docker Compose (API + PostgreSQL)
Start both the PostgreSQL database and FastAPI service:
```bash
docker compose up --build
```
This automatically configures:
- FastAPI container on port `8000` with hot-reloading
- PostgreSQL 16 container on port `5432` with health checks and persistent volume storage

### Build Docker Image Standalone
```bash
docker build -t recovera-api .
docker run -p 8000:8000 -e DATABASE_URL=sqlite:///./recovera.db recovera-api
```
