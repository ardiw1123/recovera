import hashlib
import time
from typing import Annotated
from urllib.parse import quote
import httpx
from fastapi import APIRouter, Body, File, Query, UploadFile, status

from app.core.dependencies import DbSessionDep, RequireSellerDep
from app.models.product import Product
from app.schemas.envelope import ResponseEnvelope, wrap_success
from app.schemas.product import ProductCreate, ProductResponse
from app.config import get_settings
from app.core.exceptions import AppException

router = APIRouter(prefix="/products", tags=["products"])


@router.post("/upload-image", status_code=status.HTTP_201_CREATED)
async def upload_product_image(
    _: RequireSellerDep,
    file: Annotated[UploadFile, File()],
) -> dict:
    settings = get_settings()
    if not settings.supabase_url or not settings.supabase_secret_key:
        raise AppException("IMAGE_STORAGE_NOT_CONFIGURED", "Supabase Storage belum dikonfigurasi di server", status.HTTP_503_SERVICE_UNAVAILABLE)
    if not file.content_type or not file.content_type.startswith("image/"):
        raise AppException("INVALID_IMAGE_TYPE", "File harus berupa gambar", status.HTTP_422_UNPROCESSABLE_ENTITY)
    content = await file.read(2 * 1024 * 1024 + 1)
    if len(content) > 2 * 1024 * 1024:
        raise AppException("IMAGE_TOO_LARGE", "Ukuran foto maksimum 2 MB", status.HTTP_413_REQUEST_ENTITY_TOO_LARGE)

    timestamp = int(time.time())
    extension = {
        "image/jpeg": "jpg",
        "image/png": "png",
        "image/webp": "webp",
        "image/gif": "gif",
    }.get(file.content_type.lower())
    if extension is None:
        raise AppException("INVALID_IMAGE_TYPE", "Format foto yang didukung: JPEG, PNG, WebP, atau GIF", status.HTTP_422_UNPROCESSABLE_ENTITY)

    object_path = f"products/{timestamp}_{hashlib.sha256(content).hexdigest()[:16]}.{extension}"
    bucket = quote(settings.supabase_storage_bucket, safe="")
    encoded_path = quote(object_path, safe="/")
    storage_url = settings.supabase_url.rstrip("/")
    upload_url = f"{storage_url}/storage/v1/object/{bucket}/{encoded_path}"
    headers = {
        "apikey": settings.supabase_secret_key,
        "Content-Type": file.content_type,
        "x-upsert": "false",
    }
    # Legacy service_role keys are JWTs; current sb_secret keys are API keys, not JWTs.
    if settings.supabase_secret_key.startswith("eyJ"):
        headers["Authorization"] = f"Bearer {settings.supabase_secret_key}"
    try:
        async with httpx.AsyncClient(timeout=30) as client:
            response = await client.post(upload_url, headers=headers, content=content)
            response.raise_for_status()
    except (httpx.HTTPError, ValueError) as exc:
        raise AppException("IMAGE_UPLOAD_FAILED", "Foto produk gagal diunggah", status.HTTP_502_BAD_GATEWAY) from exc

    image_url = f"{storage_url}/storage/v1/object/public/{bucket}/{encoded_path}"
    return wrap_success({"image_url": image_url})


@router.get(
    "",
    status_code=status.HTTP_200_OK,
    response_model=ResponseEnvelope[list[ProductResponse]],
)
async def list_products(
    db: DbSessionDep,
    category: Annotated[str | None, Query(description="Filter by category")] = None,
    search: Annotated[str | None, Query(description="Search by product name or brand")] = None,
) -> dict:
    query = db.query(Product)
    if category:
        query = query.filter(Product.category.ilike(category.strip()))
    if search:
        search_pattern = f"%{search.strip()}%"
        query = query.filter(Product.name.ilike(search_pattern))

    products = query.all()
    results = [ProductResponse.model_validate(p, from_attributes=True).model_dump() for p in products]
    return wrap_success(results)


@router.post(
    "",
    status_code=status.HTTP_201_CREATED,
    response_model=ResponseEnvelope[ProductResponse],
)
async def create_product(
    db: DbSessionDep,
    _: RequireSellerDep,
    payload: Annotated[ProductCreate, Body()],
) -> dict:
    product = Product(
        sku=payload.sku,
        barcode=payload.barcode,
        name=payload.name,
        brand=payload.brand,
        category=payload.category,
        storage_type=payload.storage_type,
        default_unit=payload.default_unit,
        image_url=payload.image_url,
    )
    db.add(product)
    db.commit()
    db.refresh(product)
    return wrap_success(ProductResponse.model_validate(product, from_attributes=True).model_dump())
