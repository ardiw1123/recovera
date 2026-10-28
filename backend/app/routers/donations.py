from datetime import date, datetime, timedelta, timezone
from typing import Annotated

from fastapi import APIRouter, Path, status

from app.config import get_settings
from app.core.dependencies import DbSessionDep, RequireSellerDep
from app.core.exceptions import AppException
from app.models.listing import Listing
from app.models.product import Product
from app.models.user import Seller
from app.schemas.donation import (
    CertificateResponse,
    SellerDonationsResponse,
)
from app.schemas.envelope import ResponseEnvelope, wrap_success
from app.services.donation_service import (
    divert_listing_to_donation,
    get_donation_certificate,
    get_seller_donations,
)

router = APIRouter(prefix="/donations", tags=["donations"])


@router.get(
    "/my",
    status_code=status.HTTP_200_OK,
    response_model=ResponseEnvelope[SellerDonationsResponse],
)
async def get_my_donations(
    db: DbSessionDep,
    current_user: RequireSellerDep,
) -> dict:
    seller = current_user.seller
    if not seller:
        seller = db.query(Seller).filter(Seller.user_id == current_user.id).first()
    if not seller:
        raise AppException(
            code="SELLER_PROFILE_NOT_FOUND",
            message="Profil seller tidak ditemukan",
            status_code=status.HTTP_404_NOT_FOUND,
        )

    donations_data = get_seller_donations(db, seller.id)
    return wrap_success(donations_data.model_dump())


@router.get("/sellers/{seller_id}/certificates", response_model=ResponseEnvelope[SellerDonationsResponse])
async def get_public_seller_certificates(
    db: DbSessionDep,
    seller_id: Annotated[int, Path(ge=1)],
) -> dict:
    seller = db.query(Seller).filter(Seller.id == seller_id).first()
    if not seller:
        raise AppException("SELLER_NOT_FOUND", "Profil penjual tidak ditemukan", status.HTTP_404_NOT_FOUND)
    return wrap_success(get_seller_donations(db, seller_id).model_dump())


@router.get(
    "/{donation_id}/certificate",
    status_code=status.HTTP_200_OK,
    response_model=ResponseEnvelope[CertificateResponse],
)
async def get_certificate(
    db: DbSessionDep,
    donation_id: Annotated[int, Path(ge=1, description="Donation ID")],
) -> dict:
    certificate = get_donation_certificate(db, donation_id)
    return wrap_success(certificate.model_dump())


@router.post(
    "/divert-expired",
    status_code=status.HTTP_200_OK,
)
async def process_expired_diversions(
    db: DbSessionDep,
) -> dict:
    from app.services.donation_service import check_and_divert_expired_listings
    diverted = check_and_divert_expired_listings(db)
    return wrap_success({
        "diverted_count": len(diverted),
        "diverted_listing_ids": [d.listing_id for d in diverted],
    })


@router.post(
    "/listings/{listing_id}/divert",
    status_code=status.HTTP_200_OK,
)
async def divert_single_listing(
    db: DbSessionDep,
    listing_id: Annotated[int, Path(ge=1)],
) -> dict:
    from app.models.listing import Listing
    from app.services.donation_service import divert_listing_to_donation
    listing = db.query(Listing).filter(Listing.id == listing_id).first()
    if not listing:
        raise AppException("LISTING_NOT_FOUND", "Listing not found", status.HTTP_404_NOT_FOUND)
    donation = divert_listing_to_donation(db, listing)
    return wrap_success({
        "listing_id": listing.id,
        "status": listing.status,
        "donation_id": donation.id,
        "certificate_no": donation.certificate_no,
    })


ESG_TEST_SKU_PREFIX = "TEST-ESG-"
ESG_TEST_EXPIRY_DAYS = 5  # Grade B (sisa umur 3-6 hari), masih < ambang diversion 15 hari


@router.post("/test/simulate-diversion", status_code=status.HTTP_200_OK)
async def simulate_esg_diversion(
    db: DbSessionDep,
    current_user: RequireSellerDep,
) -> dict:
    """
    Endpoint khusus pengujian (environment development, atau environment lain
    dengan flag ENABLE_TEST_FEATURES=true):
    membuat listing uji near-expiry milik seller yang sedang login, lalu
    menjalankan alur diversion & penerbitan sertifikat ESG yang asli
    (termasuk pencatatan ke BOT Chain Testnet via divert_listing_to_donation).

    Idempotent per seller: klik berulang memakai listing uji yang sama dan
    mengembalikan sertifikat yang sudah ada, tidak membuat duplikat.
    """
    settings = get_settings()
    is_dev = settings.environment.lower() in {"development", "dev", "local"}
    if not (is_dev or settings.enable_test_features):
        raise AppException(
            "TEST_FEATURE_DISABLED",
            "Fitur pengujian dinonaktifkan (aktifkan via ENABLE_TEST_FEATURES=true)",
            status.HTTP_403_FORBIDDEN,
        )

    seller = current_user.seller
    if not seller:
        seller = db.query(Seller).filter(Seller.user_id == current_user.id).first()
    if not seller:
        raise AppException(
            code="SELLER_PROFILE_NOT_FOUND",
            message="Profil seller tidak ditemukan",
            status_code=status.HTTP_404_NOT_FOUND,
        )

    test_sku = f"{ESG_TEST_SKU_PREFIX}{seller.id}"
    listing = (
        db.query(Listing)
        .join(Product, Listing.product_id == Product.id)
        .filter(Product.sku == test_sku, Listing.seller_id == seller.id)
        .first()
    )

    if listing is None:
        product = db.query(Product).filter(Product.sku == test_sku).first()
        if product is None:
            product = Product(
                sku=test_sku,
                name="[UJI] Susu UHT 1L",
                brand="Recovera Test",
                category="Dairy",
                storage_type="chilled",
                default_unit="pcs",
            )
            db.add(product)
            db.flush()

        now = datetime.now(timezone.utc)
        expiry = date.today() + timedelta(days=ESG_TEST_EXPIRY_DAYS)
        listing = Listing(
            product_id=product.id,
            seller_id=seller.id,
            batch_number="TEST-ESG",
            qty=24,
            normal_price=18000,
            start_price=18000,
            min_price=12000,
            expiry_date=expiry,
            auction_start_at=now,
            auction_end_at=datetime.combine(expiry, datetime.min.time(), tzinfo=timezone.utc),
            status="active",
        )
        db.add(listing)
        db.commit()
        db.refresh(listing)

    donation = divert_listing_to_donation(db, listing)
    has_chain = bool(donation.certificate_tx_hash and str(donation.certificate_tx_hash).strip())

    return wrap_success({
        "listing_id": listing.id,
        "donation_id": donation.id,
        "certificate_no": donation.certificate_no,
        "grade": donation.grade,
        "qty_diverted": donation.qty_diverted,
        "carbon_saved_kg": float(donation.carbon_saved_kg),
        "certificate_tx_hash": donation.certificate_tx_hash,
        "blockchain_status": "Tercatat" if has_chain else "Menunggu",
    })
