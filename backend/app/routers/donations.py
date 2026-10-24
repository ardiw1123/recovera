from typing import Annotated
from fastapi import APIRouter, Path, status

from app.core.dependencies import DbSessionDep
from app.schemas.donation import CertificateResponse
from app.schemas.envelope import ResponseEnvelope, wrap_success
from app.services.donation_service import get_donation_certificate

router = APIRouter(prefix="/donations", tags=["donations"])


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
    from app.core.exceptions import AppException
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

