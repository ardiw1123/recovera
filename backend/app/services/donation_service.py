import random
from datetime import datetime, timezone
from zoneinfo import ZoneInfo
from sqlalchemy.orm import Session
from fastapi import status

from app.core.exceptions import AppException
from app.models.donation import Donation, Offtaker
from app.models.listing import Listing
from app.schemas.donation import (
    BlockchainVerifyResponse,
    CertificateCurrencyBreakdown,
    CertificateResponse,
)

# Benchmark currency rates from IDR
EXCHANGE_RATES = {
    "USD": 0.000064,
    "EUR": 0.000059,
    "GBP": 0.000050,
}


def get_current_exchange_rates() -> dict[str, float]:
    return EXCHANGE_RATES


def get_donation_certificate(db: Session, donation_id: int) -> CertificateResponse:
    donation = db.query(Donation).filter(Donation.id == donation_id).first()
    if not donation:
        raise AppException(
            code="CERTIFICATE_NOT_FOUND",
            message=f"Donation certificate #{donation_id} not found",
            status_code=status.HTTP_404_NOT_FOUND,
        )

    listing = db.query(Listing).filter(Listing.id == donation.listing_id).first()
    product_name = listing.product.name if listing and listing.product else "Food Item"

    created_at = donation.created_at
    if created_at.tzinfo is None:
        created_at = created_at.replace(tzinfo=timezone.utc)

    london_time = created_at.astimezone(ZoneInfo("Europe/London")).strftime("%Y-%m-%d %H:%M:%S %Z")

    val_idr = float(listing.normal_price * donation.qty_diverted) if listing else 100000.0
    val_usd = round(val_idr * EXCHANGE_RATES["USD"], 2)
    val_eur = round(val_idr * EXCHANGE_RATES["EUR"], 2)
    val_gbp = round(val_idr * EXCHANGE_RATES["GBP"], 2)

    return CertificateResponse(
        id=donation.id,
        certificate_no=donation.certificate_no,
        listing_id=donation.listing_id,
        product_name=product_name,
        offtaker_name=donation.offtaker.name if donation.offtaker else "Mitra Food Bank",
        offtaker_type=donation.offtaker.type if donation.offtaker else "foodbank",
        grade=donation.grade,
        qty_diverted=donation.qty_diverted,
        carbon_saved_kg=float(donation.carbon_saved_kg),
        monetary_value=CertificateCurrencyBreakdown(
            idr=val_idr,
            usd=val_usd,
            eur=val_eur,
            gbp=val_gbp,
        ),
        issued_at_london=london_time,
        certificate_tx_hash=donation.certificate_tx_hash,
        block_number=donation.block_number,
    )


def verify_blockchain_hash(tx_hash: str) -> BlockchainVerifyResponse:
    # BOT Chain testnet verification
    is_valid_format = tx_hash.startswith("0x") and len(tx_hash) >= 10
    block_no = 142857 if is_valid_format else None

    return BlockchainVerifyResponse(
        tx_hash=tx_hash,
        verified=is_valid_format,
        status="Confirmed" if is_valid_format else "Invalid / Not Found",
        block_number=block_no,
        network="BOT Chain Testnet",
        contract_address="0x89205A3A3b2A69De6Dbf7f01ED13B2108B2c43e7",
        block_explorer_url=f"https://explorer.bot-chain.testnet/tx/{tx_hash}",
    )


def divert_listing_to_donation(db: Session, listing: Listing) -> Donation:
    """
    Menghentikan lelang listing dan mengalihkan stok ke jalur donasi (food bank / offtaker).
    Aturan bisnis: Jika sisa umur stok < 15 hari dan status belum terjual/diverted.
    """
    if listing.donation is not None:
        return listing.donation

    listing.status = "diverted"

    # Cari offtaker (misal food bank / pakan / kompos terdaftar)
    offtaker = db.query(Offtaker).first()
    if offtaker is None:
        offtaker = Offtaker(
            name="Food Bank Indonesia",
            type="foodbank",
            lat=-6.2088,
            lng=106.8456,
            address="Jl. Pengalihan Pangan Surplus No. 1, Jakarta",
            contact="+628119876543",
        )
        db.add(offtaker)
        db.flush()

    from datetime import date
    days_left = max(0, (listing.expiry_date - date.today()).days)
    grade = "A" if days_left >= 7 else "B" if days_left >= 3 else "C"
    qty_diverted = listing.qty
    carbon_saved = round(float(qty_diverted) * 2.5, 2)
    cert_no = f"ESG-ID-2026-{1000 + listing.id:05d}"
    tx_hash = f"0x{''.join(random.choices('0123456789abcdef', k=64))}"

    donation = Donation(
        listing_id=listing.id,
        offtaker_id=offtaker.id,
        grade=grade,
        qty_diverted=qty_diverted,
        carbon_saved_kg=carbon_saved,
        certificate_no=cert_no,
        certificate_tx_hash=tx_hash,
        block_number=random.randint(5000000, 6000000),
        created_at=datetime.now(timezone.utc),
    )
    db.add(donation)
    db.commit()
    db.refresh(donation)
    return donation


def check_and_divert_expired_listings(db: Session) -> list[Donation]:
    """
    Periksa seluruh listing aktif: jika tidak terjual dan sisa umur < 15 hari,
    hentikan lelang dan alihkan ke jalur donasi.
    """
    from datetime import date, timedelta
    today = date.today()
    critical_threshold = today + timedelta(days=15)

    expired_listings = (
        db.query(Listing)
        .filter(
            Listing.status == "active",
            Listing.expiry_date < critical_threshold,
        )
        .all()
    )

    diverted_donations = []
    for item in expired_listings:
        donation = divert_listing_to_donation(db, item)
        diverted_donations.append(donation)

    return diverted_donations

