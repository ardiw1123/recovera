from typing import Annotated
from fastapi import APIRouter, Body, status

from app.core.dependencies import CurrentUserDep, DbSessionDep
from app.core.exceptions import AppException
from app.models.user import Buyer, Seller
from app.schemas.envelope import ResponseEnvelope, wrap_success
from app.schemas.profile import BuyerProfile, ProfileResponse, ProfileUpdateRequest, SellerProfile

router = APIRouter(prefix="/profile", tags=["profile"])


def _build_profile_response(user) -> dict:
    seller_data = None
    if user.seller:
        seller_data = SellerProfile(
            id=user.seller.id,
            company_name=user.seller.company_name,
            address=user.seller.address,
            warehouse_lat=user.seller.warehouse_lat,
            warehouse_lng=user.seller.warehouse_lng,
            city=user.seller.city,
        ).model_dump()

    buyer_data = None
    if user.buyer:
        buyer_data = BuyerProfile(
            id=user.buyer.id,
            business_type=user.buyer.business_type,
            address=user.buyer.address,
            base_lat=user.buyer.base_lat,
            base_lng=user.buyer.base_lng,
            pref_categories=user.buyer.pref_categories or [],
            max_radius_km=user.buyer.max_radius_km,
            has_cold_storage=user.buyer.has_cold_storage,
            total_orders_completed=user.buyer.total_orders_completed,
            payment_reliability_score=float(user.buyer.payment_reliability_score),
        ).model_dump()

    return ProfileResponse(
        id=user.id,
        email=user.email,
        role=user.role,
        name=user.name,
        phone=user.phone,
        photo_url=user.photo_url,
        seller=seller_data,
        buyer=buyer_data,
    ).model_dump()


@router.get(
    "",
    status_code=status.HTTP_200_OK,
    response_model=ResponseEnvelope[ProfileResponse],
)
async def get_profile(
    current_user: CurrentUserDep,
) -> dict:
    return wrap_success(_build_profile_response(current_user))


@router.patch(
    "",
    status_code=status.HTTP_200_OK,
    response_model=ResponseEnvelope[ProfileResponse],
)
async def update_profile(
    db: DbSessionDep,
    current_user: CurrentUserDep,
    payload: Annotated[ProfileUpdateRequest, Body()],
) -> dict:
    if payload.name is not None:
        current_user.name = payload.name
    if payload.phone is not None:
        current_user.phone = payload.phone
    if payload.photo_url is not None:
        current_user.photo_url = payload.photo_url

    if current_user.role == "seller" and current_user.seller:
        if payload.company_name is not None:
            current_user.seller.company_name = payload.company_name
        if payload.address is not None:
            current_user.seller.address = payload.address
        if payload.warehouse_lat is not None:
            current_user.seller.warehouse_lat = payload.warehouse_lat
        if payload.warehouse_lng is not None:
            current_user.seller.warehouse_lng = payload.warehouse_lng
        if payload.city is not None:
            current_user.seller.city = payload.city

    elif current_user.role == "buyer" and current_user.buyer:
        if payload.business_type is not None:
            current_user.buyer.business_type = payload.business_type
        if payload.address is not None:
            current_user.buyer.address = payload.address
        if payload.base_lat is not None:
            current_user.buyer.base_lat = payload.base_lat
        if payload.base_lng is not None:
            current_user.buyer.base_lng = payload.base_lng
        if payload.pref_categories is not None:
            current_user.buyer.pref_categories = payload.pref_categories
        if payload.max_radius_km is not None:
            if payload.max_radius_km <= 0:
                raise AppException(
                    "INVALID_RADIUS",
                    "Maximum radius must be greater than zero",
                    status.HTTP_422_UNPROCESSABLE_ENTITY
                )
            current_user.buyer.max_radius_km = payload.max_radius_km
        if payload.has_cold_storage is not None:
            current_user.buyer.has_cold_storage = payload.has_cold_storage

    db.commit()
    db.refresh(current_user)
    return wrap_success(_build_profile_response(current_user))
