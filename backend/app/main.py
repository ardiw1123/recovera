from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.concurrency import run_in_threadpool
from fastapi.middleware.cors import CORSMiddleware

from app.ai.engine import AIEngine
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
    # Gagal muat model -> otomatis rule-based; API tidak pernah crash saat startup
    app.state.ai = await run_in_threadpool(
        AIEngine, use_ml=settings.use_ml_model
    )
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
    allow_origin_regex=r"^https?://(localhost|127\.0\.0\.1)(:\d+)?$",
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


@app.get(
    "/v1/models",
    tags=["ai"],
)
async def list_ai_models() -> dict:
    """Compatibility endpoint for AI model discovery tools probing port 8000."""
    ai_engine = getattr(app.state, "ai", None)
    return {
        "object": "list",
        "data": [
            {
                "id": "pricing_model",
                "object": "model",
                "owned_by": "recovera",
                "status": "active" if ai_engine and ai_engine.pricing else "heuristic",
            },
            {
                "id": "ranking_model",
                "object": "model",
                "owned_by": "recovera",
                "status": "active" if ai_engine and ai_engine.ranking else "heuristic",
            },
        ],
    }


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
