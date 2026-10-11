from typing import Annotated
from fastapi import APIRouter, Body, Query, status

from app.core.dependencies import DbSessionDep, RequireSellerDep
from app.models.product import Product
from app.schemas.envelope import ResponseEnvelope, wrap_success
from app.schemas.product import ProductCreate, ProductResponse

router = APIRouter(prefix="/products", tags=["products"])


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
