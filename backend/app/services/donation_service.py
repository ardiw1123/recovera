import logging
import time
from datetime import date, datetime, timezone
from zoneinfo import ZoneInfo
import httpx
from fastapi import status
from sqlalchemy.orm import Session

from app.config import get_settings
from app.core.exceptions import AppException
from app.models.donation import Donation, Offtaker
from app.models.listing import Listing
from app.schemas.donation import (
    BlockchainVerifyResponse,
    CertificateCurrencyBreakdown,
    CertificateResponse,
    DonationListItem,
    SellerDonationsResponse,
)
from app.services.blockchain_service import (
    store_certificate_on_chain,
    verify_certificate_on_chain,
)

logger = logging.getLogger(__name__)

_cached_rates: dict[str, float] | None = None
_rates_cached_at: float = 0.0


def get_current_exchange_rates() -> dict[str, float]:
    """
    Mengambil kurs nilai tukar mata uang dari IDR ke USD, EUR, GBP secara dinamis.
    Menggunakan caching 1 jam dan fallback default jika API eksternal offline.
    """
    global _cached_rates, _rates_cached_at
    now = time.time()
    if _cached_rates is not None and (now - _rates_cached_at < 3600):
        return _cached_rates

    try:
        resp = httpx.get("https://open.er-api.com/v6/latest/IDR", timeout=3.0)
        if resp.status_code == 200:
            data = resp.json()
            rates = data.get("rates", {})
            if "USD" in rates and "EUR" in rates and "GBP" in rates:
                _cached_rates = {
                    "USD": float(rates["USD"]),
                    "EUR": float(rates["EUR"]),
                    "GBP": float(rates["GBP"]),
                }
                _rates_cached_at = now
                return _cached_rates
    except Exception as e:
        logger.warning("Gagal mengambil kurs real-time dari open.er-api.com: %s", e)

    if _cached_rates is not None:
        return _cached_rates

    # Nilai fallback wajar jika server tidak ada akses internet eksternal
    return {
        "USD": 0.000062,
        "EUR": 0.000058,
        "GBP": 0.000049,
    }


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
    wib_time = created_at.astimezone(ZoneInfo("Asia/Jakarta")).strftime("%Y-%m-%d %H:%M:%S WIB")

    rates = get_current_exchange_rates()
    val_idr = float(listing.normal_price * donation.qty_diverted) if listing else 100000.0
    val_usd = round(val_idr * rates["USD"], 2)
    val_eur = round(val_idr * rates["EUR"], 2)
    val_gbp = round(val_idr * rates["GBP"], 2)

    has_chain = bool(donation.certificate_tx_hash and str(donation.certificate_tx_hash).strip())
    blockchain_status = "Tercatat" if has_chain else "Menunggu"

    settings = get_settings()
    explorer_url = None
    if has_chain:
        explorer_url = f"{settings.bot_chain_explorer_url.rstrip('/')}/tx/{donation.certificate_tx_hash}"

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
        issued_at_wib=wib_time,
        blockchain_status=blockchain_status,
        certificate_tx_hash=donation.certificate_tx_hash,
        block_number=donation.block_number,
        explorer_url=explorer_url,
    )


def verify_blockchain_hash(tx_hash: str) -> BlockchainVerifyResponse:
    """
    Memverifikasi transaksi sertifikat langsung ke blockchain BOT Chain Testnet secara nyata.
    """
    res = verify_certificate_on_chain(tx_hash)
    return BlockchainVerifyResponse(
        tx_hash=res["tx_hash"],
        verified=res["verified"],
        status=res["status"],
        block_number=res["block_number"],
        network=res["network"],
        contract_address=res["contract_address"],
        block_explorer_url=res["block_explorer_url"],
        verified_at=res.get("verified_at"),
        certificate_hash_on_chain=res.get("certificate_hash_on_chain"),
    )


