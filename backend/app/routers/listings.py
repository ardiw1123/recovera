import logging
from datetime import date, datetime, timedelta, timezone
from typing import Annotated
from fastapi import APIRouter, Body, Path, Query, Request, status
from sqlalchemy.orm import joinedload

logger = logging.getLogger(__name__)

from app.core.dependencies import CurrentUserDep, DbSessionDep, RequireBuyerDep, RequireSellerDep
from app.core.exceptions import AppException
from app.models.listing import Listing
from app.models.order import Order
from app.models.product import Product
from app.models.user import Seller
from app.schemas.envelope import ResponseEnvelope, wrap_success
from app.schemas.listing import (
    ListingBuyRequest,
    ListingCreate,
    ListingDetailResponse,
    ListingResponse,
    ListingUpdate,
    SellerInventoryDraftCreate,
    SellerInventoryDraftUpdate,
    SellerPublishRequest,
)
from app.schemas.order import OrderResponse
from app.schemas.product import ProductResponse
from app.services.ai_service import (
    calculate_price_advice,
    match_and_create_offers_for_listing,
)
from app.services.listing_service import (
    calculate_current_dutch_price,
    format_multi_timezone,
    get_initial_discount_percentage,
    search_listings,
)
from app.services.order_service import execute_buy_now
from app.services.push_service import send_to_user
from app.models.user import Buyer

router = APIRouter(prefix="/listings", tags=["listings"])


def _owned_listing(db, user_id: int, listing_id: int) -> tuple[Seller, Listing]:
    seller = db.query(Seller).filter(Seller.user_id == user_id).first()
    listing = db.query(Listing).filter(Listing.id == listing_id).first()
    if not listing:
        raise AppException("LISTING_NOT_FOUND", "Listing not found", status.HTTP_404_NOT_FOUND)
    if not seller or listing.seller_id != seller.id:
        raise AppException("FORBIDDEN", "You are not authorized to access this listing", status.HTTP_403_FORBIDDEN)
    return seller, listing


def _validate_inventory_listing(listing: Listing) -> list[str]:
    errors = []
    product = listing.product
    if not product or not product.name.strip() or not product.category.strip():
        errors.append("Product name and category are required")
    if not product or not product.image_url or not str(product.image_url).strip():
        errors.append("Foto produk wajib diunggah")
    if listing.qty <= 0:
        errors.append("Quantity must be greater than zero")
    if listing.expiry_date <= date.today():
        errors.append("Expiry date must be in the future")
    elif (listing.expiry_date - date.today()).days < 30:
        errors.append("Masa simpan minimal 30 hari")
    if listing.min_price > listing.start_price or listing.start_price > listing.normal_price:
        errors.append("Prices must satisfy minimum price <= starting price <= normal price")
    return errors


@router.get("/seller/inventory", response_model=ResponseEnvelope[list[ListingResponse]])
async def get_seller_inventory(db: DbSessionDep, seller_user: RequireSellerDep) -> dict:
    seller = db.query(Seller).filter(Seller.user_id == seller_user.id).first()
    if not seller:
        return wrap_success([])
    today = date.today()
    items = db.query(Listing).filter(Listing.seller_id == seller.id).order_by(Listing.created_at.desc()).all()
    for item in items:
        if item.qty <= 0 and item.status == "active":
            item.status = "sold"
        elif item.expiry_date < today and item.status == "active":
            item.status = "expired"
    db.commit()
    return wrap_success([
        _format_listing_response(item, *calculate_current_dutch_price(item)) for item in items
    ])


