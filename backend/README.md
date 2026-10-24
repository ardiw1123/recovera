# Recovera Backend API

FastAPI backend service for **Recovera (B2B Near-Expiry Food Liquidation & Diversion Platform)**.

Designed with a modular, scalable architecture supporting both local development (SQLite / Supabase PostgreSQL) and cloud container deployment (Docker) connected to managed Supabase PostgreSQL.

---

## 1. Architecture & Project Structure

The project follows domain-driven separation of concerns:

```
backend/
├── app/
│   ├── ai/                    # ML / heuristic pricing & buyer ranking engines
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
│   │   ├── ai_service.py      # OCR parsing & price advisor logic (Groq LLM)
│   │   ├── auth_service.py    # Registration, login, token rotation
│   │   ├── donation_service.py# ESG certificate & blockchain verification
│   │   ├── listing_service.py # Dutch auction dynamic pricing & multi-timezone
│   │   └── order_service.py   # Concurrency-safe Buy Now transactions
│   ├── config.py              # Environment configuration via Pydantic Settings
│   ├── database.py            # SQLAlchemy database engine and session factory
│   └── main.py                # FastAPI app entrypoint, CORS, lifespan
├── alembic/                   # Database migrations
├── tests/                     # Automated pytest suite
├── Dockerfile                 # Container image specification (Python 3.11-slim)
├── docker-compose.yml         # Container orchestration configuration
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
| `ai` | `POST` | `/ai/price-advice` | Seller | Dynamic price recommendation & ML prediction |
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
Konfigurasi database pada `.env`:
- **Supabase PostgreSQL (Direkomendasikan):**
  ```env
  DATABASE_URL=postgresql://postgres.[ref]:[PASSWORD]@aws-0-[region].pooler.supabase.com:6543/postgres
  ```
  *(Catatan: Anda juga dapat menggunakan alias `SUPABASE_DATABASE_URL`).*
- **SQLite (Fallback Pengembangan Lokal):**
  ```env
  DATABASE_URL=sqlite:///./recovera.db
  ```
- **Kredensial AI & Layanan Eksternal:**
  ```env
  GROQ_API_KEY=gsk_...
  SECRET_KEY=your-secure-random-secret-key
  ```

### Step 3: Menjalankan Migrasi Database (Alembic)
Terapkan migrasi skema tabel ke instance Supabase PostgreSQL Anda:
```bash
alembic upgrade head
```

### Step 4: Menjalankan Server Pengembangan
Menggunakan Uvicorn:
```bash
uvicorn app.main:app --reload --port 8000
```
API akan aktif dan dapat diakses di `http://localhost:8000` (Swagger docs di `http://localhost:8000/docs`).

### Step 5: Menjalankan Pengujian Otomatis
```bash
pytest tests -v
```

---

## 5. Docker Deployment Guide (Dengan Supabase PostgreSQL)

Aplikasi Recovera menggunakan **Supabase PostgreSQL** sebagai basis data cloud terkelola (bukan database PostgreSQL lokal di container). Oleh karena itu, deployment Docker **hanya perlu menjalankan container service FastAPI (`api`)** yang langsung terhubung ke instance Supabase melalui jaringan internet.

### Persyaratan Awal (Prerequisites)
1. [Docker](https://docs.docker.com/get-docker/) terinstal dan aktif.
2. File `.env` di folder `backend/` telah dikonfigurasi dengan string koneksi Supabase Anda:
   ```env
   ENVIRONMENT=production
   DATABASE_URL=postgresql://postgres.[ref]:[YOUR_PASSWORD]@aws-0-[region].pooler.supabase.com:6543/postgres
   SECRET_KEY=3862b7b8dde0ec462eb4bc7df030c36943ffc2fb13082318bcab35a18c8cd25a
   GROQ_API_KEY=gsk_...
   CORS_ORIGINS=*
   USE_ML_MODEL=true
   ```

> [!TIP]
> **Panduan Port Supabase Connection:**
> - **Port 6543 (Transaction Pooler - Sangat Direkomendasikan):** Menggunakan Supavisor pooler untuk mencegah kehabisan koneksi (*connection exhaustion*) saat container melayani banyak request bersamaan.
> - **Port 5432 (Session Mode / Direct):** Digunakan jika Anda menjalankan operasi DDL atau migrasi schema yang membutuhkan fitur sesi khusus.

---

### Opsi A: Menjalankan Container Mandiri (Docker Standalone) — Direkomendasikan

Metode ini paling efisien untuk VPS (Ubuntu/Debian) atau cloud server.

#### 1. Build Docker Image
Jalankan perintah berikut di dalam direktori `backend/`:
```bash
docker build -t recovera-api .
```

#### 2. Jalankan Container dengan Membaca File `.env`
```bash
docker run -d \
  --name recovera-backend \
  -p 8000:8000 \
  --restart unless-stopped \
  --env-file .env \
  recovera-api
```

#### 3. Alternatif: Melewatkan Environment Variable Langsung
```bash
docker run -d \
  --name recovera-backend \
  -p 8000:8000 \
  --restart unless-stopped \
  -e ENVIRONMENT=production \
  -e DATABASE_URL="postgresql://postgres.[ref]:[PASSWORD]@aws-0-[region].pooler.supabase.com:6543/postgres" \
  -e GROQ_API_KEY="gsk_..." \
  -e SECRET_KEY="your-secure-random-secret-key" \
  recovera-api
```

#### 4. Memeriksa Status & Log Container
```bash
# Cek apakah container berjalan lancar
docker ps

# Pantau log aplikasi secara real-time
docker logs -f recovera-backend
```
Setelah berjalan, API dapat diakses di port `8000`. Endpoint `/docs` dapat digunakan untuk health check.

#### 5. Menghentikan atau Me-restart Container
```bash
# Restart container
docker restart recovera-backend

# Hentikan dan hapus container
docker stop recovera-backend
docker rm recovera-backend
```

---

### Opsi B: Menjalankan Migrasi Database (Alembic) di Supabase via Docker

Jika Anda baru pertama kali menghubungkan ke database Supabase atau ada perubahan skema tabel baru:
```bash
# Jalankan migrasi di dalam container yang sedang berjalan
docker exec -it recovera-backend alembic upgrade head
```

---

### Opsi C: Menjalankan Khusus Service API pada Docker Compose

Karena database PostgreSQL sudah berada di Supabase (cloud), Anda tidak perlu menyalakan container `db` bawaan `docker-compose.yml`. Anda cukup mengeksekusi service `api`:

```bash
docker compose run --rm --service-ports api uvicorn app.main:app --host 0.0.0.0 --port 8000
```

---

### Opsi D: Deployment ke Cloud PaaS (Railway, Render, Fly.io) Menggunakan Docker

Bila ingin mendepoy image Docker ke platform cloud publik:
1. Hubungkan repository GitHub ke layanan cloud pilihan (**Railway**, **Render**, atau **Fly.io**).
2. Layanan akan otomatis mendeteksi `Dockerfile` di folder `backend/`.
3. Masukkan variabel lingkungan pada dashboard platform:
   - `ENVIRONMENT` = `production`
   - `DATABASE_URL` = `postgresql://postgres.[ref]:[PASSWORD]@aws-0-[region].pooler.supabase.com:6543/postgres`
   - `GROQ_API_KEY` = `gsk_...`
   - `SECRET_KEY` = string rahasia acak
   - `PORT` = `8000` (atau biarkan default platform)
4. Deploy akan otomatis berjalan dengan protokol HTTPS publik. URL backend tersebut kemudian siap dipasang pada aplikasi Flutter Recovera (`ApiConstants.baseUrl`).
