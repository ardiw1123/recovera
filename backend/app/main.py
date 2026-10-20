from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import get_settings
from app.core.exceptions import register_exception_handlers
from app.database import init_db
from app.schemas.envelope import ResponseEnvelope, wrap_success

# Routers
from app.routers import (
    ai,
    auth,
    blockchain,
    devices,
    donations,
    feedback,
    listings,
    notifications,
    orders,
    products,
    profile,
    rates,
)

settings = get_settings()


@asynccontextmanager
async def lifespan(app: FastAPI):
    init_db()
    yield


app = FastAPI(
    title=settings.app_name,
    version="1.0.0",
    description="Recovera B2B Near-Expiry Food Liquidation & Diversion API",
    docs_url="/docs",
    redoc_url="/redoc",
    openapi_url="/openapi.json",
    lifespan=lifespan,
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origin_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Register uniform envelope error handlers
register_exception_handlers(app)


@app.get(
    "/health",
    tags=["health"],
    response_model=ResponseEnvelope[dict],
)
async def health_check() -> dict:
    return wrap_success({
        "status": "healthy",
        "app": settings.app_name,
        "environment": settings.environment,
    })


# Include route modules
app.include_router(auth.router)
app.include_router(profile.router)
app.include_router(products.router)
app.include_router(listings.router)
app.include_router(ai.router)
app.include_router(orders.router)
app.include_router(donations.router)
app.include_router(blockchain.router)
app.include_router(rates.router)
app.include_router(notifications.router)
app.include_router(devices.router)
app.include_router(feedback.router)