@router.get("/seller/dashboard", response_model=ResponseEnvelope[dict])
async def get_seller_dashboard(db: DbSessionDep, seller_user: RequireSellerDep) -> dict:
    seller = db.query(Seller).filter(Seller.user_id == seller_user.id).first()
    if not seller:
        return wrap_success({
            "company_name": "",
            "active_listings_count": 0,
            "prev_month_active_count": 0,
            "current_month_orders_count": 0,
            "prev_month_orders_count": 0,
            "near_expiry_listings": [],
            "recent_activities": [],
            "esg_certificate_count": 0,
            "total_carbon_saved": 0.0,
        })

    today = date.today()
    first_day_this_month = today.replace(day=1)
    if first_day_this_month.month == 1:
        first_day_prev_month = date(today.year - 1, 12, 1)
    else:
        first_day_prev_month = date(today.year, first_day_this_month.month - 1, 1)

    # Timezone-aware UTC timestamps for PostgreSQL queries
    start_this_month = datetime(first_day_this_month.year, first_day_this_month.month, 1, tzinfo=timezone.utc)
    start_prev_month = datetime(first_day_prev_month.year, first_day_prev_month.month, 1, tzinfo=timezone.utc)

    # active_listings_count: listing milik seller ini yang statusnya 'active'
    active_listings_count = db.query(Listing).filter(
        Listing.seller_id == seller.id,
        Listing.status == 'active'
    ).count()

    # prev_month_active_count: listing milik seller ini yang statusnya 'active' dan created_at di bulan lalu
    prev_month_active_count = db.query(Listing).filter(
        Listing.seller_id == seller.id,
        Listing.status == 'active',
        Listing.created_at >= start_prev_month,
        Listing.created_at < start_this_month
    ).count()

    # current_month_orders_count: order yang listing.seller_id = seller ini, dan orders.created_at di bulan ini
    current_month_orders_count = db.query(Order).join(Listing).filter(
        Listing.seller_id == seller.id,
        Order.created_at >= start_this_month
    ).count()

    # prev_month_orders_count: sama seperti di atas tapi untuk bulan lalu
    prev_month_orders_count = db.query(Order).join(Listing).filter(
        Listing.seller_id == seller.id,
        Order.created_at >= start_prev_month,
        Order.created_at < start_this_month
    ).count()

    # near_expiry_listings: 3 listing aktif milik seller ini, urutkan berdasarkan expiry_date dari yang terdekat
    near_expiry = (
        db.query(Listing)
        .options(joinedload(Listing.product))
        .filter(Listing.seller_id == seller.id, Listing.status == 'active')
        .order_by(Listing.expiry_date.asc())
        .limit(3)
        .all()
    )
    near_expiry_listings = []
    for listing in near_expiry:
        days_remaining = (listing.expiry_date - today).days
        product = listing.product
        near_expiry_listings.append({
            "id": listing.id,
            "product_name": product.name if product else "Produk Tanpa Nama",
            "days_remaining": max(days_remaining, 0),
            "qty": listing.qty,
            "unit": product.default_unit if product else "pcs",
            "category": product.category if product else "Umum",
        })

    # recent_activities: gabungkan log dari order terbaru seller (stok terjual) dan listing terbaru (upload stok), urutkan berdasarkan waktu terbaru, ambil 5 teratas
    recent_orders = (
        db.query(Order)
        .options(joinedload(Order.listing).joinedload(Listing.product))
        .join(Listing)
        .filter(Listing.seller_id == seller.id)
        .order_by(Order.created_at.desc())
        .limit(5)
        .all()
    )

    recent_listings = (
        db.query(Listing)
        .options(joinedload(Listing.product))
        .filter(Listing.seller_id == seller.id)
        .order_by(Listing.created_at.desc())
        .limit(5)
        .all()
    )

    raw_activities = []
    for order in recent_orders:
        product = order.listing.product if (order.listing and order.listing.product) else None
        order_dt = order.created_at
        if order_dt and order_dt.tzinfo is None:
            order_dt = order_dt.replace(tzinfo=timezone.utc)
        raw_activities.append({
            "sort_dt": order_dt or datetime.min.replace(tzinfo=timezone.utc),
            "type": "sold",
            "title": f"{product.name if product else 'Produk'} terjual",
            "subtitle": "Berhasil dicairkan",
            "timestamp": order_dt.isoformat() if order_dt else "",
        })

    for listing in recent_listings:
        product = listing.product
        listing_dt = listing.created_at
        if listing_dt and listing_dt.tzinfo is None:
            listing_dt = listing_dt.replace(tzinfo=timezone.utc)
        raw_activities.append({
            "sort_dt": listing_dt or datetime.min.replace(tzinfo=timezone.utc),
            "type": "uploaded",
            "title": f"{product.name if product else 'Produk'} ditambahkan",
            "subtitle": "Berhasil diunggah",
            "timestamp": listing_dt.isoformat() if listing_dt else "",
        })

    raw_activities.sort(key=lambda x: x["sort_dt"], reverse=True)
    recent_activities = [
        {
            "type": item["type"],
            "title": item["title"],
            "subtitle": item["subtitle"],
            "timestamp": item["timestamp"],
        }
        for item in raw_activities[:5]
    ]

    from app.models.donation import Donation
    esg_donations = db.query(Donation).join(Listing).filter(Listing.seller_id == seller.id).all()
    esg_count = len(esg_donations)
    total_carbon = sum(float(d.carbon_saved_kg) for d in esg_donations)

    data = {
        "company_name": seller.company_name,
        "active_listings_count": active_listings_count,
        "prev_month_active_count": prev_month_active_count,
        "current_month_orders_count": current_month_orders_count,
        "prev_month_orders_count": prev_month_orders_count,
        "near_expiry_listings": near_expiry_listings,
        "recent_activities": recent_activities,
        "esg_certificate_count": esg_count,
        "total_carbon_saved": round(total_carbon, 2),
    }

    return wrap_success(data)


