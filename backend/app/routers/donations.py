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
