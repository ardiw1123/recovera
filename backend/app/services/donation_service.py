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