@router.post("/seller/inventory/drafts", status_code=status.HTTP_201_CREATED)
async def create_seller_inventory_draft(
    request: Request,
    db: DbSessionDep,
    seller_user: RequireSellerDep,
    payload: Annotated[SellerInventoryDraftCreate, Body()],
) -> dict:
    try:
        seller = db.query(Seller).filter(Seller.user_id == seller_user.id).first()
        if not seller:
            raise AppException("SELLER_NOT_FOUND", "Seller profile is not configured", status.HTTP_400_BAD_REQUEST)
        
        if payload.expiry_date <= date.today():
            raise AppException("INVALID_EXPIRY_DATE", "Expiry date must be in the future", status.HTTP_422_UNPROCESSABLE_ENTITY)

        if payload.qty <= 0:
            raise AppException("INVALID_QUANTITY", "Quantity must be greater than zero", status.HTTP_422_UNPROCESSABLE_ENTITY)
        
        if payload.normal_price <= 0 or payload.min_price <= 0:
            raise AppException("INVALID_PRICE", "Prices must be greater than zero", status.HTTP_422_UNPROCESSABLE_ENTITY)
        
        if payload.min_price > payload.normal_price:
            raise AppException("INVALID_PRICE_RANGE", "Minimum price cannot exceed normal price", status.HTTP_422_UNPROCESSABLE_ENTITY)

        if (payload.expiry_date - date.today()).days < 30:
            raise AppException("INVALID_EXPIRY_DATE", "Masa simpan minimal 30 hari agar lelang Dutch Auction berjalan. Pilih tanggal kedaluwarsa yang lebih jauh.", status.HTTP_422_UNPROCESSABLE_ENTITY)

        if not payload.image_url or not str(payload.image_url).strip():
            raise AppException("IMAGE_REQUIRED", "Foto produk wajib diunggah", status.HTTP_422_UNPROCESSABLE_ENTITY)

        product = db.query(Product).filter(Product.sku == payload.sku).first()
        if product is None:
            product = Product(
                sku=payload.sku, 
                barcode=payload.barcode, 
                name=payload.name.strip(),
                brand=payload.brand, 
                category=payload.category.strip(),
                storage_type=payload.storage_type, 
                default_unit=payload.default_unit,
                image_url=str(payload.image_url) if payload.image_url else None,
            )
            db.add(product)
            db.flush()
        elif payload.image_url and not product.image_url:
            product.image_url = str(payload.image_url)

        ai_engine = getattr(request.app.state, "ai", None)
        suggested = calculate_price_advice(
            normal_price=payload.normal_price,
            expiry_date_str=payload.expiry_date.isoformat(),
            category=payload.category,
            qty=payload.qty,
            storage_type=payload.storage_type,
            min_price=payload.min_price,
            ai_engine=ai_engine,
        )
        now = datetime.now(timezone.utc)
        listing = Listing(
            product_id=product.id, seller_id=seller.id, batch_number=payload.batch_number,
            qty=payload.qty, normal_price=payload.normal_price,
            start_price=suggested.suggested_price, min_price=payload.min_price,
            drop_interval_minutes=60, drop_percentage=2.5,
            expiry_date=payload.expiry_date, auction_start_at=now,
            auction_end_at=datetime.combine(payload.expiry_date, datetime.min.time(), tzinfo=timezone.utc),
            status="draft",
        )
        if listing.min_price > listing.start_price:
            raise AppException("INVALID_MIN_PRICE", "Minimum price cannot exceed the recommended starting price", status.HTTP_422_UNPROCESSABLE_ENTITY)
        
        db.add(listing)
        db.commit()
        db.refresh(listing)
        errors = _validate_inventory_listing(listing)
        return wrap_success({
            "listing": _format_listing_response(listing, *calculate_current_dutch_price(listing)),
            "validation": {"valid": not errors, "errors": errors},
            "price_recommendation": suggested.model_dump(),
        })
    except AppException:
        db.rollback()
        raise
    except Exception as e:
        db.rollback()
        raise AppException(
            "DRAFT_CREATION_FAILED", 
            f"Failed to create inventory draft: {str(e)}", 
            status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@router.patch("/seller/inventory/{listing_id}")
async def update_seller_inventory_draft(
    db: DbSessionDep,
    seller_user: RequireSellerDep,
    listing_id: Annotated[int, Path(ge=1)],
    payload: Annotated[SellerInventoryDraftUpdate, Body()],
) -> dict:
    try:
        _, listing = _owned_listing(db, seller_user.id, listing_id)
        if listing.status not in {"draft", "review"}:
            raise AppException("LISTING_NOT_EDITABLE", "Only drafts can be edited", status.HTTP_409_CONFLICT)
        
        values = payload.model_dump(exclude_unset=True)
        
        # Update product fields
        for field in ("name", "category", "storage_type", "default_unit", "image_url", "brand"):
            if field in values:
                value = values[field]
                if field == "image_url" and value:
                    setattr(listing.product, field, str(value))
                elif field == "image_url" and value is None:
                    # Allow clearing image_url
                    pass
                else:
                    setattr(listing.product, field, value)
        
        # Update listing fields with validation
        if "qty" in values and values["qty"] <= 0:
            raise AppException("INVALID_QUANTITY", "Quantity must be greater than zero", status.HTTP_422_UNPROCESSABLE_ENTITY)
        
        if "normal_price" in values and values["normal_price"] <= 0:
            raise AppException("INVALID_PRICE", "Normal price must be greater than zero", status.HTTP_422_UNPROCESSABLE_ENTITY)
        
        if "min_price" in values and values["min_price"] <= 0:
            raise AppException("INVALID_PRICE", "Minimum price must be greater than zero", status.HTTP_422_UNPROCESSABLE_ENTITY)
        
        if "expiry_date" in values:
            if values["expiry_date"] <= date.today():
                raise AppException("INVALID_EXPIRY_DATE", "Expiry date must be in the future", status.HTTP_422_UNPROCESSABLE_ENTITY)
            if (values["expiry_date"] - date.today()).days < 30:
                raise AppException("INVALID_EXPIRY_DATE", "Masa simpan minimal 30 hari agar lelang Dutch Auction berjalan. Pilih tanggal kedaluwarsa yang lebih jauh.", status.HTTP_422_UNPROCESSABLE_ENTITY)
        
        for field in ("batch_number", "qty", "normal_price", "start_price", "min_price", "expiry_date"):
            if field in values:
                setattr(listing, field, values[field])
        
        errors = _validate_inventory_listing(listing)
        if errors:
            listing.status = "draft"
        else:
            listing.status = "review"
        
        db.commit()
        db.refresh(listing)
        return wrap_success({
            "listing": _format_listing_response(listing, *calculate_current_dutch_price(listing)),
            "validation": {"valid": not errors, "errors": errors},
        })
    except AppException:
        db.rollback()
        raise
    except Exception as e:
        db.rollback()
        raise AppException(
            "DRAFT_UPDATE_FAILED",
            f"Failed to update inventory draft: {str(e)}",
            status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@router.delete("/seller/inventory/{listing_id}", status_code=status.HTTP_200_OK)
async def delete_seller_inventory_draft(
    db: DbSessionDep,
    seller_user: RequireSellerDep,
    listing_id: Annotated[int, Path(ge=1)],
) -> dict:
    _, listing = _owned_listing(db, seller_user.id, listing_id)
    if listing.status not in {"draft", "review"}:
        raise AppException("LISTING_NOT_DELETABLE", "Hanya produk berstatus draft yang dapat dihapus", status.HTTP_409_CONFLICT)
    db.delete(listing)
    db.commit()
    return wrap_success({"deleted": True, "id": listing_id})


@router.post("/seller/inventory/{listing_id}/validate")
async def validate_seller_inventory_draft(
    db: DbSessionDep,
    seller_user: RequireSellerDep,
    listing_id: Annotated[int, Path(ge=1)],
) -> dict:
    _, listing = _owned_listing(db, seller_user.id, listing_id)
    errors = _validate_inventory_listing(listing)
    if not errors and listing.status == "draft":
        listing.status = "review"
        db.commit()
        db.refresh(listing)
    return wrap_success({"valid": not errors, "errors": errors, "status": listing.status})


@router.post("/seller/inventory/{listing_id}/recommendation")
async def recommend_seller_inventory_price(
    request: Request,
    db: DbSessionDep,
    seller_user: RequireSellerDep,
    listing_id: Annotated[int, Path(ge=1)],
) -> dict:
    _, listing = _owned_listing(db, seller_user.id, listing_id)
    ai_engine = getattr(request.app.state, "ai", None)
    advice = calculate_price_advice(
        normal_price=float(listing.normal_price),
        expiry_date_str=listing.expiry_date.isoformat(),
        category=listing.product.category if listing.product else None,
        qty=listing.qty,
        storage_type=listing.product.storage_type if listing.product else "ambient",
        min_price=float(listing.min_price),
        ai_engine=ai_engine,
    )
    lower = advice.suggested_price * 0.8
    upper = advice.suggested_price * 1.2
    warning = not lower <= float(listing.start_price) <= upper
    return wrap_success({"recommendation": advice.model_dump(), "price_warning": warning,
                         "accepted_range": {"minimum": round(lower, 2), "maximum": round(upper, 2)}})


@router.post("/seller/inventory/{listing_id}/publish", response_model=ResponseEnvelope[ListingResponse])
async def publish_seller_inventory_listing(
    request: Request,
    db: DbSessionDep,
    seller_user: RequireSellerDep,
    listing_id: Annotated[int, Path(ge=1)],
    payload: Annotated[SellerPublishRequest, Body()] = SellerPublishRequest(),
) -> dict:
    _, listing = _owned_listing(db, seller_user.id, listing_id)
    errors = _validate_inventory_listing(listing)
    if errors:
        raise AppException("LISTING_VALIDATION_FAILED", "; ".join(errors), status.HTTP_422_UNPROCESSABLE_ENTITY)
    
    ai_engine = getattr(request.app.state, "ai", None)
    advice = calculate_price_advice(
        normal_price=float(listing.normal_price),
        expiry_date_str=listing.expiry_date.isoformat(),
        category=listing.product.category if listing.product else None,
        qty=listing.qty,
        storage_type=listing.product.storage_type if listing.product else "ambient",
        min_price=float(listing.min_price),
        ai_engine=ai_engine,
    )
    if not 0.8 * advice.suggested_price <= float(listing.start_price) <= 1.2 * advice.suggested_price and not payload.acknowledge_price_warning:
        raise AppException("PRICE_WARNING_ACK_REQUIRED", "Acknowledge the out-of-range price warning or adjust the starting price", status.HTTP_409_CONFLICT)
    
    listing.status = "active"
    db.commit()
    db.refresh(listing)

    # ── AI Ranking: Match Top-5 buyers & create offers ───────────────────────
    matching_summary = {"total_offers_sent": 0, "top_buyers": []}
    if ai_engine is not None:
        try:
            matching_summary = match_and_create_offers_for_listing(
                db=db,
                listing=listing,
                ai_engine=ai_engine,
                top_k=5,
            )
        except Exception as e:
            logger.error("AI matching on publish encountered an issue: %s", e)

    for match in matching_summary.get("top_buyers", []):
        buyer = db.query(Buyer).filter(Buyer.id == match.get("buyer_id")).first()
        if buyer:
            send_to_user(db, buyer.user_id, "Stok baru cocok untuk bisnis Anda", f"{listing.product.name if listing.product else 'Produk baru'} tersedia dari penjual yang cocok.", {"type": "new_listing", "listing_id": listing.id})

    return wrap_success(
        _format_listing_response(
            listing,
            *calculate_current_dutch_price(listing),
            matching_summary=matching_summary,
        )
    )


def _format_listing_response(item: Listing, cur_price: float, next_drop: str | None, distance: float | None = None,
                              match_score: float | None = None, discount_pct: float | None = None,
                              days_to_expiry: int | None = None, matching_summary: dict | None = None) -> dict:
    prod_data = ProductResponse.model_validate(item.product, from_attributes=True).model_dump() if item.product else None
    seller_data = item.seller

    orders = item.orders or []
    sold_qty = sum(o.qty for o in orders if o.status != 'cancelled')
    orders_count = len([o for o in orders if o.status != 'cancelled'])

    return ListingResponse(
        id=item.id,
        product_id=item.product_id,
        seller_id=item.seller_id,
        batch_number=item.batch_number,
        qty=item.qty,
        normal_price=float(item.normal_price),
        start_price=float(item.start_price),
        min_price=float(item.min_price),
        drop_interval_minutes=item.drop_interval_minutes,
        drop_percentage=float(item.drop_percentage),
        expiry_date=item.expiry_date.isoformat(),
        auction_start_at=item.auction_start_at.isoformat(),
        auction_end_at=item.auction_end_at.isoformat(),
        status=item.status,
        created_at=item.created_at.isoformat(),
        current_price=cur_price,
        sold_qty=sold_qty,
        orders_count=orders_count,
        next_drop_at=next_drop,
        auction_end_timezones=format_multi_timezone(item.auction_end_at),
        product=prod_data,
        seller_company=seller_data.company_name if seller_data else None,
        warehouse_lat=seller_data.warehouse_lat if seller_data else None,
        warehouse_lng=seller_data.warehouse_lng if seller_data else None,
        warehouse_city=seller_data.city if seller_data else None,
        distance_km=distance,
        match_score=match_score,
        discount_pct=discount_pct,
        days_to_expiry=days_to_expiry,
        matching_summary=matching_summary,
    ).model_dump()


@router.get(
    "",
    status_code=status.HTTP_200_OK,
    response_model=ResponseEnvelope[list[ListingResponse]],
)
async def list_listings(
    db: DbSessionDep,
    search: Annotated[str | None, Query(description="Search product name or brand")] = None,
    category: Annotated[str | None, Query(description="Filter by product category")] = None,
    lat: Annotated[float | None, Query(description="Buyer latitude for LBS distance filtering")] = None,
    lng: Annotated[float | None, Query(description="Buyer longitude for LBS distance filtering")] = None,
    radius_km: Annotated[float | None, Query(description="Maximum radius in km")] = None,
    max_price: Annotated[float | None, Query(description="Maximum price filter")] = None,
    min_days: Annotated[int | None, Query(description="Minimum remaining shelf life days")] = None,
    sort: Annotated[str | None, Query(description="Sort by: nearest, cheapest, expiring_soon")] = None,
    page: Annotated[int, Query(ge=1, description="Page number")] = 1,
    page_size: Annotated[int, Query(ge=1, le=100, description="Page size")] = 20,
) -> dict:
    results, _ = search_listings(
        db=db,
        search=search,
        category=category,
        lat=lat,
        lng=lng,
        radius_km=radius_km,
        max_price=max_price,
        min_days=min_days,
        sort=sort,
        page=page,
        page_size=page_size,
    )

    formatted = [
        _format_listing_response(
            r["listing"],
            r["current_price"],
            r["next_drop_at"],
            r["distance_km"],
            match_score=r.get("match_score"),
            discount_pct=r.get("discount_pct"),
            days_to_expiry=r.get("days_to_expiry"),
        )
        for r in results
    ]
    return wrap_success(formatted)


@router.post(
    "",
    status_code=status.HTTP_201_CREATED,
)
async def create_listing(
    request: Request,
    db: DbSessionDep,
    current_seller: RequireSellerDep,
    payload: Annotated[ListingCreate, Body()],
) -> dict:
    seller = db.query(Seller).filter(Seller.user_id == current_seller.id).first()
    if not seller:
        raise AppException(
            code="SELLER_NOT_FOUND",
            message="Seller profile must be configured before creating listings",
            status_code=status.HTTP_400_BAD_REQUEST,
        )

    product = db.query(Product).filter(Product.id == payload.product_id).first()
    if not product:
        raise AppException(
            code="PRODUCT_NOT_FOUND",
            message=f"Product with ID {payload.product_id} does not exist",
            status_code=status.HTTP_404_NOT_FOUND,
        )

    try:
        exp_date = date.fromisoformat(payload.expiry_date)
    except ValueError:
        raise AppException(
            code="INVALID_DATE_FORMAT",
            message="expiry_date must be in ISO format YYYY-MM-DD",
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        )

    if exp_date <= date.today():
        raise AppException(
            code="INVALID_EXPIRY_DATE",
            message="Expiry date must be in the future",
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        )

    now_utc = datetime.now(timezone.utc)
    start_at = (
        datetime.fromisoformat(payload.auction_start_at)
        if payload.auction_start_at
        else now_utc
    )
    if start_at.tzinfo is None:
        start_at = start_at.replace(tzinfo=timezone.utc)

    end_at = (
        datetime.fromisoformat(payload.auction_end_at)
        if payload.auction_end_at
        else datetime.combine(exp_date, datetime.min.time(), tzinfo=timezone.utc)
    )
    if end_at.tzinfo is None:
        end_at = end_at.replace(tzinfo=timezone.utc)

    # Calculate initial discount using AI if start_price not provided
    ai_engine = getattr(request.app.state, "ai", None)
    if payload.start_price is not None:
        start_price = payload.start_price
    else:
        advice = calculate_price_advice(
            normal_price=payload.normal_price,
            expiry_date_str=payload.expiry_date,
            category=product.category,
            qty=payload.qty,
            storage_type=product.storage_type or "ambient",
            min_price=payload.min_price,
            ai_engine=ai_engine,
        )
        start_price = advice.suggested_price

    if payload.min_price > start_price:
        raise AppException(
            code="INVALID_MIN_PRICE",
            message="Reserve min_price cannot exceed starting auction price",
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        )

    listing = Listing(
        product_id=product.id,
        seller_id=seller.id,
        batch_number=payload.batch_number,
        qty=payload.qty,
        normal_price=payload.normal_price,
        start_price=start_price,
        min_price=payload.min_price,
        drop_interval_minutes=payload.drop_interval_minutes,
        drop_percentage=payload.drop_percentage,
        expiry_date=exp_date,
        auction_start_at=start_at,
        auction_end_at=end_at,
        status="active",
    )
    db.add(listing)
    db.commit()
    db.refresh(listing)

    # ── AI Ranking: Match Top-5 buyers & create offers ───────────────────────
    matching_summary = {"total_offers_sent": 0, "top_buyers": []}
    if ai_engine is not None:
        try:
            matching_summary = match_and_create_offers_for_listing(
                db=db,
                listing=listing,
                ai_engine=ai_engine,
                top_k=5,
            )
        except Exception as e:
            logger.error("AI matching on create_listing encountered an issue: %s", e)

    for match in matching_summary.get("top_buyers", []):
        buyer = db.query(Buyer).filter(Buyer.id == match.get("buyer_id")).first()
        if buyer:
            send_to_user(db, buyer.user_id, "Stok baru cocok untuk bisnis Anda", f"{product.name} tersedia dari penjual yang cocok.", {"type": "new_listing", "listing_id": listing.id})

    cur_price, next_drop = calculate_current_dutch_price(listing)
    return wrap_success(
        _format_listing_response(
            listing,
            cur_price,
            next_drop,
            matching_summary=matching_summary,
        )
    )


@router.get(
    "/my",
    status_code=status.HTTP_200_OK,
    response_model=ResponseEnvelope[list[ListingResponse]],
)
async def get_my_listings(
    db: DbSessionDep,
    current_seller: RequireSellerDep,
) -> dict:
    seller = db.query(Seller).filter(Seller.user_id == current_seller.id).first()
    if not seller:
        return wrap_success([])

    listings = db.query(Listing).filter(Listing.seller_id == seller.id).order_by(Listing.created_at.desc()).all()
    formatted = []
    for item in listings:
        cur_price, next_drop = calculate_current_dutch_price(item)
        formatted.append(_format_listing_response(item, cur_price, next_drop))
    return wrap_success(formatted)


@router.get(
    "/{listing_id}",
    status_code=status.HTTP_200_OK,
    response_model=ResponseEnvelope[ListingDetailResponse],
)
async def get_listing_detail(
    db: DbSessionDep,
    listing_id: Annotated[int, Path(ge=1, description="Listing ID")],
) -> dict:
    listing = db.query(Listing).filter(Listing.id == listing_id).first()
    if not listing:
        raise AppException(
            code="LISTING_NOT_FOUND",
            message=f"Listing with ID {listing_id} not found",
            status_code=status.HTTP_404_NOT_FOUND,
        )

    cur_price, next_drop = calculate_current_dutch_price(listing)
    days_left = (listing.expiry_date - date.today()).days
    return wrap_success(_format_listing_response(
        listing, cur_price, next_drop,
        match_score=None,
        discount_pct=None,
        days_to_expiry=days_left,
    ))


@router.patch(
    "/{listing_id}",
    status_code=status.HTTP_200_OK,
    response_model=ResponseEnvelope[ListingResponse],
)
async def update_listing(
    db: DbSessionDep,
    current_seller: RequireSellerDep,
    listing_id: Annotated[int, Path(ge=1, description="Listing ID")],
    payload: Annotated[ListingUpdate, Body()],
) -> dict:
    seller = db.query(Seller).filter(Seller.user_id == current_seller.id).first()
    listing = db.query(Listing).filter(Listing.id == listing_id).first()
    if not listing:
        raise AppException(
            code="LISTING_NOT_FOUND",
            message=f"Listing #{listing_id} not found",
            status_code=status.HTTP_404_NOT_FOUND,
        )

    if not seller or listing.seller_id != seller.id:
        raise AppException(
            code="FORBIDDEN",
            message="You are not authorized to modify this listing",
            status_code=status.HTTP_403_FORBIDDEN,
        )

    if payload.qty is not None:
        listing.qty = payload.qty
    if payload.min_price is not None:
        listing.min_price = payload.min_price
    if payload.status is not None:
        listing.status = payload.status

    db.commit()
    db.refresh(listing)

    cur_price, next_drop = calculate_current_dutch_price(listing)
    return wrap_success(_format_listing_response(listing, cur_price, next_drop))


@router.post(
    "/{listing_id}/buy",
    status_code=status.HTTP_201_CREATED,
    response_model=ResponseEnvelope[OrderResponse],
)
async def buy_listing(
    db: DbSessionDep,
    current_buyer: RequireBuyerDep,
    listing_id: Annotated[int, Path(ge=1, description="Listing ID")],
    payload: Annotated[ListingBuyRequest, Body()] = ListingBuyRequest(),
) -> dict:
    order = execute_buy_now(
        db=db,
        listing_id=listing_id,
        buyer_user=current_buyer,
        buy_qty=payload.qty,
        biometric_verified=payload.biometric_verified,
    )

    listing = order.listing
    img_url = listing.product.image_url if (listing and listing.product) else None
    buyer_name = order.buyer.user.name if (order.buyer and order.buyer.user) else None
    buyer_business_type = order.buyer.business_type if order.buyer else None
    seller_name = listing.seller.company_name if (listing and listing.seller) else None

    product_detail = {
        "product_name": listing.product.name if listing.product else "Food Item",
        "category": listing.product.category if listing.product else "General",
        "batch_number": listing.batch_number,
        "image_url": img_url,
        "buyer_name": buyer_name,
        "buyer_business_type": buyer_business_type,
        "warehouse_lat": listing.seller.warehouse_lat if listing.seller else None,
        "warehouse_lng": listing.seller.warehouse_lng if listing.seller else None,
        "warehouse_address": (
            f"{listing.seller.company_name}, {listing.seller.city or listing.seller.address}"
            if (listing.seller and listing.seller.company_name)
            else (listing.seller.address if listing.seller else None)
        ),
    }

    resp = OrderResponse(
        id=order.id,
        listing_id=order.listing_id,
        buyer_id=order.buyer_id,
        buyer_name=buyer_name,
        buyer_business_type=buyer_business_type,
        seller_name=seller_name,
        image_url=img_url,
        qty=order.qty,
        final_unit_price=float(order.final_unit_price),
        total_price=float(order.total_price),
        status=order.status,
        created_at=order.created_at.isoformat(),
        product_detail=product_detail,
    )
    return wrap_success(resp.model_dump())