def divert_listing_to_donation(db: Session, listing: Listing) -> Donation:
    """
    Menghentikan lelang listing dan mengalihkan stok ke jalur donasi (food bank / offtaker).
    Aturan bisnis: Jika sisa umur stok < 15 hari dan status belum terjual/diverted.
    Hash sertifikat disimpan ke blockchain BOT Chain secara nyata via relayer backend.
    """
    if listing.donation is not None:
        return listing.donation

    listing.status = "diverted"

    # Cari atau buat offtaker default jika belum ada
    offtaker = db.query(Offtaker).first()
    if offtaker is None:
        offtaker = Offtaker(
            name="Food Bank Indonesia",
            type="foodbank",
            lat=-6.2088,
            lng=106.8456,
            contact="+628119876543",
        )
        db.add(offtaker)
        db.flush()

    days_left = max(0, (listing.expiry_date - date.today()).days)
    grade = "A" if days_left >= 7 else "B" if days_left >= 3 else "C"
    qty_diverted = listing.qty
    carbon_saved = round(float(qty_diverted) * 2.5, 2)
    cert_no = f"ESG-ID-2026-{1000 + listing.id:05d}"
    created_now = datetime.now(timezone.utc)

    donation = Donation(
        listing_id=listing.id,
        offtaker_id=offtaker.id,
        grade=grade,
        qty_diverted=qty_diverted,
        carbon_saved_kg=carbon_saved,
        certificate_no=cert_no,
        certificate_tx_hash=None,
        block_number=None,
        created_at=created_now,
    )
    db.add(donation)
    db.commit()
    db.refresh(donation)

    # Catat sertifikat ke Blockchain BOT Chain
    product_name = listing.product.name if listing.product else "Food Item"
    cert_payload = f"{cert_no}:{product_name}:{grade}:{qty_diverted}:{carbon_saved}:{int(created_now.timestamp())}"

    try:
        chain_res = store_certificate_on_chain(cert_no, cert_payload)
        if chain_res.get("status") == "success":
            donation.certificate_tx_hash = chain_res.get("tx_hash")
            donation.block_number = chain_res.get("block_number")
            db.commit()
            db.refresh(donation)
            logger.info(
                "Successfully stored ESG certificate %s on-chain (tx: %s, block: %s)",
                cert_no,
                donation.certificate_tx_hash,
                donation.block_number,
            )
        else:
            logger.warning(
                "Blockchain recording failed for %s: %s (will be retried by scheduler)",
                cert_no,
                chain_res.get("error"),
            )
    except Exception as e:
        logger.error("Exception during store_certificate_on_chain for %s: %s", cert_no, e)

    return donation


def check_and_divert_expired_listings(db: Session) -> list[Donation]:
    """
    Periksa seluruh listing aktif: jika tidak terjual dan sisa umur < 15 hari,
    hentikan lelang dan alihkan ke jalur donasi.
    """
    from datetime import timedelta
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


def retry_pending_blockchain_certificates(db: Session) -> int:
    """
    Mencoba mencatat ulang sertifikat donasi yang belum memiliki certificate_tx_hash.
    Dipanggil oleh cron job scheduler secara berkala.
    """
    pending_donations = (
        db.query(Donation)
        .filter(
            (Donation.certificate_tx_hash.is_(None)) | (Donation.certificate_tx_hash == "")
        )
        .all()
    )

    success_count = 0
    for donation in pending_donations:
        listing = db.query(Listing).filter(Listing.id == donation.listing_id).first()
        product_name = listing.product.name if listing and listing.product else "Food Item"
        ts = int(donation.created_at.timestamp()) if donation.created_at else int(time.time())
        cert_payload = f"{donation.certificate_no}:{product_name}:{donation.grade}:{donation.qty_diverted}:{donation.carbon_saved_kg}:{ts}"

        try:
            chain_res = store_certificate_on_chain(donation.certificate_no, cert_payload)
            if chain_res.get("status") == "success":
                donation.certificate_tx_hash = chain_res.get("tx_hash")
                donation.block_number = chain_res.get("block_number")
                db.commit()
                success_count += 1
                logger.info("Retried & stored certificate %s on chain", donation.certificate_no)
        except Exception as e:
            logger.error("Failed to retry certificate %s: %s", donation.certificate_no, e)

    return success_count


def get_seller_donations(db: Session, seller_id: int) -> SellerDonationsResponse:
    """
    Mengambil seluruh riwayat donasi yang berasal dari listing milik seller tertentu.
    """
    donations = (
        db.query(Donation)
        .join(Listing, Donation.listing_id == Listing.id)
        .filter(Listing.seller_id == seller_id)
        .order_by(Donation.created_at.desc())
        .all()
    )

    items: list[DonationListItem] = []
    total_carbon = 0.0

    for d in donations:
        product_name = d.listing.product.name if d.listing and d.listing.product else "Produk Donasi"
        carbon = float(d.carbon_saved_kg)
        total_carbon += carbon
        created_str = d.created_at.isoformat() if d.created_at else ""
        has_chain = bool(d.certificate_tx_hash and str(d.certificate_tx_hash).strip())

        items.append(
            DonationListItem(
                id=d.id,
                certificate_no=d.certificate_no,
                listing_id=d.listing_id,
                product_name=product_name,
                grade=d.grade,
                blockchain_status="Tercatat" if has_chain else "Menunggu",
                created_at=created_str,
                carbon_saved_kg=carbon,
                qty_diverted=d.qty_diverted,
                offtaker_name=d.offtaker.name if d.offtaker else "Mitra Food Bank",
                certificate_tx_hash=d.certificate_tx_hash,
                block_number=d.block_number,
            )
        )

    return SellerDonationsResponse(
        items=items,
        total_certificates=len(items),
        total_carbon_saved_kg=round(total_carbon, 2),
    )
